enum OutgoingMessageType: String, Encodable {
    case ping
    case hello
    case reauth
    case request
    case sub
    case unsub
    case message
}

protocol OutgoingMessage: Encodable {
    var type: OutgoingMessageType { get }
    var id: NesID { get }
}

// Heartbeat: server -> client -> server
struct ClientPing: OutgoingMessage {
    let type = OutgoingMessageType.ping
    let id: NesID
}

// client -> server -> client
struct ClientHello<Auth: Encodable>: OutgoingMessage {
    let type = OutgoingMessageType.hello
    let id: NesID
    let version = "2"
    let auth: Auth
    let subs: [String]?
}

// client -> server -> client
struct ClientReauth<Auth: Encodable>: OutgoingMessage {
    let type = OutgoingMessageType.reauth
    let id: NesID
    let auth: Auth
}

// client -> server -> client
struct ClientRequest<Payload: Encodable>: Encodable {
    let type = "request"
    let id: NesID
    let method: HTTPMethod
    let path: String
    let headers: [String:String]?
    let payload: Payload?
    
    init(method: HTTPMethod, path: String, payload: Payload, headers: [String:String]? = nil) {
        self.id = .numberId(1234)
        self.method = method
        self.path = path
        self.payload = payload
        self.headers = headers
    }
}

extension ClientRequest where Payload == Never {
    init(method: HTTPMethod, path: String, headers: [String:String]? = nil) {
        self.id = .numberId(1234)
        self.method = method
        self.path = path
        self.payload = nil
        self.headers = headers
    }
}

// client -> server [-> client]
struct ClientSub: OutgoingMessage {
    let type = OutgoingMessageType.sub
    let id: NesID
    let path: String
}

// client -> server -> client
struct ClientUnsub: OutgoingMessage {
    let type = OutgoingMessageType.unsub
    let id: NesID
    let path: String
}

// client -> server [-> client]
struct ClientMessage<Value: Encodable>: OutgoingMessage {
    let type = OutgoingMessageType.message
    let id: NesID
    let message: Value
}
