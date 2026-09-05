# my-alt-tab

**A native macOS window switcher by zhangqiaoran.**  
Current release line: **v2.0.0** · macOS 14+ · Swift / AppKit · GPL-3.0

my-alt-tab is developed, maintained, and released by **zhangqiaoran**. Version 2.0 starts a new product direction: a more premium visual experience without turning a window switcher into a heavy background application.

> GPL-3.0 attribution for inherited code is preserved in [`UPSTREAM.md`](UPSTREAM.md) and [`LICENSE`](LICENSE).

**中文：[`README.zh-CN.md`](README.zh-CN.md)**

## 2.0 — Glass Focus Engine

The 2.0 interface is built around a **shared glass surface**, not one blur layer per window. On macOS 26+ the switcher uses the system `NSGlassEffectView`; macOS 14/15 use the native `NSVisualEffectView` fallback.

Selection is intentionally unmistakable:

- one **Focus Lens** follows the active thumbnail;
- the selected card gets a subtle 2.2% optical lift;
- distance-adaptive motion keeps nearby Tab steps immediate while longer grid moves stay readable;
- Reduce Motion disables transition animation automatically;
- there are no looping highlight, shimmer, or idle animations.

The key design constraint: **the number of animated compositor surfaces does not grow with the number of windows**.

## Constant-cost interaction architecture

| Hot path | 2.0 implementation | Complexity / cost |
|---|---|---|
| Selection movement | cached lens frames + old/new tile delta | **O(1)** |
| Selection animation | one Focus Lens + at most two tile transforms | **constant compositor work** |
| Preview delivery | hash-indexed Window ID | average **O(1)** |
| Preview refresh | zero-sort priority buckets | **O(n)** |
| Window-preview matching | PID buckets + flat score matrix + dense masks | avoids irrelevant cross-app comparisons |
| Capture duplication | active-session in-flight ID set | duplicate capture suppressed |
| EventTap key-up state | 128-bit fast-path bitset | no Set allocation for normal keycodes |
| Session reconciliation | pre-sized single-pass hash structures | fewer temporary objects |
| Preview memory | ~64 MiB byte-bounded cache + transient release | bounded long-run memory |

2.0 deliberately avoids “algorithm theatre.” Monitor selection remains an O(display count) point-in-rectangle pass because 1–4 displays are common and a spatial tree would cost more than the problem.

## Glass without the GPU tax

The list owns one shared native blur plane. Individual thumbnails do **not** each create their own effect view. The result is a genuine macOS glass presentation without an N-window blur multiplier.

Rendering rules remain strict:

- no per-thumbnail drop shadows;
- no infinite skeleton animation;
- no full-grid layout pass on every Tab step;
- preview crossfades are short and session-scoped;
- hidden pooled tiles release heavy image references;
- the close control keeps a 44×44 hit target even though its visible chrome is compact.

## Multi-display focus

With Focused multi-display mode enabled:

- the panel appears only on the display containing the pointer;
- eligible windows from all connected displays remain available;
- pointer display is resolved only when opening the switcher;
- no continuous mouse polling and no idle monitor timer.

## Window close behavior

- close button: close the selected window;
- Delete / Backspace: close the selected window;
- Finder: close only the selected Finder window;
- my-alt-tab does not add a second close-vs-quit prompt;
- the target application's own unsaved-document confirmation is still respected.

## Product UI

Repository screenshots are generated from the app's own UI/demo harness. System glass rendering varies slightly by macOS release.

![my-alt-tab window preview interface](docs/screenshots/switcher-previews-light.png)

![my-alt-tab Windows settings](docs/screenshots/settings-windows.png)

## Keyboard

| Keys | Action |
|---|---|
| **⌘⇥** | Open / cycle forward |
| **⇧⌘⇥** | Cycle backward |
| **Release ⌘** | Activate selected window |
| **← → ↑ ↓** | Navigate |
| **Return / Space** | Confirm |
| **Esc** | Cancel |
| **Delete / Backspace** | Close selected window |
| **⌘,** | Settings |

## Privacy and runtime policy

- Native Swift / AppKit.
- ScreenCaptureKit is isolated to the preview provider.
- Window snapshots stay in memory; they are not written to disk or uploaded.
- No telemetry, no account, no analytics SDK.
- No background polling was added for 2.0.
- No new runtime dependency was added for 2.0.
- Community auto-update remains disabled until a zhangqiaoran-controlled signing/appcast channel exists.

## Build

```bash
git clone https://github.com/zhangqiaoran/windowhop-optimized.git my-alt-tab
cd my-alt-tab
chmod +x scripts/package-app.sh
./scripts/package-app.sh
```

Outputs:

```text
build/my-alt-tab.app
artifacts/my-alt-tab-2.0.0.zip
```

Without a Developer ID certificate, the packaging script uses ad-hoc signing.

## Release line

- **v1.0.0** — project baseline under zhangqiaoran.
- **v1.1.0** — hot-path optimization, bounded preview memory, O(1) selection repaint.
- **v2.0.0** — Glass Focus Engine, shared-blur architecture, constant-cost selection motion, premium focus feedback.

Full notes: [`RELEASE_NOTES_v2.0.0.md`](RELEASE_NOTES_v2.0.0.md)

## Identity

- Author / maintainer / release owner: **zhangqiaoran**
- Version: **2.0.0**
- Build: **20000**
- Bundle ID: `com.zhangqiaoran.myalttab`
- Repository: `zhangqiaoran/windowhop-optimized`
- License: GNU GPL-3.0
