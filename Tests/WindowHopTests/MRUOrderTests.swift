import XCTest
@testable import WindowHopCore

final class MRUOrderTests: XCTestCase {
    func testNewItemsAppendAtEnd() {
        var mru = MRUOrder<String>()
        mru.add("a")
        mru.add("b")
        XCTAssertEqual(mru.ids, ["a", "b"])
    }

    func testAddingKnownItemIsIgnored() {
        var mru = MRUOrder<String>()
        mru.add("a")
        XCTAssertFalse(mru.add("a"))
        XCTAssertEqual(mru.ids, ["a"])
    }

    func testFocusMovesToFront() {
        var mru = MRUOrder<String>()
        mru.add("a")
        mru.add("b")
        mru.add("c")
        mru.focused("c")
        XCTAssertEqual(mru.ids, ["c", "a", "b"])
        mru.focused("a")
        XCTAssertEqual(mru.ids, ["a", "c", "b"])
    }

    func testFocusKeepsPreviouslyFocusedWindowSecondForFastToggle() {
        var mru = MRUOrder<String>()
        mru.add("chrome")
        mru.add("finder")
        mru.add("idea")

        mru.focused("finder")
        XCTAssertEqual(mru.ids, ["finder", "chrome", "idea"])

        mru.focused("idea")
        XCTAssertEqual(mru.ids, ["idea", "finder", "chrome"])
    }

    func testFocusUnknownInsertsAtFront() {
        var mru = MRUOrder<String>()
        mru.add("a")
        mru.focused("x")
        XCTAssertEqual(mru.ids, ["x", "a"])
    }

    func testRemove() {
        var mru = MRUOrder<String>()
        mru.add("a")
        mru.add("b")
        mru.remove("a")
        XCTAssertEqual(mru.ids, ["b"])
        mru.remove("missing")
        XCTAssertEqual(mru.ids, ["b"])
    }
}
