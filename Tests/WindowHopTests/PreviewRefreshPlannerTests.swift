import XCTest
@testable import WindowHopCore

final class PreviewRefreshPlannerTests: XCTestCase {
    func testMissingWindowsBeatStaleCachedWindows() {
        let entries = [
            PreviewRefreshPlanner.Entry(id: "cached-1", hasCachedImage: true,
                                        signatureMatches: true, age: 10),
            PreviewRefreshPlanner.Entry(id: "missing-1", hasCachedImage: false,
                                        signatureMatches: false, age: nil),
            PreviewRefreshPlanner.Entry(id: "cached-2", hasCachedImage: true,
                                        signatureMatches: true, age: 20),
            PreviewRefreshPlanner.Entry(id: "missing-2", hasCachedImage: false,
                                        signatureMatches: false, age: nil),
        ]

        XCTAssertEqual(
            PreviewRefreshPlanner.plan(entries: entries, selectedID: nil,
                                       freshnessInterval: 2),
            ["missing-1", "missing-2", "cached-1", "cached-2"])
    }

    func testSelectedMissingWindowIsFirst() {
        let entries = [
            PreviewRefreshPlanner.Entry(id: 1, hasCachedImage: false,
                                        signatureMatches: false, age: nil),
            PreviewRefreshPlanner.Entry(id: 2, hasCachedImage: false,
                                        signatureMatches: false, age: nil),
            PreviewRefreshPlanner.Entry(id: 3, hasCachedImage: false,
                                        signatureMatches: false, age: nil),
        ]

        XCTAssertEqual(
            PreviewRefreshPlanner.plan(entries: entries, selectedID: 3,
                                       freshnessInterval: 2),
            [3, 1, 2])
    }

    func testFreshCacheIsSkippedButSignatureChangeForcesRefresh() {
        let entries = [
            PreviewRefreshPlanner.Entry(id: "fresh", hasCachedImage: true,
                                        signatureMatches: true, age: 0.2),
            PreviewRefreshPlanner.Entry(id: "moved", hasCachedImage: true,
                                        signatureMatches: false, age: 0.1),
            PreviewRefreshPlanner.Entry(id: "old", hasCachedImage: true,
                                        signatureMatches: true, age: 3),
        ]

        XCTAssertEqual(
            PreviewRefreshPlanner.plan(entries: entries, selectedID: "fresh",
                                       freshnessInterval: 2),
            ["moved", "old"])
    }

    func testSelectedStaleCacheBeatsOtherStaleCachesButNotMissingWindows() {
        let entries = [
            PreviewRefreshPlanner.Entry(id: "stale-a", hasCachedImage: true,
                                        signatureMatches: true, age: 10),
            PreviewRefreshPlanner.Entry(id: "missing", hasCachedImage: false,
                                        signatureMatches: false, age: nil),
            PreviewRefreshPlanner.Entry(id: "selected", hasCachedImage: true,
                                        signatureMatches: true, age: 10),
        ]

        XCTAssertEqual(
            PreviewRefreshPlanner.plan(entries: entries, selectedID: "selected",
                                       freshnessInterval: 2),
            ["missing", "selected", "stale-a"])
    }
    func testIndexPlanAvoidsIDRoundTripAndPreservesPriority() {
        let entries = [
            PreviewRefreshPlanner.Entry(id: "fresh", hasCachedImage: true,
                                        signatureMatches: true, age: 0.1),
            PreviewRefreshPlanner.Entry(id: "missing", hasCachedImage: false,
                                        signatureMatches: false, age: nil),
            PreviewRefreshPlanner.Entry(id: "selected", hasCachedImage: true,
                                        signatureMatches: true, age: 8),
            PreviewRefreshPlanner.Entry(id: "stale", hasCachedImage: true,
                                        signatureMatches: true, age: 9),
        ]

        XCTAssertEqual(
            PreviewRefreshPlanner.planIndices(entries: entries, selectedID: "selected",
                                              freshnessInterval: 2),
            [1, 2, 3])
    }

}
