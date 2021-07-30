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
        let token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IlJrUTROREZHUmtVek5qazBOalJEUmtNMk5ERXpOVVZET1RORFFrWTJORVU1UXpkQ1FqTXlRdyJ9.eyJodHRwOi8vbG92ZXMuY29tL2xvdmVzSWQiOiI3MDU2MThiOS02NzJiLTQwYzMtODc1NS02ZDYzYTMyMTJjYmIiLCJpc3MiOiJodHRwczovL2FwcDczMTI2NDQ5LmF1dGgwLmNvbS8iLCJzdWIiOiJhdXRoMHw1ZGJhM2VhNzc0YjM3ZTBjN2IzNzA4ZjEiLCJhdWQiOlsiaHR0cHM6Ly9sb3Zlc2Nsb3Vkc2VydmljZXMubG92ZXMuY29tIiwiaHR0cHM6Ly9hcHA3MzEyNjQ0OS5hdXRoMC5jb20vdXNlcmluZm8iXSwiaWF0IjoxNjI3NjYzNzM4LCJleHAiOjE2Mjc2NzA5MzgsImF6cCI6Ik5HTHlEQjRadEN6eWNuRGNXVjVOaUJURmRGZXVhVnI3Iiwic2NvcGUiOiJvcGVuaWQgZW1haWwgcHJvZmlsZSBzZWFyY2g6cHJvZmlsZSB1cGRhdGU6cHJvZmlsZSB1cGRhdGU6bG95YWx0eSByZWFkOnByb2ZpbGUgcmVhZDpsb3lhbHR5IHJlYWQ6cHJvZmlsZS5uYW1lIHJlYWQ6bG95YWx0eS5zdW1tYXJ5IGNyZWF0ZTpvcmRlciBvZmZsaW5lX2FjY2VzcyIsImd0eSI6InBhc3N3b3JkIn0.PJhMvOVcsvEQEe8RsGPdp90iUGYFthth9zeFVAisv53mT473tuJkx208F4ukYs2WNzZ-Dq9dpVPd7TZdqB12xysdIrWT7Eo3tkuK7yFGqo1zM-29Q7F-JFwszw1FIa3Hsk5FiQXors4BnxCf2ZsU-aH-O-I21V6qcKPHgrNcBytodro4GQUSO3piTIymt9PCL1mW0l7Mi1os-spJGlQR9yhZbbVZ7BpyrNZMiQun-LWNX0kHCbO9aD4clwYtFcKHWrbdhjjuBPzVGDnB2RCD0Lw3mCTG1oW2ywyjWvS8fRBPHoB5oiY2xrhJWrJltjBhBtlBgJQDhR6GG6QZRK8DdA"
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
        
        client.connect(authToken: token)

        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertNil(error)
        XCTAssertEqual(id, "3907da17-306c-4711-9c01-12e4489a570b")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
