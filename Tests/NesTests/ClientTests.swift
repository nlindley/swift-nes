import XCTest
import Combine
@testable import Nes
final class NesTests: XCTestCase {
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = []
    }

    func testExample() {        
        struct Transaction: Decodable {
            let id: String
        }
        
        let url = URL(string: "ws://demo-api.loves.com/ws/papi")!
        var id: String?
        var error: Error?
        let client = Client(url: url)
        let expectation = XCTestExpectation(description: "Receives Transaction")
        
        client
            .subscribe(path: "/transactions/DBBD862D-AAA9-48BB-A416-ABB0EC210C87", for: Transaction.self)
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
        
        client.connect(auth: getAuthHeader)

        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertNil(error)
        XCTAssertEqual(id, "DBBD862D-AAA9-48BB-A416-ABB0EC210C87".lowercased())
    }
    
    func getAuthHeader() -> Future<[String: String]?, Never> {
        let future = Future<[String: String]?, Never> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IlJrUTROREZHUmtVek5qazBOalJEUmtNMk5ERXpOVVZET1RORFFrWTJORVU1UXpkQ1FqTXlRdyJ9.eyJodHRwOi8vbG92ZXMuY29tL2xvdmVzSWQiOiI3MDU2MThiOS02NzJiLTQwYzMtODc1NS02ZDYzYTMyMTJjYmIiLCJpc3MiOiJodHRwczovL2FwcDczMTI2NDQ5LmF1dGgwLmNvbS8iLCJzdWIiOiJhdXRoMHw1ZGJhM2VhNzc0YjM3ZTBjN2IzNzA4ZjEiLCJhdWQiOiJodHRwczovL2xvdmVzY2xvdWRzZXJ2aWNlcy5sb3Zlcy5jb20iLCJpYXQiOjE2Mjc2ODA2NzYsImV4cCI6MTYyNzY4Nzg3NiwiYXpwIjoiTkdMeURCNFp0Q3p5Y25EY1dWNU5pQlRGZEZldWFWcjciLCJzY29wZSI6InNlYXJjaDpwcm9maWxlIHVwZGF0ZTpwcm9maWxlIHVwZGF0ZTpsb3lhbHR5IHJlYWQ6cHJvZmlsZSByZWFkOmxveWFsdHkgcmVhZDpwcm9maWxlLm5hbWUgcmVhZDpsb3lhbHR5LnN1bW1hcnkgY3JlYXRlOm9yZGVyIG9mZmxpbmVfYWNjZXNzIiwiZ3R5IjoicGFzc3dvcmQifQ.E2di8R5NS6Ek3Uary2L4hgwoKFHHHe8lxjR_nozj6qW_wk60evjk6uOLcHEhmtd3BLvXWaNM4kXBdqCz-XO7NLU166Be0dz4iP7z3zDgSTH9yJqWulDkGVVlxCCsUyjttbvpjvPfnUqUr8OI3-fA_imOd7gYm0ZXP0gr7TkrCDJAVowaipe9hLrj1G1-PPZTBF2m0oHnJc86QxRZ3aAfB6HyQ6vUEf3UlYbHjljYDc4toqzLCF2NBFhc5x57v_kR4UNgARvtl4KoniyljyETVQ3_3FbzsbmBwAIrIMNBktddfOfxm4gZloIZk-lDyuksHXAKhgYljR74rZYJFUXYGA"
                
                promise(.success(["authorization": "Bearer \(token)"]))
            }
        }
        
        return future
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
