import Foundation
import Combine

// TODO: Remove extra print statements
// TODO: Handle

public class Client: NSObject {
    public private(set) var isConnected: Bool = false
    
    private let subject = PassthroughSubject<PubMessage, Error>()
    private var operationQueue = OperationQueue()
    private var urlSession: URLSession!
    private var webSocketTask: URLSessionWebSocketTask!
    private var subscriptions: Set<String> = []
    private var cancellables: Set<AnyCancellable> = []
    private var fetchAuth: (() -> AnyPublisher<AuthHeader?, Never>)
        
    typealias MessageCallback<Message> = (_ message: Message) -> ()
    public typealias FutureAuthHeader = () -> Future<[String:String]?, Never>

    public init(url: URL) {
        fetchAuth = { Empty().eraseToAnyPublisher() }
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: operationQueue)
        webSocketTask = urlSession.webSocketTask(with: url)
    }
    
    deinit {
        disconnect()
    }

    public func connect(auth: FutureAuthHeader? = nil) {
        self.fetchAuth = buildFetchAuth(auth: auth)
        webSocketTask.resume()
    }
    
    public func disconnect() {
        isConnected = false
        subject.send(completion: .finished)
        subscriptions.forEach(unsubscribe)
        webSocketTask.cancel(with: .goingAway, reason: nil)
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // TODO: Use NES errors
    public func subscribe<Message>(path: String, for type: Message.Type) -> AnyPublisher<Message, Error>
    where Message : Decodable {
        // TODO: Should this be tracked by ID for unsub?
        let id = NesID(string: UUID().uuidString)
        let outgoingMessage = ClientSub(id: id, path: path)
        let data = try! JSONEncoder().encode(outgoingMessage)

        subscriptions.insert(path.lowercased())

        if isConnected {
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
            .eraseToAnyPublisher()
    }
    
    public func unsubscribe(_ path: String) {
        let id = NesID(string: UUID().uuidString)
        let outgoingMessage = ClientUnsub(id: id, path: path)
        let data = try! JSONEncoder().encode(outgoingMessage)

        subscriptions.remove(path.lowercased())
        webSocketTask.send(.data(data)) { _ in }
    }
    
    func readNextMessage()  {
        print("Reading next message.")
        webSocketTask.receive { result in
            switch(result) {
            case .failure(let error):
                print("Failed to receive message: \(error)")
            case .success(.data(let data)):
                print(String(data: data, encoding: .utf8)!)
                self.parseData(data)
                self.readNextMessage()
            case .success(.string(let string)):
                print(string)
                self.parseData(string.data(using: .utf8)!)
                self.readNextMessage()
            @unknown default:
                print("I don’t know how to handle this.")
            }
        }
    }
    
    func parseData(_ data: Data) {
        let message = try? JSONDecoder().decode(IncomingMessage.self, from: data)
        guard let message = message else {
            subject.send(completion: .failure(NesError(message: "Error")))
            return
        }
        
        switch message {
        case .hello(let hello):
            print("Received hello: \(hello.id)")
        case .ping:
            print("Received ping")
            let pong = ClientPing(id: NesID(string: UUID().uuidString))
            send(message: pong)
        case .sub(let sub):
            print("Received sub: \(sub.id) \(sub.path)")
        case .reauth(let reauth):
            print("Received reauth: \(reauth.id)")
        case .pub(let pub):
            print("Received text pub: \(pub.path)")
            let pub = PubMessage(path: pub.path, content: data)
            subject.send(pub)
        case .request(let request):
            print("Received request: \(request.id) \(request.statusCode)")
        case .message(let message):
            print("Received message: \(message.id)")
        case .unsub(let unsub):
            print("Received unsub: \(unsub.id)")
        case .update:
            print("Received udpate:")
        case .revoke(let revoke):
            print("Received revoke: \(revoke.path)")
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
    
    func sendHello() {
        let id = NesID(string: UUID().uuidString)
        let subscriptions = self.subscriptions
        fetchAuth()
            .sink { auth in
                let hello = ClientHello(id: id, auth: auth, subs: Array(subscriptions))
                self.send(message: hello)
                self.readNextMessage()
            }
            .store(in: &cancellables)
    }
    
    func buildFetchAuth(auth: FutureAuthHeader?) -> (() -> AnyPublisher<AuthHeader?, Never>) {
        return auth.map {
            unwrappedAuth in {
                unwrappedAuth().map { unwrappedheaders in
                    unwrappedheaders.map { AuthHeader(headers: $0) }
                }.eraseToAnyPublisher()
            }
        } ?? { Empty().eraseToAnyPublisher() }
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
}

extension Client: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        print("Connected")
        sendHello()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
    }
}

struct NesError: Error {
    let message: String
}
