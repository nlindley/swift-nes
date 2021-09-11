import Foundation
import Combine

// TODO: Remove extra print statements
// TODO: Handle

public enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
}

public class Client: NSObject {
    public private(set) var connectionStatus = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    
    private let subject = PassthroughSubject<PubMessage, NesError>()
    private var operationQueue = OperationQueue()
    private var urlSession: URLSession!
    private var webSocketTask: URLSessionWebSocketTask!
    private var subscriptions: Set<String> = []
    private var cancellables: Set<AnyCancellable> = []
    private var pendingRequests: Dictionary<NesID, (Result<Data, NesError>) -> Void> = [:]
    private var fetchAuth: FetchAuthHeadersFuture? = nil
        
    typealias MessageCallback<Message> = (_ message: Message) -> ()
    public typealias FetchAuthHeadersFuture = () -> Future<[String:String], Error>

    public init(url: URL) {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: operationQueue)
        webSocketTask = urlSession.webSocketTask(with: url)
    }
    
    deinit {
        disconnect()
    }

    public func connect(auth: FetchAuthHeadersFuture? = nil) -> AnyPublisher<Client, NesError> {
        if let auth = auth {
            self.fetchAuth = auth
        }

        webSocketTask.resume()
        
        connectionStatus.send(.connecting)
        
        return connectionStatus
            .first(where: { status in
                switch (status) {
                case .connected:
                    return true
                case _:
                    return false
                }
            })
            .setFailureType(to: NesError.self)
            .timeout(.seconds(30), scheduler: DispatchQueue.main, options: nil) { [self] () in
                connectionStatus.send(.disconnected)
                return NesError(message: "timed out connecting")
            }
            .map { _ in
                return self
            }
            .eraseToAnyPublisher()
    }
    
    public func disconnect(err: Error? = nil) {
        connectionStatus.send(.disconnected)
        subject.send(completion: err.map { _ in Subscribers.Completion.failure(NesError(message: err?.localizedDescription ?? "")) } ?? .finished)
        subscriptions.forEach(unsubscribe)
        webSocketTask.cancel(with: .goingAway, reason: nil)
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // TODO: Use NES errors
    public func subscribe<Message>(path: String, for type: Message.Type) -> AnyPublisher<Message, NesError>
    where Message : Decodable {
        // TODO: Should this be tracked by ID for unsub?
        let id = NesID(string: UUID().uuidString)
        let outgoingMessage = ClientSub(id: id, path: path)
        let data = try! JSONEncoder().encode(outgoingMessage)

        subscriptions.insert(path)

        if case .connected = connectionStatus.value {
            webSocketTask.send(.data(data), completionHandler: { _ in
            
            })
        }
        
        return subject
            .filter { pubMessage in
                return pubMessage.path.compare(path, options: .caseInsensitive) == .orderedSame
            }
            .tryMap { pubMessage in
                let pub = try! JSONDecoder().decode(PubMessageContent<Message>.self, from: pubMessage.content)
                return pub.message
            }
            .mapError { NesError(message: $0.localizedDescription) }
            .eraseToAnyPublisher()
    }
    
    public func request<RequestPayload: Encodable, ResponsePayload: Decodable>(
        method: HTTPMethod,
        path: String,
        payload: RequestPayload,
        headers: [String: String]? = nil,
        for type: ResponsePayload.Type
    ) -> AnyPublisher<ResponsePayload?, NesError> {
        let clientRequest = ClientRequest(method: method, path: path, payload: payload, headers: headers)
        return request(clientRequest, for: type)
    }
    
    public func request<ResponsePayload: Decodable>(
        method: HTTPMethod,
        path: String,
        headers: [String: String]? = nil,
        for type: ResponsePayload.Type
    ) -> AnyPublisher<ResponsePayload?, NesError> {
        let clientRequest = ClientRequest(method: method, path: path, headers: headers)
        return request(clientRequest, for: type)
    }
    
    func request<RequestPayload: Encodable, ResponsePayload: Decodable>(
        _ clientRequest: ClientRequest<RequestPayload>,
        for type: ResponsePayload.Type
    ) -> AnyPublisher<ResponsePayload?, NesError> {
        send(message: clientRequest)
        // TODO: Make timeout configurable
        return Future<Data, NesError> { [self] promise in
            pendingRequests[clientRequest.id] = promise
        }
        .map { requestResponse in
            let response = try! JSONDecoder().decode(RequestResponse<ResponsePayload>.self, from: requestResponse)
            return response.payload
        }
        .timeout(.seconds(30), scheduler: DispatchQueue.main, options: nil) { [self] () in
            pendingRequests.removeValue(forKey: clientRequest.id)
            return NesError(message: "Timed out waiting for response")
        }
        .eraseToAnyPublisher()
    }
    
    public func unsubscribe(_ path: String) {
        let id = NesID(string: UUID().uuidString)
        let outgoingMessage = ClientUnsub(id: id, path: path)
        let data = try! JSONEncoder().encode(outgoingMessage)

        subscriptions.remove(path)
        webSocketTask.send(.data(data)) { _ in }
    }
    
    func readNextMessage()  {
        webSocketTask.receive { result in
            switch(result) {
            case .failure(let error):
                self.subject.send(completion: .failure(NesError(message: error.localizedDescription)))
            case .success(.data(let data)):
                self.parseData(data)
                self.readNextMessage()
            case .success(.string(let string)):
                self.parseData(string.data(using: .utf8)!)
                self.readNextMessage()
            @unknown default:
                print("I don’t know how to handle this.")
            }
        }
    }
    
    func parseData(_ data: Data) {
        guard let message = try? JSONDecoder().decode(IncomingMessage.self, from: data) else {
            subject.send(completion: .failure(NesError(message: "Error")))
            return
        }
        
        switch message {
        case .hello(let hello):
            connectionStatus.send(.connected)
        case .ping:
            let pong = ClientPing(id: NesID(string: UUID().uuidString))
            send(message: pong)
        case .sub(let sub):
            print("Received sub: \(sub.id) \(sub.path)")
        case .reauth(let reauth):
            print("Received reauth: \(reauth.id)")
        case .pub(let pub):
            let pub = PubMessage(path: pub.path, content: data)
            subject.send(pub)
        case .request(let request):
            guard let promise = pendingRequests[request.id] else {
                return
            }

            promise(.success(data))
            pendingRequests.removeValue(forKey: request.id)
        case .message(let message):
            print("Received message: \(message.id)")
        case .unsub(let unsub):
            print("Received unsub: \(unsub.id)")
        case .update:
            print("Received udpate:")
        case .revoke(let revoke):
            // FIXME: This should only send completions for subscribers to this path
            subject.send(completion: .finished)
            subscriptions.remove(revoke.path)
        }
    }
    
    func send<T: OutgoingMessage>(message: T) {
        let data = try! JSONEncoder().encode(message)
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask.send(message) { error in
            if let error = error {
                print(error)
            }
        }
    }
    
    private func authenticate() -> AnyPublisher<[String : String]?, Error> {
            switch self.fetchAuth {
            case nil:
                return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
            case .some(let auth):
                return auth().map(Optional.some).eraseToAnyPublisher()
            }
        }
    
    func sendHello() {
        let id = NesID(string: UUID().uuidString)
        let subscriptions = self.subscriptions
        authenticate()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let err):
                    self.disconnect(err: err)
                }
            }, receiveValue: { auth in
                let hello = ClientHello(id: id, auth: auth, subs: Array(subscriptions))
                self.send(message: hello)
                self.readNextMessage()
            })
            .store(in: &cancellables)
    }
    
    struct PubMessage {
        let path: String
        let content: Data
        
        init(path: String, content: String) {
            self.path = path
            self.content = Data(content.utf8)
        }
        
        init(path: String, content: Data) {
            self.path = path
            self.content = content
        }
    }
    
    struct PubMessageContent<Message: Decodable>: Decodable {
        let message: Message
    }
    
    struct RequestResponse<ResponsePayload: Decodable>: Decodable {
        let id: NesID
        let statusCode: Int
        let headers: [String:String]?
        let payload: ResponsePayload?
    }
}

extension Client: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        sendHello()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        connectionStatus.send(.disconnected)
    }
}

public struct NesError: Error {
    let message: String
}
