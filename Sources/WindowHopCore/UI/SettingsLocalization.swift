import Foundation

/// Settings-only localization table.
///
/// Keeping this tiny bilingual table in code makes language switching immediate
/// and avoids coupling the app's SwiftPM packaging/signing path to resource
/// bundles. English strings are the stable lookup keys and also the fallback.
enum SettingsL10n {
    static func t(_ english: String, language: SettingsLanguage? = nil) -> String {
        let language = language ?? Preferences.shared.settingsLanguage
        guard language == .simplifiedChinese else { return english }
        return zhCN[english] ?? english
    }

    static func format(_ english: String, _ arguments: CVarArg...) -> String {
        String(format: t(english),
               locale: Locale(identifier: Preferences.shared.settingsLanguage.localeIdentifier),
               arguments: arguments)
    }

    static func percentAccessibilityValue(_ value: Int) -> String {
        Preferences.shared.settingsLanguage == .simplifiedChinese
            ? "\(value) 百分比"
            : "\(value) percent"
    }

    private static let zhCN: [String: String] = [
        "my-alt-tab Settings": "my-alt-tab 设置",
        "General": "通用",
        "Shortcuts": "快捷键",
        "Windows": "窗口",
        "Appearance": "外观",
        "Updates": "更新",
        "About": "关于",

        "Language": "语言",
        "Changes apply immediately to the Settings window.": "更改会立即应用到设置窗口。",
        "Enable my-alt-tab": "启用 my-alt-tab",
        "Launch at login": "登录时启动",
        "Launch at login could not be configured. Run my-alt-tab from the Applications folder and try again.": "无法配置登录时启动。请从“应用程序”文件夹运行 my-alt-tab 后重试。",
        "Disabling my-alt-tab hands ⌘⇥ back to the native app switcher without quitting.": "停用 my-alt-tab 后，无需退出应用，⌘⇥ 会立即交还给 macOS 原生应用切换器。",
        "Show menu bar item": "显示菜单栏图标",
        "Show Dock icon": "显示 Dock 图标",
        "Appears in": "显示位置",
        "Restore Defaults…": "恢复默认设置…",
        "Restore all my-alt-tab settings?": "恢复所有 my-alt-tab 设置？",
        "Restore Defaults": "恢复默认设置",
        "Cancel": "取消",
        "Shortcuts, appearance, window filters, update checks, and app visibility return to their original values. macOS permissions and cached previews are unchanged.": "快捷键、外观、窗口筛选、更新检查和应用显示状态将恢复为默认值。macOS 权限和已缓存的预览不会改变。",
        "Defaults could not be restored because Launch at Login is unavailable. Run my-alt-tab from Applications and try again.": "由于“登录时启动”当前不可用，无法完整恢复默认设置。请从“应用程序”中运行 my-alt-tab 后重试。",
        "Quit my-alt-tab…": "退出 my-alt-tab…",
        "Quit my-alt-tab?": "退出 my-alt-tab？",
        "Quit my-alt-tab": "退出 my-alt-tab",
        "The native ⌘⇥ app switcher takes over until you open my-alt-tab again.": "退出后将由 macOS 原生 ⌘⇥ 应用切换器接管，直到你再次打开 my-alt-tab。",

        "Switcher shortcut": "窗口切换快捷键",
        "Open my-alt-tab": "打开 my-alt-tab",
        "The switcher shortcut cycles while you hold the modifier (add ⇧ to go backward); releasing it switches windows. Open my-alt-tab keeps the switcher open without holding anything: ⇥ and arrows navigate, ↩ or Space switches, ⎋ cancels, ⌫ closes the selected window directly.": "按住修饰键时可用切换快捷键循环选择窗口（加 ⇧ 可反向切换），松开修饰键即切换窗口。“打开 my-alt-tab”会让切换器保持显示：⇥ 和方向键用于选择，↩ 或空格确认切换，⎋ 取消，⌫ 直接关闭当前窗口。",
        "Add at least one modifier key (⌘, ⌥, ⌃) so normal typing can't open WindowHop.": "请至少加入一个修饰键（⌘、⌥、⌃），避免普通输入误触发 my-alt-tab。",
        "This is already the switcher shortcut. Choose a different combination.": "该组合已经被窗口切换快捷键占用，请选择其他组合。",
        "Open my-alt-tab shortcut": "打开 my-alt-tab 快捷键",
        "Type shortcut… (⎋ cancels, ⌫ clears)": "请输入快捷键…（⎋ 取消，⌫ 清除）",
        "Record Shortcut…": "录制快捷键…",

        "Selected display (disconnected)": "已选择的显示器（未连接）",
        "Focused multi-display mode": "聚焦多显示器模式",
        "Include windows from other Spaces": "包含其他桌面空间的窗口",
        "Include windows from other displays": "包含其他显示器的窗口",
        "Include minimized windows": "包含最小化窗口",
        "Include windows from hidden applications": "包含已隐藏应用的窗口",
        "Include Picture-in-Picture windows": "包含画中画窗口",
        "Windows shown": "显示的窗口",
        "Focused multi-display mode shows one switcher on the display with the pointer while loading windows from every display. Other window filters still apply.": "聚焦多显示器模式只在鼠标所在显示器上显示一个切换器，同时加载所有显示器中的窗口；其他窗口筛选规则仍然生效。",
        "my-alt-tab shows a curated set of normal windows by default. Additional categories are opt-in and update the switcher immediately. Menus, tooltips, tab siblings, and system overlays are never listed.": "my-alt-tab 默认只显示常规窗口；其他类别可按需开启，并会立即更新切换器。菜单、工具提示、同标签页窗口以及系统浮层不会出现在列表中。",
        "Show the switcher on": "切换器显示在",
        "Display": "显示器",
        "Switcher placement": "切换器位置",
        "Legacy placement options are available when focused multi-display mode is off. The display with the pointer is the one you are looking at, which is not always the one holding keyboard focus.": "关闭聚焦多显示器模式后可使用传统显示位置选项。鼠标所在显示器通常是你正在看的显示器，但它不一定是当前拥有键盘焦点的显示器。",
        "All displays": "所有显示器",
        "The display with the pointer": "鼠标所在显示器",
        "A specific display": "指定显示器",

        "Switcher shows": "切换器显示方式",
        "App Icons": "应用图标",
        "Window Previews": "窗口预览",
        "Preview row alignment": "预览行对齐",
        "Left": "左对齐",
        "Center": "居中",
        "Right": "右对齐",
        "App Icons shows each window as a large application icon. Window Previews shows a snapshot of each window instead. Preview row alignment controls how an incomplete thumbnail row is placed; Center preserves the original layout.": "“应用图标”会用大图标表示每个窗口；“窗口预览”则显示窗口快照。预览行对齐用于控制最后一行不足一整行时的位置；“居中”保持默认布局。",
        "Glass transparency": "玻璃透明度",
        "Liquid Glass": "液态玻璃",
        "Higher values make the background Clear Glass more transparent. 100% is the clearest state with no extra milky layer; lower values progressively strengthen the glass body and milk. Window previews, text, controls, and the blue focus ring remain fully opaque above the glass.": "数值越高，背景 Clear Glass 越通透。100% 是最透明状态，不叠加额外乳白层；数值降低时才逐步增强玻璃本体和乳白效果。窗口预览、文字、控件和蓝色选中框始终保持完全不透明，并位于玻璃上层。",
        "Show an expanded preview after pausing": "停留后显示放大预览",
        "Expanded Preview": "放大预览",
        "After you pause, my-alt-tab enlarges the latest snapshot inside the switcher. The real window is not activated until you confirm; cancelling leaves the desktop unchanged. The default delay is 3 seconds.": "停留一段时间后，my-alt-tab 会在切换器中放大最新窗口快照。在你确认之前不会激活真实窗口；取消操作不会改变当前桌面。默认延迟为 3 秒。",
        "Off": "关闭",
        "1 second": "1 秒",
        "2 seconds": "2 秒",
        "3 seconds": "3 秒",
        "5 seconds": "5 秒",
        "App Icons never needs any extra permission.": "应用图标模式不需要额外权限。",
        "Window Previews will ask for Screen Recording when you select it — macOS requires that permission for window snapshots.": "选择窗口预览后会请求“屏幕录制”权限；macOS 要求该权限才能获取窗口快照。",
        "Screen Recording access is granted.": "已获得屏幕录制权限。",
        "Snapshots are captured only while the switcher is open.": "仅在切换器打开时捕获快照。",
        "Window Previews needs Screen Recording access.": "窗口预览需要屏幕录制权限。",
        "Until it is granted, cached previews remain visible and other cards use a static fallback instead of an indefinite loading animation.": "授权前，已有缓存预览仍会显示；其他窗口卡片会使用静态占位，而不会一直显示加载动画。",
        "Grant Permission": "授予权限",
        "Open System Settings": "打开系统设置",
        "Screen Recording": "屏幕录制",
        "Captures run only while the switcher is open. Recent tile-sized previews may remain in memory for the next open; they are never written to disk or transmitted.": "捕获仅在切换器打开时进行。最近的缩略图预览可能暂存在内存中供下次打开使用，但不会写入磁盘，也不会上传或传输。",

        "my-alt-tab %@ is available": "my-alt-tab %@ 已可更新",
        "This release is signed with the my-alt-tab Sparkle key. Update Now opens Sparkle's verified installer and relaunches my-alt-tab when installation completes.": "该版本使用 my-alt-tab 的 Sparkle 密钥签名。“立即更新”会打开经过验证的 Sparkle 安装程序，并在安装完成后重新启动 my-alt-tab。",
        "Update Now…": "立即更新…",
        "Automatically check for updates": "自动检查更新",
        "Current version": "当前版本",
        "Latest version": "最新版本",
        "Checking…": "正在检查…",
        "Up to date": "已是最新版本",
        "Unavailable in development build": "开发版本不可用",
        "Signed automatic updates are ready.": "已启用签名自动更新。",
        "Check Now": "立即检查",
        "View Releases": "查看发布版本",
        "Last checked at %@": "上次检查：%@",
        "Opening this pane performs a silent Sparkle version probe. Scheduled checks remain Sparkle-managed, and every downloaded archive is EdDSA verified before installation. No telemetry, accounts, or system-profile reporting.": "打开此页面时会静默执行一次 Sparkle 版本检查。定时检查仍由 Sparkle 管理，所有下载的更新包在安装前都会进行 EdDSA 验证。不包含遥测、账户或系统信息上报。",

        "my-alt-tab application icon": "my-alt-tab 应用图标",
        "Switch between windows, not just apps.": "切换窗口，而不只是切换应用。",
        "Version %@ · Build %@": "版本 %@ · 构建 %@",
        "A fast, native macOS window switcher focused on getting you to the exact window you want.": "一个快速、原生的 macOS 窗口切换器，帮助你直接找到真正想切换到的那个窗口。",
        "Website": "官方网站",
        "GitHub": "GitHub",
        "Report Issue": "反馈问题",
        "Application": "应用",
        "Bundle identifier": "Bundle 标识符",
        "License": "许可证",
        "Details": "详细信息",
        "Free and open source": "免费且开源",
        "Developed & maintained by zhangqiaoran. my-alt-tab builds on WindowHop and AltTab, with upstream attribution preserved under GPL-3.0.": "由 zhangqiaoran 开发并维护。my-alt-tab 基于 WindowHop 和 AltTab 构建，并按照 GPL-3.0 保留上游项目署名。",
        "AltTab upstream on GitHub": "GitHub 上的 AltTab 上游项目",
        "© 2026 zhangqiaoran and my-alt-tab contributors.": "© 2026 zhangqiaoran 与 my-alt-tab 贡献者。"
    ]
}
