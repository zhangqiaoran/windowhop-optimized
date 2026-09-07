import CoreGraphics
import XCTest
@testable import WindowHopCore

final class EventTapInterceptionTests: XCTestCase {
    func testCommandTabSequenceIsFullyConsumedAndReleasesOnModifierChange() {
        var state = EventTapInterceptionState(
            mode: .watching,
            holdModifier: .maskCommand,
            persistentShortcut: .optionTab)

        XCTAssertEqual(
            state.decide(type: .keyDown, keyCode: KeyCode.tab, flags: .maskCommand),
            EventTapDecision(disposition: .consume, input: .trigger(backward: false)))
        XCTAssertEqual(
            state.decide(type: .keyUp, keyCode: KeyCode.tab, flags: .maskCommand),
            .consume)
        XCTAssertEqual(
            state.decide(type: .flagsChanged, keyCode: 55, flags: []),
            EventTapDecision(disposition: .pass, input: .modifierReleased))
    }

    func testReverseAndRepeatedCyclingNeverLeaksToNativeSwitcher() {
        var state = EventTapInterceptionState(
            mode: .watching,
            holdModifier: .maskCommand,
            persistentShortcut: .optionTab)
        let reverseFlags: CGEventFlags = [.maskCommand, .maskShift]

        XCTAssertEqual(
            state.decide(type: .keyDown, keyCode: KeyCode.tab, flags: reverseFlags),
            EventTapDecision(disposition: .consume, input: .trigger(backward: true)))
        XCTAssertEqual(state.decide(type: .keyUp, keyCode: KeyCode.tab,
                                    flags: reverseFlags), .consume)
        XCTAssertEqual(
            state.decide(type: .keyDown, keyCode: KeyCode.tab, flags: .maskCommand),
            EventTapDecision(disposition: .consume, input: .step(backward: false)))
        XCTAssertEqual(state.decide(type: .keyUp, keyCode: KeyCode.tab,
                                    flags: .maskCommand), .consume)
    }

    func testRapidSessionEndStillConsumesOwnedKeyUp() {
        var state = EventTapInterceptionState(
            mode: .watching,
            holdModifier: .maskCommand,
            persistentShortcut: .optionTab)
        _ = state.decide(type: .keyDown, keyCode: KeyCode.tab, flags: .maskCommand)
        state.mode = .watching

        XCTAssertEqual(
            state.decide(type: .keyUp, keyCode: KeyCode.tab, flags: .maskCommand),
            .consume)
        XCTAssertEqual(
            state.decide(type: .keyUp, keyCode: KeyCode.tab, flags: .maskCommand),
            .pass)
    }

    func testRapidReleaseAndRepressStartsFreshSessionBeforeMainThreadCatchesUp() {
        var state = EventTapInterceptionState(
            mode: .watching,
            holdModifier: .maskAlternate,
            persistentShortcut: nil)

        XCTAssertEqual(
            state.decide(type: .keyDown, keyCode: KeyCode.tab, flags: .maskAlternate),
            EventTapDecision(disposition: .consume, input: .trigger(backward: false)))
        XCTAssertEqual(state.mode, .sessionHeld)

        // The tap thread sees Option released before the controller necessarily
        // handles the semantic release on main.
        XCTAssertEqual(
            state.decide(type: .flagsChanged, keyCode: 58, flags: []),
            EventTapDecision(disposition: .pass, input: .modifierReleased))
        XCTAssertEqual(state.mode, .watching)

        // A second physical Option+Tab must already be a brand-new trigger, not
        // a .step that the just-ended controller session will later discard.
        XCTAssertEqual(
            state.decide(type: .keyDown, keyCode: KeyCode.tab, flags: .maskAlternate),
            EventTapDecision(disposition: .consume, input: .trigger(backward: false)))
        XCTAssertEqual(state.mode, .sessionHeld)

        XCTAssertEqual(
            state.decide(type: .flagsChanged, keyCode: 58, flags: []),
            EventTapDecision(disposition: .pass, input: .modifierReleased))
        XCTAssertEqual(state.mode, .watching)
    }

    func testOnlyConfiguredChordIsInterceptedWhileWatching() {
        var state = EventTapInterceptionState(
            mode: .watching,
            holdModifier: .maskCommand,
            persistentShortcut: .optionTab)

        XCTAssertEqual(state.decide(type: .keyDown, keyCode: KeyCode.tab,
                                    flags: .maskControl), .pass)
        XCTAssertEqual(state.decide(type: .keyDown, keyCode: KeyCode.comma,
                                    flags: .maskCommand), .pass)
        XCTAssertEqual(
            state.decide(type: .keyDown, keyCode: KeyCode.tab, flags: .maskAlternate),
            EventTapDecision(disposition: .consume, input: .openPersistent))
    }

    func testSuppressedKeyUpBitsetAndOverflowFallbackRemainCorrect() {
        for keyCode in [Int64(70), Int64(130)] {
            var state = EventTapInterceptionState(
                mode: .watching,
                holdModifier: .maskCommand,
                persistentShortcut: PersistentShortcut(keyCode: keyCode, modifiers: .maskAlternate))

            XCTAssertEqual(
                state.decide(type: .keyDown, keyCode: keyCode, flags: .maskAlternate),
                EventTapDecision(disposition: .consume, input: .openPersistent))
            XCTAssertTrue(state.suppressedKeyUps.contains(keyCode))
            XCTAssertEqual(
                state.decide(type: .keyUp, keyCode: keyCode, flags: .maskAlternate),
                .consume)
            XCTAssertFalse(state.suppressedKeyUps.contains(keyCode))
        }
    }

    func testSearchEditingModePassesTypingAndNavigationThrough() {
        var state = EventTapInterceptionState(
            mode: .sessionSearch,
            holdModifier: .maskAlternate,
            persistentShortcut: .optionTab)

        XCTAssertEqual(state.decide(type: .keyDown, keyCode: 0, flags: []), .pass)
        XCTAssertEqual(state.decide(type: .keyDown, keyCode: KeyCode.delete, flags: []), .pass)
        XCTAssertEqual(state.decide(type: .keyUp, keyCode: KeyCode.delete, flags: []), .pass)
        XCTAssertEqual(state.decide(type: .keyDown, keyCode: KeyCode.forwardDelete, flags: []), .pass)
        XCTAssertEqual(state.decide(type: .keyUp, keyCode: KeyCode.forwardDelete, flags: []), .pass)
        XCTAssertEqual(state.decide(type: .keyDown, keyCode: KeyCode.leftArrow, flags: []), .pass)
        XCTAssertEqual(state.decide(type: .keyDown, keyCode: KeyCode.returnKey, flags: []), .pass)
        XCTAssertEqual(state.decide(type: .flagsChanged, keyCode: 58, flags: []), .pass)

        XCTAssertEqual(
            state.decide(type: .keyDown, keyCode: KeyCode.tab, flags: .maskAlternate),
            EventTapDecision(disposition: .consume, input: .step(backward: false)))
        XCTAssertEqual(
            state.decide(type: .keyUp, keyCode: KeyCode.tab, flags: .maskAlternate),
            .consume)
    }

    func testStoppingResetsSuppressedReleasesAndInterception() {
        var state = EventTapInterceptionState(
            mode: .watching,
            holdModifier: .maskCommand,
            persistentShortcut: .optionTab)
        _ = state.decide(type: .keyDown, keyCode: KeyCode.tab, flags: .maskCommand)
        state.reset()

        XCTAssertEqual(state.mode, .off)
        XCTAssertTrue(state.suppressedKeyUps.isEmpty)
        XCTAssertEqual(state.decide(type: .keyUp, keyCode: KeyCode.tab,
                                    flags: .maskCommand), .pass)
    }
}
