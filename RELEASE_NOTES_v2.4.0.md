# my-alt-tab v2.4.0

**Author / maintainer / release owner: zhangqiaoran**

## Update

Existing v2.3.1 users can install v2.4.0 through **Settings → Updates → Check for Updates…**.
The archive is signed for Sparkle with the same my-alt-tab EdDSA update key.

## Liquid Glass rebuilt

v2.3.1 used the native glass surface, but its user percentage primarily changed
`NSGlassEffectView.tintColor`. Apple defines `tintColor` as a color tint for the glass;
it is not a literal transparency control. v2.4.0 separates those responsibilities.

- **Higher = more transparent.**
- **100%** uses native clear Liquid Glass with no added density.
- **90%** adds 10% material density.
- **50%** adds 50% material density.
- **0%** applies the maximum configured density.
- macOS 26+ uses native `NSGlassEffectView.Style.clear` for both the switcher panel and
  the selected-window focus surface.
- A dedicated background-only density layer controls opacity. Window previews, application
  icons, titles, badges, and controls remain at full opacity.
- The selected window follows the same transparency setting, with a restrained accent tint
  and soft glow so the focus remains visible without becoming an opaque blue plate.
- macOS 14/15 continue to use the closest native `NSVisualEffectView` fallback.
- Right and bottom clip-safe space is preserved for the stronger focus glow.

## Existing behavior retained

- Signed Sparkle automatic updates and manual update checks.
- Universal 2 support for Apple Silicon and Intel.
- Fast two-window MRU switching and keyboard navigation.
- Immediate direct window close with the bounded 28-particle dissolve.
- No telemetry, analytics, accounts, advertising, or additional runtime dependency.

## Build

- Marketing version: **2.4.0**
- Internal build: **20400**
- Minimum macOS: **14.0**
- Bundle ID: `com.zhangqiaoran.myalttab`
