import XCTest
@testable import Nes

final class IncomingMessageTests: XCTestCase {
    func testDecodesServerPing() {
        let data = """
            { "type": "ping" }
        """.data(using: .utf8)!

        let decoded = try! JSONDecoder().decode(IncomingMessage.self, from: data)

        XCTAssertEqual(decoded, .ping)
    }
    
    func testDecodesServerHello() {
        let data = """
            {
                "type": "hello",
                "id": 1,
                "heartbeat": {
                    "interval": 15000,
                    "timeout": 5000
                },
                "socket": "abc-123"
            }
        """.data(using: .utf8)!
        
        let expected: IncomingMessage = .hello(ServerHello.init(id: .numberId(1), heartbeat: .init(interval: 15000, timeout: 5000)))
        let decoded = try! JSONDecoder().decode(IncomingMessage.self, from: data)
        
        XCTAssertEqual(decoded, expected)
    }
    
    func testDecodesServerSub() {
        let data = """
            { "type": "sub", "id": 4, "path": "/path/to/4" }
        """.data(using: .utf8)!
        
        let expected: IncomingMessage = .sub(ServerSub(id: .numberId(4), path: "/path/to/4"))
        let decoded = try! JSONDecoder().decode(IncomingMessage.self, from: data)
        
        XCTAssertEqual(decoded, expected)
    }
    
    func testDecodesServerUnsub() {
        let data = """
            { "type": "unsub", "id": 5 }
        """.data(using: .utf8)!
        
        let expected: IncomingMessage = .unsub(ServerUnsub(id: .numberId(5)))
        let decoded = try! JSONDecoder().decode(IncomingMessage.self, from: data)
        
        XCTAssertEqual(decoded, expected)
    }
    
    func testDecodesServerMessage() {
        let data = """
            {
                "type": "message",
                "id": 3,
                "message": "hi"
            }
        """.data(using: .utf8)!
        
        let expected: IncomingMessage = .message(ServerMessage(id: .numberId(3)))
        let decoded = try! JSONDecoder().decode(IncomingMessage.self, from: data)
        
        XCTAssertEqual(decoded, expected)
    }
    
    func testDecodesServerPub() {
        let data = """
            {
                "type": "pub",
                "path": "/box/blue",
                "message": "my message"
            }
        """.data(using: .utf8)!
        
        let expected: IncomingMessage = .pub(ServerPub(path: "/box/blue"))
        let decoded = try! JSONDecoder().decode(IncomingMessage.self, from: data)
        
        XCTAssertEqual(decoded, expected)
    }
    
    func testDecodesServerUpdate() {
        let data = """
            { "type": "update", "message": "my update" }
        """.data(using: .utf8)!
        
        let expected: IncomingMessage = .update(ServerUpdate())
        let decoded = try! JSONDecoder().decode(IncomingMessage.self, from: data)
        
        XCTAssertEqual(decoded, expected)
    }
    
    func testDecodesServerReauth() {
        let data = """
            { "type": "reauth", "id": 1 }
        """.data(using: .utf8)!
        
        let expected: IncomingMessage = .reauth(ServerReauth(id: .numberId(1)))
        let decoded = try! JSONDecoder().decode(IncomingMessage.self, from: data)
        
        XCTAssertEqual(decoded, expected)
    }
    
    func testDecodesServerRevoke() {
        let data = """
            { "type": "revoke", "path": "/box/blue", "message": "reason" }
        """.data(using: .utf8)!
        
        let expected: IncomingMessage = .revoke(ServerRevoke(path: "/box/blue"))
        let decoded = try! JSONDecoder().decode(IncomingMessage.self, from: data)
        
        XCTAssertEqual(decoded, expected)
    }
    
    func testDecodesServerRequest() {
        let data = """
            { "type": "request", "id": 2, "payload": "ok", "statusCode": 200, "headers": { "content-type": "text/plain" } }
        """.data(using: .utf8)!
        
        let expected: IncomingMessage = .request(ServerRequest(id: .numberId(2), statusCode: 200, headers: ["content-type": "text/plain"]))
        let decoded = try! JSONDecoder().decode(IncomingMessage.self, from: data)
        
        XCTAssertEqual(decoded, expected)
    }
}
