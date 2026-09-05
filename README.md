# WindowHop

**macOS window switcher maintained and released by [zhangqiaoran](https://github.com/zhangqiaoran).**  
Current release: **v1.0.0** · macOS 14+ · GPL-3.0 · Native Swift/AppKit

> WindowHop Optimized is a modified GPL-3.0 distribution based on the open-source WindowHop project by Marton Paulo, which itself acknowledges AltTab by Louis Pontoise (lwouis) and contributors. Upstream attribution and license notices are preserved in [`UPSTREAM.md`](UPSTREAM.md), [`AUTHORS.md`](AUTHORS.md), and [`LICENSE`](LICENSE).

**中文说明：[`README.zh-CN.md`](README.zh-CN.md)**

## Why this version

This project focuses on a lightweight, fast, stable macOS `⌘ Tab` workflow, especially for users with multiple displays and many open windows. It intentionally avoids high-frequency mouse tracking, background polling, telemetry, and unnecessary dependencies.

## v1.0.0 highlights

- **Pointer-display switcher:** exactly one switcher panel appears on the display containing the mouse pointer.
- **All-display candidates:** the panel still loads eligible windows from every connected display.
- **Preview row alignment:** Left / Center / Right alignment for incomplete thumbnail rows.
- **Direct window close:** the close button and Delete/Backspace close the selected window immediately, without WindowHop's old close-vs-quit confirmation. Finder closes only the selected Finder window.
- **EventTap self-healing:** a disabled or invalid global event tap can be re-enabled or rebuilt after system interruptions, sleep/wake, or session transitions.
- **Bounded preview cache:** cost-aware LRU-style caching limits long-running memory growth.
- **Freshness-aware refresh:** fresh previews are reused; missing/selected/stale previews are refreshed in priority order.
- **PID bucketing:** window-preview matching is partitioned by process to avoid irrelevant cross-app comparisons.
- **Hash-indexed hot paths:** window IDs map directly to model/index state for near O(1) average lookup.
- **Compact score reuse:** same-process matching scores are computed once and reused.
- **No new background poller:** pointer display is resolved when the switcher opens, not via continuous `mouseMoved` tracking.

See [`RELEASE_NOTES_v1.0.0.md`](RELEASE_NOTES_v1.0.0.md) for the complete first-release notes.

## Keyboard controls

| Keys | Action |
|---|---|
| **⌘⇥** | Open WindowHop / cycle forward |
| **⇧⌘⇥** | Cycle backward |
| **Release ⌘** | Activate selected window |
| **← → ↑ ↓** | Navigate |
| **Return / Space** | Confirm |
| **Esc** | Cancel |
| **Delete / Backspace** | Close selected window directly |
| **⌘,** | Open Settings |

## Multi-display behavior

With **Settings → Windows → Focused multi-display mode** enabled (default):

```text
MacBook display        External A        External B
                                            ↑ pointer
                                            │
                                      [ WindowHop ]
```

Only External B shows the switcher, but candidate windows can come from **MacBook + External A + External B**. Move the pointer to another display and the next switcher session opens there.

## Preview alignment

Open **Settings → Appearance → Preview row alignment** and choose:

- Left
- Center (default)
- Right

## Permissions

WindowHop requires **Accessibility** permission to intercept the global shortcut and focus/close windows. **Screen Recording** is required only when Window Previews are enabled. Captured previews stay in memory; the project does not upload them.

## Build locally

Requirements: macOS 14+, Xcode 16+ recommended.

```bash
git clone https://github.com/zhangqiaoran/windowhop-optimized.git
cd windowhop-optimized
chmod +x scripts/package-app.sh
./scripts/package-app.sh
```

Outputs:

```text
build/WindowHop.app
artifacts/WindowHop-1.0.0.zip
```

Without a Developer ID identity, the packaging script uses an ad-hoc signature suitable for development and personal use.

## Build with GitHub Actions

Open **Actions → Build WindowHop App → Run workflow**. The macOS runner executes tests and builds an ad-hoc signed archive, then exposes it under **Artifacts**.

## Release workflow

This repository includes `.github/workflows/release-community.yml`. To publish a version whose `Support/Info.plist` already contains the matching version:

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will test, validate, package and create the GitHub Release automatically. This community workflow does **not** pretend to be an Apple-notarized Developer ID release.

## Update policy

The upstream Sparkle feed is intentionally disconnected in this distribution. `v1.0.0` does not automatically replace itself with an upstream build. Future release/update infrastructure should use zhangqiaoran-controlled signing keys and URLs.

## Project identity

- Maintainer / current release author: **zhangqiaoran**
- Current version: **1.0.0**
- Bundle ID: `com.zhangqiaoran.windowhop`
- Repository: `zhangqiaoran/windowhop-optimized`
- License: **GNU GPL-3.0**

## Upstream attribution

This is modified GPL software, so the upstream work is not erased or re-labeled as wholly original code. See [`UPSTREAM.md`](UPSTREAM.md) and [`AUTHORS.md`](AUTHORS.md) for preserved attribution.
