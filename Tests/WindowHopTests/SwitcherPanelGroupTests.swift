import AppKit
import XCTest
@testable import WindowHopCore

/// Mirrored panels must stay indistinguishable from each other. These drive the
/// group against one real screen repeated under different display ids, which
/// exercises the fan-out without needing multiple monitors attached to CI.
final class SwitcherPanelGroupTests: XCTestCase {
    private var group: SwitcherPanelGroup!

    override func setUp() {
        super.setUp()
        group = SwitcherPanelGroup()
    }

    override func tearDown() {
        group.hide()
        group = nil
        super.tearDown()
    }

    private func targets(_ count: Int,
                         scale: CGFloat = 2) -> [(descriptor: DisplayDescriptor, screen: NSScreen)] {
        guard let screen = NSScreen.screens.first else { return [] }
        return (0..<count).map { index in
            (DisplayDescriptor(id: "display-\(index)",
                               name: "Display \(index)",
                               visibleFrame: screen.visibleFrame,
                               backingScale: scale),
             screen)
        }
    }

    private func items(_ count: Int) -> [SwitcherItem] {
        (0..<count).map {
            SwitcherItem(id: "item-\($0)" as AnyHashable,
                         window: nil,
                         title: "Window \($0)",
                         appName: "App",
                         icon: nil,
                         tabCount: nil)
        }
    }

    func testOnePanelIsCreatedPerTargetDisplay() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "needs a display")

        group.prepare(for: targets(3), tileCount: 4, tileSize: NSSize(width: 200, height: 160))

        XCTAssertEqual(group.panelCountForTesting, 3)
    }

    func testShrinkingTheTargetSetLeavesNoOrphanPanel() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "needs a display")
        let tileSize = NSSize(width: 200, height: 160)

        group.prepare(for: targets(3), tileCount: 4, tileSize: tileSize)
        group.prepare(for: targets(1), tileCount: 4, tileSize: tileSize)

        XCTAssertEqual(group.panelCountForTesting, 1,
                       "unplugging a display must not leave a panel behind")
    }

    func testSelectionIsSynchronizedAcrossEveryPanel() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "needs a display")
        let list = items(5)
        group.prepare(for: targets(2), tileCount: list.count,
                      tileSize: NSSize(width: 200, height: 160))
        group.show(items: list, selectedIndex: 0, presentationMode: .cycling)

        group.select(3)

        for index in 0..<group.panelCountForTesting {
            let panel = try XCTUnwrap(group.panelForTesting(at: index))
            XCTAssertEqual(panel.selectedIndexForTesting, 3,
                           "panel \(index) drifted from the shared selection")
        }
        group.hide()
    }

    func testEndingASessionRemovesEveryPanelFromTheScreen() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "needs a display")
        let list = items(3)
        group.prepare(for: targets(2), tileCount: list.count,
                      tileSize: NSSize(width: 200, height: 160))
        group.show(items: list, selectedIndex: 0, presentationMode: .cycling)

        group.hide()

        for index in 0..<group.panelCountForTesting {
            let panel = try XCTUnwrap(group.panelForTesting(at: index))
            XCTAssertFalse(panel.isVisible, "panel \(index) stayed on screen after the session")
        }
    }

    func testEveryPanelReportsTheSameNavigationGrid() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "needs a display")
        let list = items(9)
        group.prepare(for: targets(3), tileCount: list.count,
                      tileSize: NSSize(width: 200, height: 160))
        group.show(items: list, selectedIndex: 0, presentationMode: .cycling)

        let columns = try XCTUnwrap(group.panelForTesting(at: 0)).columnsPerRow
        for index in 1..<group.panelCountForTesting {
            let panel = try XCTUnwrap(group.panelForTesting(at: index))
            XCTAssertEqual(panel.columnsPerRow, columns,
                           "arrow navigation would mean different things per display")
        }
        XCTAssertEqual(group.columnsPerRow, columns)
        group.hide()
    }

    func testPreviewCaptureTargetUsesActualExternalDisplayAspect() throws {
        guard let screen = NSScreen.screens.first else {
            throw XCTSkip("needs a display")
        }
        let targets: [(descriptor: DisplayDescriptor, screen: NSScreen)] = [
            (
                DisplayDescriptor(
                    id: "ultrawide",
                    name: "Ultrawide",
                    visibleFrame: CGRect(x: 0, y: 0, width: 3440, height: 1440),
                    backingScale: 1),
                screen
            ),
        ]

        group.prepare(
            for: targets,
            tileCount: 4,
            tileSize: SwitcherTileView.Metrics.metrics(
                for: .windowPreviews,
                showTabCounts: false,
                displayAspect: 3440.0 / 1440.0).tileSize)

        let expected = SwitcherPanel.previewContentSize(displayAspect: 3440.0 / 1440.0)
        XCTAssertEqual(group.previewTargetSize.width, expected.width)
        XCTAssertEqual(group.previewTargetSize.height, expected.height)
        XCTAssertEqual(group.captureScale, 1,
                       "a 1x external display must not be forced through a hard-coded Retina assumption")
    }

    func testCaptureScaleFollowsTheSharpestTargetDisplay() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "needs a display")
        var mixed = targets(1, scale: 1)
        mixed.append(contentsOf: targets(1, scale: 3))

        group.prepare(for: mixed, tileCount: 2, tileSize: NSSize(width: 200, height: 160))

        XCTAssertEqual(group.captureScale, 3)
    }

    func testGlobalMouseClassificationKeepsClicksInsideVisiblePanel() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "needs a display")
        let list = items(3)
        group.prepare(for: targets(1), tileCount: list.count,
                      tileSize: NSSize(width: 200, height: 160))
        group.show(items: list, selectedIndex: 0, presentationMode: .cycling)

        let panel = try XCTUnwrap(group.panelForTesting(at: 0))
        let inside = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let outside = NSPoint(x: panel.frame.maxX + 100, y: panel.frame.maxY + 100)

        XCTAssertTrue(group.containsScreenPoint(inside),
                      "clicks inside the nonactivating switcher must not be classified as outside")
        XCTAssertFalse(group.containsScreenPoint(outside))

        group.hide()
        XCTAssertFalse(group.containsScreenPoint(inside),
                       "hidden panels must not reserve stale outside-click geometry")
    }
}
