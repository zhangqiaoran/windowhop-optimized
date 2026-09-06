import Foundation

/// Canonical public project destinations used by native About UI. Keeping
/// these URLs together prevents attribution, support, and website links from
/// drifting independently across panes.
public enum ProjectLinks {
    public static let website = URL(string: "https://zhangqiaoran.github.io/my-alt-tab/")!
    public static let repository = URL(string: "https://github.com/zhangqiaoran/my-alt-tab")!
    public static let issues = URL(string: "https://github.com/zhangqiaoran/my-alt-tab/issues")!
    public static let releases = URL(string: "https://github.com/zhangqiaoran/my-alt-tab/releases")!
    public static let altTabRepository = URL(string: "https://github.com/lwouis/alt-tab-macos")!
}
