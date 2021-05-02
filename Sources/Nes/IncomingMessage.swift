import Foundation

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

/* Doesn’t handle payloads since those aren’t known until a subscription occurs */
enum IncomingMessage: Decodable, Equatable {
    case ping
    case hello(ServerHello)
    case reauth(ServerReauth)
    case request(ServerRequest)
    case sub(ServerSub)
    case unsub(ServerUnsub)
    case message(ServerMessage)
    case update(ServerUpdate)
    case pub(ServerPub)
    case revoke(ServerRevoke)
    
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
        case "sub":
            let sub = try ServerSub(from: decoder)
            self = .sub(sub)
        case "unsub":
            let unsub = try ServerUnsub(from: decoder)
            self = .unsub(unsub)
        case "message":
            let message = try ServerMessage(from: decoder)
            self = .message(message)
        case "update":
            let update = try ServerUpdate(from: decoder)
            self = .update(update)
        case "pub":
            let pub = try ServerPub(from: decoder)
            self = .pub(pub)
        case "revoke":
            let revoke = try ServerRevoke(from: decoder)
            self = .revoke(revoke)
        case "request":
            let request = try ServerRequest(from: decoder)
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
    let id: NesID
    let heartbeat: HeartbeatConfig?
}

extension ServerHello: Decodable {
    enum CodingKeys: CodingKey {
        case id
        case heartbeat
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(NesID.self, forKey: .id)
        
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
    let id: NesID
}

struct ServerRequest: Decodable, Equatable {
    let id: NesID
    let statusCode: Int
    let headers: [String:String]?
}

struct ServerMessage: Decodable, Equatable {
    let id: NesID
}

struct ServerSub: Decodable, Equatable{
    let id: NesID
    let path: String
}

struct ServerUnsub: Decodable, Equatable {
    let id: NesID
}

struct ServerPub: Decodable, Equatable {
    let path: String
}

struct ServerUpdate: Decodable, Equatable {}

struct ServerRevoke: Decodable, Equatable {
    let path: String
}
