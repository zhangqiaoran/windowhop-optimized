# my-alt-tab v3.4.0

**Author / maintainer / release owner: zhangqiaoran**

## Liquid Glass now follows the slider literally

The user-facing contract is now:

- **100% → most liquid / transparent**
- **0% → most milky / dense**

The previous renderer kept foreground content inside `NSGlassEffectView.contentView`. That
made the material and content too tightly coupled: reducing material opacity could also affect
the foreground, so earlier versions mostly changed a white density overlay instead.

v3.4 splits the hierarchy into three independent planes:

1. **Native glass background** — material only.
2. **Milky density layer** — background-only and user controlled.
3. **Foreground chrome** — thumbnails, icons, labels, controls, and focus ring at full opacity.

On macOS 26+ the material remains native `NSGlassEffectView.Style.clear`.

### Perceptual mapping

For a user value `p`:

- liquid factor = `p / 100`
- milk factor = `(1 - liquid)^1.55`
- glass surface alpha = `0.60 + 0.40 × (1 - liquid)^0.85`
- milk alpha = `0.72 × milk factor`

Important endpoints:

- **100%:** glass surface ≈ 0.60, milk = 0.00
- **50%:** glass becomes stronger while milk becomes clearly visible
- **0%:** glass surface = 1.00, milk = 0.72

This makes 90–100% stay genuinely transparent while the lower half transitions much more
obviously toward an intentional milky-white body.

The Release environment was also checked directly: the current GitHub build uses
**Apple Swift 6.3.3 targeting macOS 26.0**, so the native Glass code is included in the binary.

## Stable-ID unified FLIP reflow

The old close reflow mixed two animation systems:

- `NSWindow` frame movement through AppKit.
- surviving tile positions through independent `CABasicAnimation`.

Even with equal duration values those two systems do not share the exact same animation clock.
Combined with live glass resize and selected-tile scale motion, the result could look like a
small hitch or dropped frame.

v3.4 replaces that path with one Stable-ID FLIP transaction:

1. Capture current presentation geometry by stable window ID.
2. Build the final layout.
3. Restore the visible first geometry.
4. Animate every geometric participant through one `NSAnimationContext`:
   - NSWindow frame
   - native glass background
   - foreground chrome
   - milky density view
   - scroll view
   - document view
   - surviving window tiles
   - global controls
   - blue focus ring
5. Snap to exact final geometry on completion.

The NSWindow animation uses `display: false` during the transition to avoid forcing synchronous
glass redraw work on every intermediate resize frame. The final frame is displayed once at completion.

The old independent tile-position CA animations are removed. The selected tile also no longer
scales to 1.018×; selection is communicated only through the existing blue focus ring.

## Existing close effect retained

- Real window closes immediately.
- Original source tile is visually hidden.
- 36-frame deterministic alpha-mask atlas genuinely erodes the snapshot.
- Dust is emitted from a narrow moving erosion front.
- Reflow begins at 80% of the 1.02 s dissolve lifetime.
- Dust/haze tail remains compositor driven.

## Performance

- No display link.
- No per-frame CPU particle simulation.
- No runtime random generator.
- No mixed CA/AppKit reflow clocks.
- Stable-ID lookup remains linear only when the list changes; keyboard selection remains O(1).
- Universal 2 remains supported.

## Signing and updates

3.4.0 remains an ad-hoc signed community release. Sparkle verifies the update archive with the
project's EdDSA key. Accessibility / Screen Recording may need re-authorization after an ad-hoc update.

## Build

- Marketing version: **3.4.0**
- Internal build: **30400**
- Minimum macOS: **14.0**
- Architectures: **arm64 + x86_64 (Universal 2)**
- Bundle ID: `com.zhangqiaoran.myalttab`
