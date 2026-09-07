import XCTest
@testable import WindowHopCore

final class SwitcherSearchIndexTests: XCTestCase {
    func testSearchMatchesAppAndTitleCaseInsensitivelyAndKeepsSessionOrder() {
        var index = SwitcherSearchIndex()
        let items = [
            item("1", app: "Google Chrome", title: "GitHub"),
            item("2", app: "ChatGPT", title: "my-alt-tab discussion"),
            item("3", app: "Finder", title: "Downloads"),
        ]
        index.rebuild(items: items)

        XCTAssertEqual(index.filter(items, query: "chrome").map(\.id),
                       [AnyHashable("1")])
        XCTAssertEqual(index.filter(items, query: "MY-ALT").map(\.id),
                       [AnyHashable("2")])
        XCTAssertEqual(index.filter(items, query: "").map(\.id),
                       items.map(\.id))
    }

    func testSearchFoldsWidthAndDiacritics() {
        var index = SwitcherSearchIndex()
        let items = [item("1", app: "Café", title: "Ｗｉｎｄｏｗ")]
        index.rebuild(items: items)

        XCTAssertEqual(index.filter(items, query: "cafe").count, 1)
        XCTAssertEqual(index.filter(items, query: "window").count, 1)
    }

    func testNoMatchReturnsEmptyWithoutChangingSource() {
        var index = SwitcherSearchIndex()
        let items = [item("1", app: "Finder", title: "Downloads")]
        index.rebuild(items: items)

        XCTAssertTrue(index.filter(items, query: "Safari").isEmpty)
        XCTAssertEqual(items.count, 1)
    }

    private func item(_ id: String, app: String, title: String) -> SwitcherItem {
        SwitcherItem(id: id, window: nil, title: title,
                     appName: app, icon: nil, tabCount: nil)
    }
}
