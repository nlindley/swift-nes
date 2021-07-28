import Foundation
import Combine

// TODO: Remove extra print statements
// TODO: Handle

public class Client {
    private var urlSession: URLSession
    private var webSocketTask: URLSessionWebSocketTask
    public private(set) var isConnected: Bool = false
    private var subscriptions: Set<String> = []
    private let subject = PassthroughSubject<PubMessage, Error>()
    
    typealias MessageCallback<Message> = (_ message: Message) -> ()
    
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
    
    struct MessageHandler<Message: Decodable> {
        let callback: MessageCallback<Message.Type>
        let decoder: Decoder
    }

    public func receive(result: Result<URLSessionWebSocketTask.Message, Error>) -> Void {
        switch(result) {
        case .failure(let error):
            print(error.localizedDescription);
        case .success(.data(let data)):
            print(String(data: data, encoding: .utf8)!)
        case .success(.string(let string)):
            print(string)
        case .success(_):
            print("I don’t know how to handle this.")
//        case .connected:
//            isConnected = true
//            print("Connected")
//            let subs = subscriptions
//            print("Subs: \(subs)")
//            let hello = try! JSONEncoder().encode(ClientHello<[String:[String:String]]>(id: NesID(string: UUID().uuidString), auth: ["headers":["authorization":""]], subs: Array(subscriptions)))
//            socket.write(data: hello)
//        case .disconnected:
//            isConnected = false
//            print("Disconnected")
//        case .text(let text):
//            print("Received text \(text)")
//            let message = try! JSONDecoder().decode(IncomingMessage.self, from: text.data(using: .utf8)!)
//
//            switch message {
//            case .hello(let hello):
//                print("Received hello: \(hello.id)")
//            case .ping:
//                print("Received ping")
//                let pong = try! JSONEncoder().encode(ClientPing(id: NesID(string: UUID().uuidString)))
//                socket.write(data: pong)
//            case .sub(let sub):
//                print("Received sub: \(sub.id) \(sub.path)")
//            case .reauth(let reauth):
//                print("Received reauth: \(reauth.id)")
//            case .pub(let pub):
//                print("Received text pub: \(pub.path)")
//                subject.send(PubMessage(path: pub.path, content: text))
//            case .request(let request):
//                print("Received request: \(request.id) \(request.statusCode)")
//            case .message(let message):
//                print("Received message: \(message.id)")
//            case .unsub(let unsub):
//                print("Received unsub: \(unsub.id)")
//            case .update:
//                print("Received udpate:")
//            case .revoke(let revoke):
//                print("Received revoke: \(revoke.path)")
//            }
//        case .binary(let data):
//            print("Received binary \(data)")
//            let message = try! JSONDecoder().decode(IncomingMessage.self, from: data)
//
//            switch message {
//            case .hello(let hello):
//                print("Received hello: \(hello.id)")
//            case .ping:
//                print("Received ping")
//            case .sub(let sub):
//                print("Received sub: \(sub.id) \(sub.path)")
//            case .reauth(let reauth):
//                print("Received reauth: \(reauth.id)")
//            case .pub(let pub):
//                print("Received data pub: \(pub.path)")
//                subject.send(PubMessage(path: pub.path, content: data))
//            case .request(let request):
//                print("Received request: \(request.id) \(request.statusCode)")
//            case .message(let message):
//                print("Received message: \(message.id)")
//            case .unsub(let unsub):
//                print("Received unsub: \(unsub.id)")
//            case .update:
//                print("Received udpate:")
//            case .revoke(let revoke):
//                print("Received revoke: \(revoke.path)")
//            }
//        case .ping:
//            break
//        case .pong:
//            break
//        case .viabilityChanged(let viable):
//            print("Viability changed: \(viable)")
//            break
//        case .reconnectSuggested(let suggested):
//            // TODO: Reconnect? If true?
//            print("Reconnect suggested: \(suggested)")
//            break
//        case .cancelled:
//            print("Cancelled")
//            isConnected = false
//        case .error(let error):
//            isConnected = false
//            print("Received error: \(String(describing: error))")
        }
    }

    public init(url: URL) {
        urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask.receive(completionHandler: self.receive)
        // TODO: webSocketTask.resume()
    }
    
    public func connect() {
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
            print("I think I should write data")
            webSocketTask.send(.data(data), completionHandler: {_ in
                print("Sent")
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
}
