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
            .subscribe(path: "/transactions/99d096e5-54c3-4007-bcd5-eaf67197e78b", for: Transaction.self)
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
        XCTAssertEqual(id, "99d096e5-54c3-4007-bcd5-eaf67197e78b")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}