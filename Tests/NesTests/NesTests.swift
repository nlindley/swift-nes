import XCTest
@testable import Nes

final class NesTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Nes().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
