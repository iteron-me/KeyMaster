import XCTest
@testable import KeyMaster

final class HintGeneratorTests: XCTestCase {
    func testGenerateUsesSingleLetterHintsFirst() {
        XCTAssertEqual(
            HintGenerator.generate(count: 5, alphabet: ["A", "S", "D"]),
            ["A", "S", "D", "AA", "AS"]
        )
    }

    func testGenerateReturnsUniqueHintsForMVPMaximum() {
        let hints = HintGenerator.generate(count: 120)

        XCTAssertEqual(hints.count, 120)
        XCTAssertEqual(Set(hints).count, 120)
    }

    func testGenerateHandlesEmptyInput() {
        XCTAssertEqual(HintGenerator.generate(count: 0), [])
        XCTAssertEqual(HintGenerator.generate(count: 5, alphabet: []), [])
    }
}
