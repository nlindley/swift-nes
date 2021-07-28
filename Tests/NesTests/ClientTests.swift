import XCTest
import Combine
@testable import Nes
final class NesTests: XCTestCase {
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = []
    }

    func testConsumesMultipleMessages() {
        struct Counter: Decodable {
            let count: Int
        }
        
        let url = URL(string: "ws://127.0.0.1:3000")!
        var counts: [Int] = []
        var error: Error?
        let client = Client(url: url)
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

        
        client.connect(auth: nil)

        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertNil(error)
        XCTAssertEqual(counts, [1, 2, 3])
    }

    static var allTests = [
        ("testConsumesMultipleMessages", testConsumesMultipleMessages),
    ]
}
