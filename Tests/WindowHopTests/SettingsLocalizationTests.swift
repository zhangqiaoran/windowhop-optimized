import XCTest
@testable import WindowHopCore

final class SettingsLocalizationTests: XCTestCase {
    func testEnglishFallsBackToStableSourceText() {
        XCTAssertEqual(
            SettingsL10n.t("General", language: .english),
            "General")
        XCTAssertEqual(
            SettingsL10n.t("Glass transparency", language: .english),
            "Glass transparency")
    }

    func testChineseTranslatesToolbarAndAppearanceText() {
        XCTAssertEqual(
            SettingsL10n.t("General", language: .simplifiedChinese),
            "通用")
        XCTAssertEqual(
            SettingsL10n.t("Appearance", language: .simplifiedChinese),
            "外观")
        XCTAssertEqual(
            SettingsL10n.t("Glass transparency", language: .simplifiedChinese),
            "玻璃透明度")
        XCTAssertEqual(
            SettingsL10n.t("Window Previews", language: .simplifiedChinese),
            "窗口预览")
    }

    func testEverySettingsPaneHasBothLanguageTitles() {
        XCTAssertEqual(
            SettingsPane.allCases.map { $0.title(for: .english) },
            ["General", "Shortcuts", "Windows", "Appearance", "Updates", "About"])
        XCTAssertEqual(
            SettingsPane.allCases.map { $0.title(for: .simplifiedChinese) },
            ["通用", "快捷键", "窗口", "外观", "更新", "关于"])
    }

    func testUnknownStringsRemainReadableInsteadOfDisappearing() {
        XCTAssertEqual(
            SettingsL10n.t("Future setting", language: .simplifiedChinese),
            "Future setting")
    }

    func testRetiredTabCountSettingCannotBeEnabled() {
        let suite = "settings-localization-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        // Even an old stored value is ignored by 3.4.3.
        defaults.set(true, forKey: "showTabCounts")
        let preferences = Preferences(defaults: defaults)

        XCTAssertFalse(preferences.showTabCounts)
        XCTAssertFalse(Preferences.Key.allCases.map(\.rawValue).contains("showTabCounts"))
    }
}
