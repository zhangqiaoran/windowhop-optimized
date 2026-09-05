# WindowHop Optimized

**Lightweight macOS window switching by zhangqiaoran.**
Current release: **v1.1.0** · macOS 14+ · Native Swift / AppKit · GPL-3.0

WindowHop Optimized is developed, maintained, and released by **zhangqiaoran**. The project focuses on one thing: make `⌘ Tab` window switching fast, stable, visually clean, and inexpensive to keep running all day.

> GPL-3.0 upstream attribution for inherited code is preserved in [`UPSTREAM.md`](UPSTREAM.md) and [`LICENSE`](LICENSE).

**中文说明：[`README.zh-CN.md`](README.zh-CN.md)**

## v1.1.0 — Performance + Lightweight UI

v1.0.0 is the frozen project baseline. v1.1.0 keeps its multi-display behavior and direct-close workflow, then optimizes the paths that run most often while the switcher is open.

### Performance architecture

| Area | v1.1 implementation | Why it matters |
|---|---|---|
| Selection repaint | **O(1) old/new tile update** | Tab/arrow traversal no longer repaints every visible tile |
| Preview lookup | **Hash-indexed IDs** | near O(1) average lookup instead of repeated scans |
| Preview matching | **PID buckets + flat score matrix + dense active masks** | removes irrelevant cross-app comparisons and per-round Set/Dictionary churn |
| Preview refresh | **O(n) priority planner returning indices** | no temporary ID→request dictionary round-trip |
| Capture scheduling | **session in-flight deduplication** | repeated AX/window-store refreshes do not capture the same window twice |
| Key interception | **128-bit key-up bitset** | normal macOS keycodes avoid Set hashing/allocation in the EventTap hot path |
| Session reconciliation | **single-pass pre-sized hash structures** | fewer temporary arrays during Chrome/IDE/Finder window churn |
| Thumbnail memory | **bounded ~64 MiB LRU-style cost cache** | long-running sessions cannot grow preview memory without bound |
| Hidden tile memory | **transient preview release** | pooled hidden tiles do not keep evicted images alive |
| Expanded preview | **explicit image release on hide** | large dwell snapshots are not unnecessarily retained |

The algorithms are deliberately simple where the data size is small. For display detection, for example, an O(number of displays) point-in-rect scan is faster and lighter than maintaining a spatial tree for the usual 1–4 monitors.

### Lightweight UI

v1.1 reduces visual/compositor overhead instead of adding effects:

- tighter panel padding, tile spacing, and preview dimensions;
- static loading placeholder — **no infinite skeleton animation**;
- preview card drop shadows removed to reduce per-tile compositing;
- selection/hover changes repaint only; they no longer force geometry layout;
- shorter preview crossfades;
- close button keeps a 44×44 hit target while its visible chrome is smaller;
- left / center / right preview-row alignment remains available.

### Multi-display behavior

With **Focused multi-display mode** enabled:

- the switcher panel appears **only on the display containing the mouse pointer**;
- candidate windows still include eligible windows from **all connected displays**;
- pointer location is resolved when the switcher opens — no continuous `mouseMoved` listener and no idle polling.

### Window close behavior

- close button → closes the selected window directly;
- Delete / Backspace → closes the selected window directly;
- no WindowHop close-vs-quit confirmation;
- Finder closes only the selected Finder window;
- an application's own unsaved-document dialog is still respected.

## Screenshots

### Window switching

![WindowHop v1.1 multi-window switcher](docs/screenshots/v1.1-switcher.jpg)

### Lightweight settings UI

![WindowHop v1.1 Appearance settings](docs/screenshots/v1.1-settings.jpg)

## Keyboard controls

| Keys | Action |
|---|---|
| **⌘⇥** | Open / cycle forward |
| **⇧⌘⇥** | Cycle backward |
| **Release ⌘** | Activate selected window |
| **← → ↑ ↓** | Navigate |
| **Return / Space** | Confirm |
| **Esc** | Cancel |
| **Delete / Backspace** | Close selected window directly |
| **⌘,** | Settings |

## Privacy and resource policy

- Native Swift / AppKit.
- ScreenCaptureKit is confined to the preview provider.
- No telemetry and no account.
- No new runtime dependency was added for v1.1.
- No background polling was added.
- Window snapshots stay in memory and are not written to disk or transmitted.
- Community auto-update remains disabled until zhangqiaoran-controlled signing/appcast infrastructure is configured.

## Build

Requirements: macOS 14+, Xcode 16+ recommended.

```bash
git clone https://github.com/zhangqiaoran/windowhop-optimized.git my-alt-tab
cd my-alt-tab
chmod +x scripts/package-app.sh
./scripts/package-app.sh
```

Outputs:

```text
build/my-alt-tab.app
artifacts/my-alt-tab-1.1.0.zip
```

A Developer ID is not required for personal/community builds; the packaging script falls back to ad-hoc signing.

## Release line

- **v1.0.0** — frozen zhangqiaoran baseline: multi-display focus mode, all-display candidates, direct close, LRU/freshness preview cache, EventTap recovery.
- **v1.1.0** — hot-path algorithm optimization, duplicate-capture suppression, bounded transient memory, O(1) selection repaint, and a lighter UI/compositor path.

Full notes: [`RELEASE_NOTES_v1.1.0.md`](RELEASE_NOTES_v1.1.0.md)

## Project identity

- Author / maintainer / release owner: **zhangqiaoran**
- Current version: **1.1.0**
- Bundle ID: `com.zhangqiaoran.myalttab`
- Repository: `zhangqiaoran/windowhop-optimized`
- License: GNU GPL-3.0
