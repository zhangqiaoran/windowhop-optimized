# my-alt-tab

Native macOS window switcher maintained by **zhangqiaoran**.

**Current release: v3.0.0** · macOS 14+ · Swift / AppKit · GPL-3.0  
中文说明：[`README.zh-CN.md`](README.zh-CN.md)

## Install

1. Open **Releases**.
2. Download `my-alt-tab-3.0.0.zip`.
3. Unzip it to get **my-alt-tab.app**.
4. Drag **my-alt-tab.app** into **Applications**.
5. On first launch, grant **Accessibility** permission. Grant **Screen Recording** only if you use window previews.

## v3.0.0

- **Fluid list reflow:** when windows disappear from an open switcher, survivors are matched by stable window ID and spring from their current presentation-layer positions while the centered panel shrinks with native AppKit animation.
- **Dusting close engine:** window close now uses a deterministic 56-particle R2 low-discrepancy distribution, gradient erosion, and cubic inward/upward wind paths for a softer drifting disintegration.
- **Interruptible motion:** repeated closes start from the currently rendered Core Animation presentation state instead of stale geometry, avoiding jumps during fast interaction.
- **Proactive Updates:** opening Settings → Updates silently probes the signed Sparkle feed; a new version exposes a prominent **Update Now…** path into Sparkle's verified installer.
- **Zero idle animation cost:** no display link, repeating particle timer, or background motion loop was added. Reduce Motion is respected.
- Removed obsolete UI design tokens left over from earlier layout iterations.

## v2.4.0

- **Liquid Glass now means real transparency:** higher values are more transparent; 100% is the clearest native glass.
- On macOS 26+, the switcher uses native `NSGlassEffectView.Style.clear` instead of trying to simulate transparency through tint alone.
- A separate background-density layer provides a smooth literal 0–100 range without fading previews, icons, or text.
- The selected window follows the same Liquid Glass level with its own native glass focus surface.
- Signed Sparkle automatic updates remain enabled.

## v2.3.1

- Refined **Liquid Glass** with a perceptual 0–100% transparency curve, so 90% is already visibly denser than the fully clear 100% endpoint.
- Selected windows now use a layered native Liquid Glass focus surface on macOS 26+, with a visual-effect fallback on older systems.
- Preserves the stronger selection glow while keeping the right and bottom edges clip-safe.
- Signed Sparkle automatic updates remain enabled.

## v2.3

- Signed Sparkle updates are enabled for future releases; automatic checks and native manual update checks are available in Settings.
- Appearance includes a live **Liquid Glass transparency** slider from 0% to 100%.
- More breathing room on the right and bottom edges.
- The top-right **ellipsis (…)** lives in its own chrome strip and no longer covers thumbnails.
- Closing a window removes it from the switcher immediately while a denser 28-particle dissolve plays.
- Keeps Universal 2 support for Intel + Apple Silicon.

## UI

### Window previews
![my-alt-tab window previews](docs/screenshots/switcher-previews-light.png)

### Dark appearance
![my-alt-tab dark window previews](docs/screenshots/switcher-previews-dark.png)

### Settings
![my-alt-tab settings](docs/screenshots/settings-windows.png)

## Build from source

```bash
git clone https://github.com/zhangqiaoran/my-alt-tab.git
cd my-alt-tab
chmod +x scripts/package-app.sh
./scripts/package-app.sh
```

Output:

```text
build/my-alt-tab.app
artifacts/my-alt-tab-3.0.0.zip
```

Official GitHub releases are verified as **Universal 2** builds for both **Intel (x86_64)** and **Apple Silicon (arm64)**.

## Project

- Author / maintainer / release owner: **zhangqiaoran**
- Bundle ID: `com.zhangqiaoran.myalttab`
- License: GNU GPL-3.0
- Upstream attribution: [`UPSTREAM.md`](UPSTREAM.md)
