enum ClientRequestType: String, Encodable {
    case ping
    case hello
    case reauth
    case request
    case sub
    case unsub
    case message
}

protocol ClientRequest: Encodable {
    var type: ClientRequestType { get }
    var id: NesId { get }
}

// Heartbeat: server -> client -> server
struct Ping: ClientRequest {
    let type = ClientRequestType.ping
    let id: NesId
}

// client -> server -> client
struct Hello<Auth: Encodable>: ClientRequest {
    let type = ClientRequestType.hello
    let id: NesId
    let version = "2"
    let auth: Auth
    let subs: [String]?
}

// client -> server -> client
struct Reauth<Auth: Encodable>: ClientRequest {
    let type = ClientRequestType.reauth
    let id: NesId
    let auth: Auth
}

// client -> server -> client
struct Request<Payload: Encodable>: Encodable {
    let type = "request"
    let id: NesId
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

// https://bugs.swift.org/browse/SR-8458
extension Never: Codable {
    public init(from decoder: Decoder) throws {
        fatalError("Cannot construct Never")
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("Should not have constructed Never")
    }
}

extension Request where Payload == Never {
    init(method: HTTPMethod, path: String, headers: [String:String]? = nil) {
        self.id = .numberId(1234)
        self.method = method
        self.path = path
        self.payload = nil
        self.headers = headers
    }
}

// client -> server [-> client]
struct Sub: ClientRequest {
    let type = ClientRequestType.sub
    let id: NesId
    let path: String
}

// client -> server -> client
struct Unsub: ClientRequest {
    let type = ClientRequestType.unsub
    let id: NesId
    let path: String
}

// client -> server [-> client]
struct Message<Value: Encodable>: ClientRequest {
    let type = ClientRequestType.message
    let id: NesId
    let message: Value
}
