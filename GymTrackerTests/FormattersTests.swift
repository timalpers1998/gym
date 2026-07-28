import XCTest
@testable import GymTracker

final class FormattersTests: XCTestCase {
    func testParseWeightAcceptsCommaDecimal() {
        XCTAssertEqual(Format.parseWeight("82,5"), 82.5)
        XCTAssertEqual(Format.parseWeight("82.5"), 82.5)
        XCTAssertEqual(Format.parseWeight("80"), 80)
        XCTAssertEqual(Format.parseWeight("junk"), 0)
        XCTAssertEqual(Format.parseWeight(""), 0)
    }

    func testEditableWeightDropsTrailingZero() {
        XCTAssertEqual(Format.editableWeight(80), "80")
        XCTAssertEqual(Format.editableWeight(82.5), "82.5")
    }

    func testParseDurationSecondsAndMinutes() {
        XCTAssertEqual(Format.parseDuration("90"), 90)
        XCTAssertEqual(Format.parseDuration("1:30"), 90)
        XCTAssertEqual(Format.parseDuration("0:45"), 45)
        XCTAssertEqual(Format.parseDuration(" 2:05 "), 125)
        XCTAssertEqual(Format.parseDuration("junk"), 0)
        XCTAssertEqual(Format.parseDuration(""), 0)
        XCTAssertEqual(Format.parseDuration("-5"), 0)
    }

    func testEditableDurationRoundTrips() {
        for seconds in [0, 45, 59, 60, 90, 125, 600] {
            XCTAssertEqual(Format.parseDuration(Format.editableDuration(seconds)), seconds)
        }
        XCTAssertEqual(Format.editableDuration(45), "45")
        XCTAssertEqual(Format.editableDuration(90), "1:30")
        XCTAssertEqual(Format.editableDuration(125), "2:05")
    }
}
