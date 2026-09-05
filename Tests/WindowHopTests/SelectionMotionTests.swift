import XCTest
@testable import WindowHopCore

final class SelectionMotionTests: XCTestCase {
    func testSameSelectionNeedsNoAnimation() {
        XCTAssertEqual(SelectionMotion.duration(from: 4, to: 4, columns: 3), 0)
    }

    func testAdjacentStepIsFasterThanLongGridJump() {
        let adjacent = SelectionMotion.duration(from: 0, to: 1, columns: 4)
        let distant = SelectionMotion.duration(from: 0, to: 11, columns: 4)
        XCTAssertGreaterThan(adjacent, 0)
        XCTAssertLessThan(adjacent, distant)
        XCTAssertLessThanOrEqual(distant, SelectionMotion.maximumDuration)
    }

    func testInvalidPreviousSelectionStartsImmediately() {
        XCTAssertEqual(SelectionMotion.duration(from: -1, to: 0, columns: 0), 0)
    }
}
