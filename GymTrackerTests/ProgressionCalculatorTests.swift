import XCTest
@testable import GymTracker

final class ProgressionCalculatorTests: XCTestCase {
    func testSuggestsSmallestTenRMIncrease() {
        let suggestion = ProgressionCalculator.nextProgression(
            lastWeight: 80, lastReps: 8, increment: 2.5, allowIncrease: true
        )
        XCTAssertNotNil(suggestion)
        let baseline = ProgressionCalculator.estimatedTenRepMax(weight: 80, reps: 8)
        XCTAssertGreaterThan(suggestion!.estTenRM, baseline)
        // The suggested move must be one of the legal steps.
        let isRepHold = suggestion!.weight == 82.5 && suggestion!.reps == 8
        let isRepUp = suggestion!.weight == 80 && suggestion!.reps == 9
        let isDrop = suggestion!.weight == 82.5 && suggestion!.reps == 7
        XCTAssertTrue(isRepHold || isRepUp || isDrop)
    }

    func testHoldWhenIncreaseNotAllowed() {
        let suggestion = ProgressionCalculator.nextProgression(
            lastWeight: 80, lastReps: 8, increment: 2.5, allowIncrease: false
        )
        XCTAssertEqual(suggestion?.weight, 80)
        XCTAssertEqual(suggestion?.reps, 8)
        XCTAssertEqual(suggestion?.kind, .hold)
    }

    func testRepCapForcesWeightIncrease() {
        let suggestion = ProgressionCalculator.nextProgression(
            lastWeight: 60, lastReps: 12, increment: 2.5, allowIncrease: true
        )
        XCTAssertEqual(suggestion?.weight, 62.5)
        XCTAssertLessThan(suggestion?.reps ?? 99, 12)
    }

    func testBodyweightProgressesByRep() {
        let suggestion = ProgressionCalculator.nextProgression(
            lastWeight: 0, lastReps: 10, increment: 2.5, allowIncrease: true
        )
        XCTAssertEqual(suggestion?.weight, 0)
        XCTAssertEqual(suggestion?.reps, 11)
    }

    func testZeroRepsGivesNoSuggestion() {
        XCTAssertNil(ProgressionCalculator.nextProgression(
            lastWeight: 80, lastReps: 0, increment: 2.5, allowIncrease: true
        ))
    }

    func testComebackNeverExceedsLastWeight() {
        let suggestion = ProgressionCalculator.comeback(lastWeight: 100, lastReps: 8, step: 2.5)
        XCTAssertNotNil(suggestion)
        XCTAssertLessThanOrEqual(suggestion!.weight, 100)
        XCTAssertEqual(suggestion!.kind, .comeback)
        XCTAssertEqual(suggestion!.reps, 8)
    }

    func testDeloadBacksOffRoughlyFifteenPercent() {
        let suggestion = ProgressionCalculator.deload(lastWeight: 100, lastReps: 8, step: 2.5)
        XCTAssertEqual(suggestion?.weight, 85)
        XCTAssertEqual(suggestion?.kind, .deload)
    }

    func testEpleyOneRepMax() {
        XCTAssertEqual(ProgressCalculator.epleyOneRepMax(weight: 100, reps: 1), 100)
        XCTAssertEqual(ProgressCalculator.epleyOneRepMax(weight: 100, reps: 10), 100 * (1 + 10.0 / 30))
        XCTAssertEqual(ProgressCalculator.epleyOneRepMax(weight: 0, reps: 5), 0)
        XCTAssertEqual(ProgressCalculator.epleyOneRepMax(weight: 100, reps: 0), 0)
    }
}
