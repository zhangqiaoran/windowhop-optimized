# my-alt-tab v1.0.0

**Author / maintainer / release publisher: zhangqiaoran**

This is the first zhangqiaoran-maintained release line. The goal is a lightweight and stable macOS window switcher for multi-display workflows, with cross-display previews and reduced repeated capture work.

## New in 1.0.0

### Multi-display workflow
- The switcher appears on **only the display currently containing the mouse pointer**.
- Candidate windows still come from **all connected displays**.
- Pointer display is resolved at session open; no continuous mouse-move tracker is added.
- Legacy display-placement controls remain available when Focused multi-display mode is disabled.

### Thumbnail layout
- Added **Left / Center / Right** preview-row alignment.
- Center remains the default to preserve previous visual behavior.

### Direct window closing
- Close button and Delete/Backspace now close the selected window directly.
- Removed the legacy close-vs-quit confirmation path.
- Finder closes only the selected Finder window.
- Application-native unsaved-document prompts are still respected.

### Reliability
- Strengthened global `CGEventTap` recovery.
- Disabled taps can be re-enabled; invalid taps can be recreated.
- Recovery integrates with sleep/wake and session transitions without a high-frequency watchdog.

### Preview performance
- Added bounded **LRU-style preview caching** (~64 MiB budget).
- Fresh preview reuse reduces repeated ScreenCaptureKit requests.
- Selected/missing/stale previews are refreshed in priority order.
- Large expanded previews no longer pollute the normal tile cache.
- Window IDs use direct hash indexing for average near-O(1) lookup on asynchronous preview completion.
- Preview matching is partitioned by **PID buckets**.
- Same-process match scores are computed once and reused through compact matching data.
- Hot paths reduce unnecessary intermediate arrays/dictionaries.

### Project identity
- Version reset to **1.0.0** for the zhangqiaoran-maintained release line.
- Bundle ID is now `com.zhangqiaoran.myalttab`.
- App About identifies **zhangqiaoran** as current developer/maintainer.
- Project links point to `zhangqiaoran/windowhop-optimized`.
- Upstream Sparkle update feed and public key are disconnected so this build cannot silently update into another release line.
- GPL-3.0 and upstream attribution remain preserved.

## Build

```bash
chmod +x scripts/package-app.sh
./scripts/package-app.sh
```

Expected output:

```text
build/my-alt-tab.app
artifacts/my-alt-tab-1.0.0.zip
```

## Notes

Community builds use ad-hoc signing when no Apple Developer ID is supplied. Users may need to grant Accessibility and, when using previews, Screen Recording permission to this new bundle identity.
