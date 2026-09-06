# my-alt-tab v3.4.3

**Author / maintainer / release owner: zhangqiaoran**

## Rapid Alt / Option + Tab switching fixed

- Fixed a real input race when repeatedly switching between two windows very quickly.
- The event tap now ends the held session **synchronously when Alt/Option is released**, instead of waiting for the semantic release to reach the main thread.
- A new Alt/Option+Tab pressed while the main queue is still finishing the previous switch is therefore recognized as a fresh trigger, not as a stale `step` event that gets discarded after the old session closes.
- The controller no longer rewrites the tap's held/sticky mode when showing a panel, preventing delayed UI work from resurrecting an already-released session or overwriting a newer one.
- A committed window activation is promoted in MRU order immediately, before asynchronous AX focus notifications arrive. This makes rapid 1↔2 toggling target the actual previous window instead of occasionally snapshotting stale MRU order.
- Regression tests reproduce the release/repress sequence without waiting for the main thread and verify the immediate MRU swap.

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
- Internal build: **30605**.
