import XCTest
import Combine
@testable import Nes

struct Transaction: Decodable {
    let id: String
}

final class NesTests: XCTestCase {
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = []
    }

    func testExample() {
        let url = URL(string: "ws://localhost:5000")!
        var id: String?
        var error: Error?
        let client = Client(url: url)
        
        let expectation = XCTestExpectation(description: "Receives Transaction")
        
        client
            .subscribe(path: "/transactions/3907da17-306c-4711-9c01-12e4489a570b", for: Transaction.self)
            .first()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let encounteredError):
                    error = encounteredError
                }
                
                expectation.fulfill()
            }, receiveValue: { transaction in
                id = transaction.id
            })
            .store(in: &cancellables)
        
        client.connect()

        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertNil(error)
        XCTAssertEqual(id, "3907da17-306c-4711-9c01-12e4489a570b")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
