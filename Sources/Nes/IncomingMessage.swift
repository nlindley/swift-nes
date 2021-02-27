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

// FIXME: Is this helpful? Should `type` be removed?
protocol IncomingMessage: Decodable {
    var type: IncomingMessageType { get }
}

// Heartbeat: server -> client -> server
struct ServerPing: IncomingMessage {
    let type = IncomingMessageType.ping;
    
    enum CodingKeys: CodingKey {}
}

struct HeartbeatConfig: Decodable {
    let interval: Double
    let timeout: Double
}

struct ServerHello: IncomingMessage {
    let type = IncomingMessageType.hello
    let id: NesId
    // TODO: Decode from `false | HeartbeatConfig`
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

struct ServerReauth: IncomingMessage {
    let type = IncomingMessageType.reauth
    let id: NesId
    
    enum CodingKeys: CodingKey {
        case id
    }
}

struct ServerRequet<Payload: Decodable>: IncomingMessage {
    let type = IncomingMessageType.request
    let id: NesId
    let statusCode: Int
    // TODO: Can this be nil on, e.g., a 204?
    let payload: Payload
    let headers: [String:String]?
    
    enum CodingKeys: CodingKey {
        case id
        case statusCode
        case payload
        case headers
    }
}

struct ServerMessage<Value: Decodable>: IncomingMessage {
    let type = IncomingMessageType.message
    let id: NesId
    let message: Value
    
    enum CodingKeys: CodingKey {
        case id
        case message
    }
}

struct ServerSub: IncomingMessage {
    let type = IncomingMessageType.sub
    let id: NesId
    let path: String
    
    enum CodingKeys: CodingKey {
        case id
        case path
    }
}

struct ServerUnsub: IncomingMessage {
    let type = IncomingMessageType.unsub
    let id: NesId
    
    enum CodingKeys: CodingKey {
        case id
    }
}

struct ServerUpdate<Value: Decodable>: IncomingMessage {
    let type = IncomingMessageType.update
    let message: Value
    
    enum CodingKeys: CodingKey {
        case message
    }
}

struct ServerRevoke<Value: Decodable>: IncomingMessage {
    let type = IncomingMessageType.revoke
    let path: String
    let message: Value
    
    enum CodingKeys: CodingKey {
        case path
        case message
    }
}
