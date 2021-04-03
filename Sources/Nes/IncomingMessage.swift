enum IncomingMessageType: String, Decodable {
    case ping
    case hello
    case reauth
    case request
    case sub
    case unsub
    case message
    case update
    case pub
    case revoke
}

enum IncomingMessage<
    Msg: Decodable & Equatable,
    Pub: Decodable & Equatable,
    Update: Decodable & Equatable,
    Revoke: Decodable & Equatable,
    Request: Decodable & Equatable
>: Decodable, Equatable {
    case ping
    case hello(ServerHello)
    case reauth(ServerReauth)
    case request(ServerRequest<Request>)
    case sub(ServerSub)
    case unsub(ServerUnsub)
    case message(ServerMessage<Msg>)
    case update(ServerUpdate<Update>)
    case pub(ServerPub<Pub>)
    case revoke(ServerRevoke<Revoke>)
    
    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "ping":
            self = .ping
        case "hello":
            let hello = try ServerHello(from: decoder)
            self = .hello(hello)
        case "reauth":
            let reauth = try ServerReauth(from: decoder)
            self = .reauth(reauth)
//        case "request":
        case "sub":
            let sub = try ServerSub(from: decoder)
            self = .sub(sub)
        case "unsub":
            let unsub = try ServerUnsub(from: decoder)
            self = .unsub(unsub)
        case "message":
            let message = try ServerMessage<Msg>(from: decoder)
            self = .message(message)
        case "update":
            let update = try ServerUpdate<Update>(from: decoder)
            self = .update(update)
        case "pub":
            let pub = try ServerPub<Pub>(from: decoder)
            self = .pub(pub)
        case "revoke":
            let revoke = try ServerRevoke<Revoke>(from: decoder)
            self = .revoke(revoke)
        case "request":
            let request = try ServerRequest<Request>(from: decoder)
            self = .request(request)
        default:
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected known type for incoming message");
            throw DecodingError.dataCorrupted(context)
        }
    }
}

struct HeartbeatConfig: Decodable, Equatable {
    let interval: Double
    let timeout: Double
}

struct ServerHello: Equatable {
    let id: NesId
    let heartbeat: HeartbeatConfig?
}

extension ServerHello: Decodable {
    enum CodingKeys: CodingKey {
        case id
        case heartbeat
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(NesId.self, forKey: .id)
        
        if let heartbeat = try? container.decode(HeartbeatConfig.self, forKey: .heartbeat) {
            self.heartbeat = heartbeat
            return
        } else if let heartbeat = try? container.decode(Bool.self, forKey: .heartbeat), heartbeat == false {
            self.heartbeat = nil
            return
        } else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected false or heartbeat object.")
            throw DecodingError.dataCorrupted(context)
        }
    }
}

struct ServerReauth: Decodable, Equatable {
    let id: NesId
}

struct ServerRequest<Payload: Decodable & Equatable>: Decodable, Equatable {
    let id: NesId
    let statusCode: Int
    // TODO: Can this be nil on, e.g., a 204?
    let payload: Payload
    let headers: [String:String]?
}

struct ServerMessage<Value: Decodable & Equatable>: Decodable, Equatable {
    let id: NesId
    let message: Value
}

struct ServerSub: Decodable, Equatable{
    let id: NesId
    let path: String
}

struct ServerUnsub: Decodable, Equatable {
    let id: NesId
}

struct ServerPub<Value: Decodable & Equatable>: Decodable, Equatable {
    let path: String
    let message: Value
}

struct ServerUpdate<Value: Decodable & Equatable>: Decodable, Equatable {
    let message: Value
}

struct ServerRevoke<Value: Decodable & Equatable>: Decodable, Equatable {
    let path: String
    let message: Value
}
