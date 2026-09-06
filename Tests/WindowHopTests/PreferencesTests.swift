import XCTest
import Combine
@testable import WindowHopCore

final class PreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var preferences: Preferences!

    override func setUp() {
        super.setUp()
        suiteName = "windowhop-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        preferences = Preferences(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaults() {
        XCTAssertTrue(preferences.switcherEnabled)
        XCTAssertTrue(preferences.launchAtLogin)
        XCTAssertEqual(preferences.shortcut, .commandTab)
        XCTAssertEqual(preferences.persistentShortcut, .optionTab)
        XCTAssertEqual(preferences.appearanceMode, .appIcons)
        XCTAssertEqual(preferences.previewRowAlignment, .center)
        XCTAssertEqual(preferences.glassTransparencyPercent, 100)
        XCTAssertEqual(preferences.expandedPreviewDelay, .threeSeconds)
        XCTAssertEqual(preferences.expandedPreviewDelay.duration, 3)
        XCTAssertTrue(preferences.focusedMultiDisplayMode)
        XCTAssertEqual(preferences.switcherDisplayPlacement, .allDisplays)
        XCTAssertNil(preferences.switcherDisplayID)
        XCTAssertTrue(preferences.includeOtherSpaces)
        XCTAssertTrue(preferences.includeOtherDisplays)
        XCTAssertFalse(preferences.includeMinimizedWindows)
        XCTAssertFalse(preferences.includeHiddenApplicationWindows)
        XCTAssertFalse(preferences.includePictureInPictureWindows)
        XCTAssertFalse(preferences.showTabCounts)
        XCTAssertFalse(preferences.showMenuBarItem)
        XCTAssertFalse(preferences.showDockIcon)
        XCTAssertTrue(preferences.automaticUpdateChecks)
        XCTAssertFalse(preferences.firstLaunchCompleted)
    }

    func testRoundTrip() {
        preferences.switcherEnabled = false
        preferences.launchAtLogin = false
        preferences.shortcut = .optionTab
        preferences.persistentShortcut = PersistentShortcut(
            keyCode: KeyCode.space, modifiers: [.maskAlternate])
        preferences.appearanceMode = .windowPreviews
        preferences.previewRowAlignment = .right
        preferences.glassTransparencyPercent = 37
        preferences.expandedPreviewDelay = .fiveSeconds
        preferences.focusedMultiDisplayMode = false
        preferences.switcherDisplayPlacement = .specificDisplay
        preferences.switcherDisplayID = "UUID-EXTERNAL"
        preferences.includeOtherSpaces = false
        preferences.includeOtherDisplays = false
        preferences.includeMinimizedWindows = true
        preferences.includeHiddenApplicationWindows = true
        preferences.includePictureInPictureWindows = true
        preferences.showTabCounts = false
        preferences.showMenuBarItem = true
        preferences.showDockIcon = true
        preferences.automaticUpdateChecks = false
        preferences.firstLaunchCompleted = true

        let restored = Preferences(defaults: defaults)

        XCTAssertFalse(restored.switcherEnabled)
        XCTAssertFalse(restored.launchAtLogin)
        XCTAssertEqual(restored.shortcut, .optionTab)
        XCTAssertEqual(restored.persistentShortcut, preferences.persistentShortcut)
        XCTAssertEqual(restored.appearanceMode, .windowPreviews)
        XCTAssertEqual(restored.previewRowAlignment, .right)
        XCTAssertEqual(restored.glassTransparencyPercent, 37)
        XCTAssertEqual(restored.expandedPreviewDelay, .fiveSeconds)
        XCTAssertFalse(restored.focusedMultiDisplayMode)
        XCTAssertEqual(restored.switcherDisplayPlacement, .specificDisplay)
        XCTAssertEqual(restored.switcherDisplayID, "UUID-EXTERNAL")
        XCTAssertFalse(restored.includeOtherSpaces)
        XCTAssertFalse(restored.includeOtherDisplays)
        XCTAssertTrue(restored.includeMinimizedWindows)
        XCTAssertTrue(restored.includeHiddenApplicationWindows)
        XCTAssertTrue(restored.includePictureInPictureWindows)
        XCTAssertFalse(restored.showTabCounts)
        XCTAssertTrue(restored.showMenuBarItem)
        XCTAssertTrue(restored.showDockIcon)
        XCTAssertFalse(restored.automaticUpdateChecks)
        XCTAssertTrue(restored.firstLaunchCompleted)
    }

    func testLoadsValuesPersistedByEarlierVersionsWithoutDataLoss() {
        let openShortcut = PersistentShortcut(
            keyCode: KeyCode.space, modifiers: [.maskAlternate])
        defaults.set(false, forKey: Preferences.Key.switcherEnabled.rawValue)
        defaults.set(ShortcutSpec.optionTab.rawValue,
                     forKey: Preferences.Key.shortcut.rawValue)
        defaults.set(openShortcut.encoded,
                     forKey: Preferences.Key.persistentShortcut.rawValue)
        defaults.set(AppearanceMode.windowPreviews.rawValue,
                     forKey: Preferences.Key.appearanceMode.rawValue)
        defaults.set(false, forKey: Preferences.Key.showTabCounts.rawValue)
        defaults.set(true, forKey: Preferences.Key.showMenuBarItem.rawValue)

        let migrated = Preferences(defaults: defaults)

        XCTAssertFalse(migrated.switcherEnabled)
        XCTAssertEqual(migrated.shortcut, .optionTab)
        XCTAssertEqual(migrated.persistentShortcut, openShortcut)
        XCTAssertEqual(migrated.appearanceMode, .windowPreviews)
        XCTAssertEqual(migrated.previewRowAlignment, .center)
        XCTAssertEqual(migrated.expandedPreviewDelay, .threeSeconds,
                       "existing users inherit the documented three-second default")
        XCTAssertTrue(migrated.focusedMultiDisplayMode,
                      "the optimized single-panel multi-display behavior is the new default")
        XCTAssertFalse(migrated.includeMinimizedWindows)
        XCTAssertFalse(migrated.includeHiddenApplicationWindows)
        XCTAssertFalse(migrated.includePictureInPictureWindows)
        XCTAssertFalse(migrated.showTabCounts)
        XCTAssertTrue(migrated.showMenuBarItem)
    }

    func testCorruptShortcutFallsBackToCommandTab() {
        defaults.set("garbage", forKey: Preferences.Key.shortcut.rawValue)
        XCTAssertEqual(Preferences(defaults: defaults).shortcut, .commandTab)
    }

    func testCorruptAppearanceAndBooleanValuesFallBackToDocumentedDefaults() {
        defaults.set("obsolete-mode", forKey: Preferences.Key.appearanceMode.rawValue)
        defaults.set("diagonal", forKey: Preferences.Key.previewRowAlignment.rawValue)
        defaults.set("obsolete-delay", forKey: Preferences.Key.expandedPreviewDelay.rawValue)
        defaults.set("not-a-boolean", forKey: Preferences.Key.includeOtherSpaces.rawValue)
        defaults.set("not-a-boolean",
                     forKey: Preferences.Key.includeMinimizedWindows.rawValue)
        defaults.set("not-a-boolean", forKey: Preferences.Key.showMenuBarItem.rawValue)

        let restored = Preferences(defaults: defaults)

        XCTAssertEqual(restored.appearanceMode, .appIcons)
        XCTAssertEqual(restored.previewRowAlignment, .center)
        XCTAssertEqual(restored.expandedPreviewDelay, .threeSeconds)
        XCTAssertTrue(restored.includeOtherSpaces)
        XCTAssertFalse(restored.includeMinimizedWindows)
        XCTAssertFalse(restored.showMenuBarItem)
    }

    func testCorruptPersistentShortcutRestoresUnassignedDefault() {
        defaults.set("broken-shortcut", forKey: Preferences.Key.persistentShortcut.rawValue)
        XCTAssertEqual(Preferences(defaults: defaults).persistentShortcut, .optionTab)
    }

    func testExpandedPreviewDelayPresetsAvoidRawMillisecondsInSettings() {
        XCTAssertNil(ExpandedPreviewDelay.off.duration)
        XCTAssertEqual(ExpandedPreviewDelay.oneSecond.duration, 1)
        XCTAssertEqual(ExpandedPreviewDelay.twoSeconds.duration, 2)
        XCTAssertEqual(ExpandedPreviewDelay.threeSeconds.duration, 3)
        XCTAssertEqual(ExpandedPreviewDelay.fiveSeconds.duration, 5)
        XCTAssertEqual(ExpandedPreviewDelay.allCases.map(\.displayName),
                       ["Off", "1 second", "2 seconds", "3 seconds", "5 seconds"])
    }

    func testPreviewRowAlignmentUsesPredictableLeadingOffsets() {
        XCTAssertEqual(PreviewRowAlignment.allCases.map(\.displayName),
                       ["Left", "Center", "Right"])
        XCTAssertEqual(PreviewRowAlignment.left.leadingOffset(remainingWidth: 120), 0)
        XCTAssertEqual(PreviewRowAlignment.center.leadingOffset(remainingWidth: 120), 60)
        XCTAssertEqual(PreviewRowAlignment.right.leadingOffset(remainingWidth: 120), 120)
        XCTAssertEqual(PreviewRowAlignment.right.leadingOffset(remainingWidth: -1), 0)
    }

    func testExpandedPreviewDelayPublishesRuntimeUpdatesImmediately() {
        var observed: [ExpandedPreviewDelay] = []
        let observation = preferences.$expandedPreviewDelay.sink {
            observed.append($0)
        }

        preferences.expandedPreviewDelay = .oneSecond

        XCTAssertEqual(observed, [.threeSeconds, .oneSecond])
        withExtendedLifetime(observation) {}
    }

    func testLegacyNavigationDelayMigratesToExpandedPreviewPreset() {
        defaults.removeObject(forKey: Preferences.Key.expandedPreviewDelay.rawValue)
        defaults.set("long", forKey: Preferences.Key.navigationPreviewDelay.rawValue)

        XCTAssertEqual(Preferences(defaults: defaults).expandedPreviewDelay, .fiveSeconds)
    }

    func testWindowFilterChangesPublishRuntimeRefresh() {
        let expectation = expectation(forNotification: Preferences.windowFiltersDidChange,
                                      object: preferences)
        preferences.includePictureInPictureWindows = true
        wait(for: [expectation], timeout: 1)
    }

    func testExplicitlyClearedPersistentShortcutSurvivesUpgrade() {
        defaults.set("", forKey: Preferences.Key.persistentShortcut.rawValue)
        XCTAssertNil(Preferences(defaults: defaults).persistentShortcut)
    }

    func testRestoreDefaultsResetsEveryConfigurablePreferenceAndPreservesInternalState() {
        preferences.switcherEnabled = false
        preferences.launchAtLogin = false
        preferences.shortcut = .controlTab
        preferences.persistentShortcut = nil
        preferences.appearanceMode = .windowPreviews
        preferences.previewRowAlignment = .left
        preferences.glassTransparencyPercent = 12
        preferences.expandedPreviewDelay = .off
        preferences.focusedMultiDisplayMode = false
        preferences.includeOtherSpaces = false
        preferences.includeOtherDisplays = false
        preferences.includeMinimizedWindows = true
        preferences.includeHiddenApplicationWindows = true
        preferences.includePictureInPictureWindows = true
        preferences.showTabCounts = true
        preferences.showMenuBarItem = true
        preferences.showDockIcon = true
        preferences.automaticUpdateChecks = false
        preferences.firstLaunchCompleted = true

        preferences.restoreDefaults()

        XCTAssertTrue(preferences.switcherEnabled)
        XCTAssertTrue(preferences.launchAtLogin)
        XCTAssertEqual(preferences.shortcut, .commandTab)
        XCTAssertEqual(preferences.persistentShortcut, .optionTab)
        XCTAssertEqual(preferences.appearanceMode, .appIcons)
        XCTAssertEqual(preferences.previewRowAlignment, .center)
        XCTAssertEqual(preferences.glassTransparencyPercent, 100)
        XCTAssertEqual(preferences.expandedPreviewDelay, .threeSeconds)
        XCTAssertTrue(preferences.focusedMultiDisplayMode)
        XCTAssertEqual(preferences.switcherDisplayPlacement, .allDisplays)
        XCTAssertNil(preferences.switcherDisplayID)
        XCTAssertTrue(preferences.includeOtherSpaces)
        XCTAssertTrue(preferences.includeOtherDisplays)
        XCTAssertFalse(preferences.includeMinimizedWindows)
        XCTAssertFalse(preferences.includeHiddenApplicationWindows)
        XCTAssertFalse(preferences.includePictureInPictureWindows)
        XCTAssertFalse(preferences.showTabCounts)
        XCTAssertFalse(preferences.showMenuBarItem)
        XCTAssertFalse(preferences.showDockIcon)
        XCTAssertTrue(preferences.automaticUpdateChecks)
        XCTAssertTrue(preferences.firstLaunchCompleted,
                      "Restore Defaults must not repeat first-run state")
    }


    func testGlassTransparencyClampsAndPersistsPercentRange() {
        preferences.glassTransparencyPercent = -12
        XCTAssertEqual(preferences.glassTransparencyPercent, 0)
        preferences.glassTransparencyPercent = 118
        XCTAssertEqual(preferences.glassTransparencyPercent, 100)
        preferences.glassTransparencyPercent = 42
        XCTAssertEqual(Preferences(defaults: defaults).glassTransparencyPercent, 42)

        defaults.set(Double.nan, forKey: Preferences.Key.glassTransparencyPercent.rawValue)
        XCTAssertEqual(Preferences(defaults: defaults).glassTransparencyPercent, 100)
    }

    func testGlassTransparencyPublishesRuntimeAppearanceChange() {
        let expectation = expectation(
            forNotification: Preferences.panelAppearanceDidChange,
            object: preferences)
        preferences.glassTransparencyPercent = 55
        wait(for: [expectation], timeout: 1)
    }

    func testFocusedMultiDisplayModeForcesCrossDisplayInclusionWithoutLosingStoredChoice() {
        preferences.includeOtherDisplays = false
        preferences.focusedMultiDisplayMode = true

        XCTAssertFalse(preferences.windowInclusionPolicy.includeOtherDisplays,
                       "the stored legacy choice remains untouched")
        XCTAssertTrue(preferences.effectiveWindowInclusionPolicy.includeOtherDisplays,
                      "focused mode must load windows from every display")

        preferences.focusedMultiDisplayMode = false
        XCTAssertFalse(preferences.effectiveWindowInclusionPolicy.includeOtherDisplays,
                       "disabling focused mode restores the legacy display filter")
    }

    func testInvalidStoredPlacementFallsBackToTheDocumentedDefault() {
        defaults.set("mirrored-onto-the-ceiling",
                     forKey: Preferences.Key.switcherDisplayPlacement.rawValue)

        let restored = Preferences(defaults: defaults)

        XCTAssertEqual(restored.switcherDisplayPlacement, .allDisplays)
    }

    func testAnUpgradeWithoutAStoredPlacementReceivesTheNewDefault() {
        // an installation that predates the preference has nothing in its
        // persistent domain and must land on All displays with no migration step
        let suite = "windowhop-tests-\(UUID().uuidString)"
        let clean = UserDefaults(suiteName: suite)!
        defer { clean.removePersistentDomain(forName: suite) }
        XCTAssertNil(clean.persistentDomain(forName: suite)?[
            Preferences.Key.switcherDisplayPlacement.rawValue])

        let restored = Preferences(defaults: clean)

        XCTAssertEqual(restored.switcherDisplayPlacement, .allDisplays)
        XCTAssertNil(restored.switcherDisplayID)
    }

    func testAChosenDisplaySurvivesBeingUnplugged() {
        // the id is the user's choice, not a cache of connected hardware: it is
        // kept verbatim so reconnecting the display restores the behavior
        preferences.switcherDisplayPlacement = .specificDisplay
        preferences.switcherDisplayID = "UUID-UNPLUGGED"

        let restored = Preferences(defaults: defaults)

        XCTAssertEqual(restored.switcherDisplayID, "UUID-UNPLUGGED")
    }

    func testClearingTheChosenDisplayPersistsAsNoChoice() {
        preferences.switcherDisplayID = "UUID-EXTERNAL"
        preferences.switcherDisplayID = nil

        XCTAssertNil(Preferences(defaults: defaults).switcherDisplayID)
    }

    func testEveryNonInternalKeyParticipatesInRestoreDefaults() {
        let internalKeys: Set<Preferences.Key> = [
            .navigationPreviewDelay,
            .firstLaunchCompleted,
        ]
        XCTAssertEqual(
            Preferences.configurableKeys,
            Set(Preferences.Key.allCases).subtracting(internalKeys),
            "A new configurable preference must be considered by Restore Defaults")
    }

    func testRestoreDefaultsPublishesOneCoherentWindowFilterRefresh() {
        preferences.includeOtherSpaces = false
        preferences.includeOtherDisplays = false
        preferences.includeMinimizedWindows = true
        preferences.includeHiddenApplicationWindows = true
        preferences.includePictureInPictureWindows = true
        var refreshCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: Preferences.windowFiltersDidChange,
            object: preferences,
            queue: nil) { _ in refreshCount += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        preferences.restoreDefaults()

        XCTAssertEqual(refreshCount, 1)
    }
}
