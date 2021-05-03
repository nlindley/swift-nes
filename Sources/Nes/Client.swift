import Foundation
import Combine
import Starscream

// TODO: Remove extra print statements
// TODO: Handle

@available(macOS 10.15, *)
public class Client: WebSocketDelegate {
    private var request: URLRequest
    private var socket: WebSocket
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

    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch(event) {
        case .connected:
            isConnected = true
            print("Connected")
            let subs = subscriptions
            print("Subs: \(subs)")
            let hello = try! JSONEncoder().encode(ClientHello<[String:String]>(id: NesID(string: UUID().uuidString), auth: [:], subs: Array(subscriptions)))
            socket.write(data: hello)
        case .disconnected:
            isConnected = false
            print("Disconnected")
        case .text(let text):
            print("Received text \(text)")
            let message = try! JSONDecoder().decode(IncomingMessage.self, from: text.data(using: .utf8)!)

            switch message {
            case .hello(let hello):
                print("Received hello: \(hello.id)")
            case .ping:
                print("Received ping")
                let pong = try! JSONEncoder().encode(ClientPing(id: NesID(string: UUID().uuidString)))
                socket.write(data: pong)
            case .sub(let sub):
                print("Received sub: \(sub.id) \(sub.path)")
            case .reauth(let reauth):
                print("Received reauth: \(reauth.id)")
            case .pub(let pub):
                print("Received text pub: \(pub.path)")
                subject.send(PubMessage(path: pub.path, content: text))
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
        case .binary(let data):
            print("Received binary \(data)")
            let message = try! JSONDecoder().decode(IncomingMessage.self, from: data)

            switch message {
            case .hello(let hello):
                print("Received hello: \(hello.id)")
            case .ping:
                print("Received ping")
            case .sub(let sub):
                print("Received sub: \(sub.id) \(sub.path)")
            case .reauth(let reauth):
                print("Received reauth: \(reauth.id)")
            case .pub(let pub):
                print("Received data pub: \(pub.path)")
                subject.send(PubMessage(path: pub.path, content: data))
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
        case .ping:
            break
        case .pong:
            break
        case .viabilityChanged(let viable):
            print("Viability changed: \(viable)")
            break
        case .reconnectSuggested(let suggested):
            // TODO: Reconnect? If true?
            print("Reconnect suggested: \(suggested)")
            break
        case .cancelled:
            print("Cancelled")
            isConnected = false
        case .error(let error):
            isConnected = false
            print("Received error: \(String(describing: error))")
        }
    }

    init(url: URL) {
        request = URLRequest(url: url)
        socket = WebSocket(request: request)
        socket.delegate = self
        // TODO: Give this a different DispatchQueue?
    }
    
    func connect() {
        return socket.connect()
    }
    
    // TODO: Use NES errors
    func subscribe<Message>(path: String, for type: Message.Type) -> AnyPublisher<Message, Error>
    where Message : Decodable {
        // TODO: Should this be tracked by ID for unsub?
        let id = UUID()
        let outgoingMessage = ClientSub(id: NesID(string: id.uuidString), path: path)
        let data = try! JSONEncoder().encode(outgoingMessage)

        subscriptions.insert(path)

        if isConnected {
            print("I think I should write data")
            socket.write(data: data)
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
