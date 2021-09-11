import XCTest
import Combine
@testable import Nes
final class NesTests: XCTestCase {
    private var cancellables: Set<AnyCancellable>!
    private var client: Client!
    
    override func setUp() {
        super.setUp()
        cancellables = []

        let url = URL(string: "ws://127.0.0.1:3000")!
        client = Client(url: url)
    }
    
    override func tearDown() {
        client.disconnect()
    }

    func testConsumesMultipleMessages() {
        struct Counter: Decodable {
            let count: Int
        }
        
        var counts: [Int] = []
        var error: Error?
        let expectation = XCTestExpectation(description: "Receives all messages")
        
        client
            .subscribe(path: "/counter/3", for: Counter.self)
            .map { $0.count }
            .collect()
            .sink { completion in
                switch completion {
                case .failure(let err):
                    error = err
                case .finished:
                    expectation.fulfill()
                }
            } receiveValue: { receivedCounts in
                counts = receivedCounts
            }
            .store(in: &cancellables)

        
        let _ = client.connect(auth: nil)

        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertNil(error)
        XCTAssertEqual(counts, [1, 2, 3])
    }
    
    func testFulfillsRequestWithResponse() {
        struct TestPayload: Codable, Equatable {
            let hello: String
        }
        
        var response: TestPayload?;
        var error: Error?
        let expectation = XCTestExpectation(description: "Receives response")
        
        client
            .connect(auth: nil)
            .flatMap {
                $0.request(method: .POST, path: "/echo", payload: TestPayload(hello: "world"), for: TestPayload.self)
            }
            .sink { completion in
                switch completion {
                case .failure(let err):
                    error = err
                case .finished:
                    expectation.fulfill()
                }
            } receiveValue: { payload in
                response = payload
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertNil(error)
        XCTAssertEqual(response, TestPayload(hello: "world"))
    }

    static var allTests = [
        ("testConsumesMultipleMessages", testConsumesMultipleMessages),
    ]
}
