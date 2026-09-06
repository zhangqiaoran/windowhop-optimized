import Foundation

/// Explicit language choice for my-alt-tab Settings.
///
/// The switcher itself is intentionally icon/preview driven; this preference
/// controls the Settings window and related Settings-only helper text.
public enum SettingsLanguage: String, CaseIterable, Identifiable {
    case english
    case simplifiedChinese

    public var id: String { rawValue }

    /// Language names are intentionally self-identifying so the user can always
    /// switch back even if the current UI language is unfamiliar.
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "中文"
        }
    }

    public var localeIdentifier: String {
        switch self {
        case .english: return "en_US"
        case .simplifiedChinese: return "zh_CN"
        }
    }
}
