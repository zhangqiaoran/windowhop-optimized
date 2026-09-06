import XCTest
@testable import WindowHopCore

final class SettingsDefaultsRestorerTests: XCTestCase {
    func testExternalFailureLeavesEveryPreferenceUntouched() {
        let suite = "windowhop-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.shortcut = .controlTab
        preferences.settingsLanguage = .simplifiedChinese
        preferences.automaticUpdateChecks = false
        var appliedUpdateValue: Bool?
        let restorer = SettingsDefaultsRestorer(
            preferences: preferences,
            setLoginItem: { _ in false },
            applyAutomaticUpdateChecks: { appliedUpdateValue = $0 })

        XCTAssertFalse(restorer.restore())
        XCTAssertEqual(preferences.shortcut, .controlTab)
        XCTAssertEqual(preferences.settingsLanguage, .simplifiedChinese)
        XCTAssertFalse(preferences.automaticUpdateChecks)
        XCTAssertNil(appliedUpdateValue)
    }

    func testSuccessfulRestoreAppliesExternalAndPersistedDefaultsTogether() {
        let suite = "windowhop-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.shortcut = .controlTab
        preferences.persistentShortcut = nil
        preferences.settingsLanguage = .simplifiedChinese
        preferences.automaticUpdateChecks = false
        var loginValue: Bool?
        var updateValue: Bool?
        let restorer = SettingsDefaultsRestorer(
            preferences: preferences,
            setLoginItem: { loginValue = $0; return true },
            applyAutomaticUpdateChecks: { updateValue = $0 })

        XCTAssertTrue(restorer.restore())
        XCTAssertEqual(loginValue, Preferences.Defaults.launchAtLogin)
        XCTAssertEqual(updateValue, Preferences.Defaults.automaticUpdateChecks)
        XCTAssertEqual(preferences.shortcut, .commandTab)
        XCTAssertEqual(preferences.persistentShortcut, .optionTab)
        XCTAssertEqual(preferences.settingsLanguage, .english)
        XCTAssertTrue(preferences.automaticUpdateChecks)
        let restored = Preferences(defaults: defaults)
        XCTAssertEqual(restored.persistentShortcut, .optionTab)
        XCTAssertEqual(restored.settingsLanguage, .english)
        XCTAssertTrue(restored.automaticUpdateChecks)
    }
}
