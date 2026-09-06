# my-alt-tab v3.4.3

**Author / maintainer / release owner: zhangqiaoran**

## English / 中文 Settings

- Added a new **Language / 语言** picker in General.
- Supported choices: **English** and **中文**.
- Switching language updates the open Settings window immediately; no restart is required.
- Toolbar pane names, form labels, buttons, explanatory text, permission status, update status, shortcut validation, Updates, and About all participate in the same bilingual system.
- The visible Settings window title and current pane title relabel when the language changes.
- The selected language is persisted in typed `Preferences`.
- Restore Defaults returns the Settings language to English.

## Appearance cleanup

- Removed the low-value **Show tab counts** row from Appearance.
- The old persisted preference is retired; an older stored `showTabCounts=true` value is ignored.
- Tab-count metadata remains disabled, keeping the window cards and Appearance pane simpler.
- Updated the Liquid Glass help text to describe the current renderer correctly: native Clear Glass is a background-only layer while previews, labels, controls, and the blue focus ring stay fully opaque above it.

## Compatibility and retained fixes

- Keeps the v3.4.2 nonactivating-panel click ownership and click-through fix.
- Keeps root-level window-card / Close / Settings / permission routing.
- Keeps native macOS 26 Clear Liquid Glass with no white tint and the literal transparency curve.
- Keeps the 96-state deterministic dissolve atlas and 80% dust-to-FLIP hand-off.
- Keeps synchronized Stable-ID FLIP reflow.
- Reduce Motion remains supported.
- Universal 2: arm64 + x86_64.
- Sparkle EdDSA update verification.
- Minimum macOS: 14.0.
- Bundle ID: `com.zhangqiaoran.myalttab`.
- Marketing version: **3.4.3**.
- Internal build: **30604**.
