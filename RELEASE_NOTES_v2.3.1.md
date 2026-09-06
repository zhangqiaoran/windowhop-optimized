# my-alt-tab v2.3.1

**Author / maintainer / release owner: zhangqiaoran**

## Install

1. Existing v2.3.0 build 20301 users can update through **Settings → Updates**.
2. Or download `my-alt-tab-2.3.1.zip` from GitHub Releases.
3. Unzip it to get `my-alt-tab.app`, then place it in `/Applications`.

## Liquid Glass

- Renamed the appearance setting to **Liquid Glass transparency**.
- 100% remains the clearest native Liquid Glass presentation.
- The transparency control now uses a perceptual density curve, so 90% already looks noticeably denser instead of almost identical to 100%.
- The user setting still persists as the same 0–100 value; existing preferences are preserved during upgrade.
- On macOS 26+, the selected window now gets its own native `NSGlassEffectView` layer for a true layered Liquid Glass focus effect.
- Earlier macOS versions use the closest native `NSVisualEffectView` fallback.
- Stronger selection glow remains clip-safe on the right and bottom edges.

## Existing 2.3 features retained

- Signed Sparkle automatic updates and manual **Check for Updates…**.
- Universal 2 support for Apple Silicon and Intel.
- Polished my-alt-tab About interface.
- Clip-safe right/bottom spacing and dedicated ellipsis chrome.
- Immediate close removal with the deterministic 28-particle dissolve.

## Build

- Marketing version: **2.3.1**
- Internal build: **20302**
- Minimum macOS: **14.0**
- Bundle ID: `com.zhangqiaoran.myalttab`

No telemetry, analytics, accounts, or advertising.
