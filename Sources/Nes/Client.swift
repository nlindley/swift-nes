import Foundation
import Combine

// TODO: Remove extra print statements
// TODO: Handle

public class Client: NSObject {
    public private(set) var isConnected: Bool = false
    
    private var operationQueue = OperationQueue()
    private var urlSession: URLSession!
    private var webSocketTask: URLSessionWebSocketTask!
    private var subscriptions: Set<String> = []
    private let subject = PassthroughSubject<PubMessage, Error>()
    private var token: String?
    
    typealias MessageCallback<Message> = (_ message: Message) -> ()

    public init(url: URL) {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: operationQueue)
        webSocketTask = urlSession.webSocketTask(with: url)
    }
    
    public func connect(authToken: String? = nil) {
        self.token = authToken
        webSocketTask.resume()
    }

    // TODO: Use NES errors
    public func subscribe<Message>(path: String, for type: Message.Type) -> AnyPublisher<Message, Error>
    where Message : Decodable {
        // TODO: Should this be tracked by ID for unsub?
        let id = UUID()
        let outgoingMessage = ClientSub(id: NesID(string: id.uuidString), path: path)
        let data = try! JSONEncoder().encode(outgoingMessage)

        subscriptions.insert(path)

        if isConnected {
            webSocketTask.send(.data(data), completionHandler: { _ in
            
            })
        }
        
        return subject
            .filter { pubMessage in
                print("\(pubMessage.path) \(path)")
                return pubMessage.path == path
            }
            .tryMap { pubMessage in
                let pub = try! JSONDecoder().decode(PubMessageContent<Message>.self, from: pubMessage.content)
                return pub.message
            }
            .eraseToAnyPublisher()
    }
    
    func readNextMessage()  {
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
            subject.send(completion: .failure("Error"))
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
        let id = NesID(string: UUID().uuidString)
        let auth = self.token.map { BearerAuthToken(token: $0) }
        let hello = ClientHello(id: id, auth: auth, subs: [])
        self.send(message: hello)
        readNextMessage()
    }
}

extension String: Error {}
