import XCTest
@testable import Nes

final class NesTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let expectation = XCTestExpectation(description: "Say hello")

        let urlSession = URLSession(configuration: .default)
        let url = URL(string: "wss://loves-mock-pay-api.herokuapp.com")!
        let webSocket = urlSession.webSocketTask(with: url)
        
        webSocket.resume()
        
        let hello = ClientHello<[String:String]?>(id: .stringId(UUID().uuidString), auth: nil, subs: nil)
        let encoder = JSONEncoder()
        let message = try! encoder.encode(hello)
        
        
        webSocket.send(.data(message)) { error in
            if let error = error {
                print("WebSocket sending error: \(error)")
            }
        }
        
        webSocket.receive { result in
            switch (result) {
            case .failure(let error):
                XCTFail("\(error)")
                print("Failed to receive message: \(error)")
            case .success(.data(let data)):
                let decoder = JSONDecoder()
                print("Received data: \(try! decoder.decode(ServerHello.self, from: data)))")
            case .success(.string(let string)):
                let decoder = JSONDecoder()
                print("Received string: \(try! decoder.decode(ServerHello.self, from: string.data(using: .utf8)!))")
            @unknown default:
                fatalError("Received unexpected WebSocket response")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
