# my-alt-tab v3.5.0

**Author / maintainer / release owner: zhangqiaoran**

## Native Liquid Glass architecture

v3.5 corrects a structural mistake in the 3.4 renderer.

Apple's AppKit guidance for Liquid Glass is to place foreground content in
`NSGlassEffectView.contentView`. That lets AppKit apply the material's adaptive
legibility, sampling, reflection, and refraction treatments as one coherent effect.

The 3.4 renderer instead placed the glass behind switcher chrome as a sibling and then
changed the whole glass view's alpha. That weakened the material itself together with
its highlights/refraction and made the result read more like a translucent panel than
Control Center-style Liquid Glass.

### v3.5 hierarchy

On macOS 26+:

1. `NSGlassEffectContainerView` provides one shared glass sampling group.
2. The main `NSGlassEffectView` is a descendant of that group.
3. `chromeView` is the main glass view's actual `contentView`.
4. The contextual ellipsis uses its own small `NSGlassEffectView` in the same container.
5. Container spacing is zero: glass shapes share sampling/performance without forced merging.

On older macOS versions, `NSVisualEffectView` remains the compatibility path and also
contains the switcher chrome rather than sitting behind it as an unrelated sibling.

## Slider semantics

The user contract remains simple:

- **100% = maximum Liquid Glass**
- **0% = strongest milky glass**

The native `NSGlassEffectView` now remains **alpha 1.0 at all values**.

At 100%:

- style = `.clear`
- tintColor = nil
- glass alpha = 1
- system refraction/highlights/background sampling stay fully active

As the slider moves downward, only a perceptual white `tintColor` is added. The curve
uses `(1 - liquid)^1.65`, so 90–100% remains strongly liquid while the lower half
becomes visibly milkier.

No thumbnail, label, control, or focus-ring alpha is used to simulate glass strength.

## Video-driven dissolve-tail analysis

The supplied recording is approximately **29.87 FPS**. The visible cadence change near
the end of the dissolve also had a direct source-code explanation.

3.4 timing:

- total dissolve lifetime: 1.02 s
- Stable-ID FLIP hand-off: 80% = 0.816 s
- fragment-mask erosion duration: 0.88 s
- fragment-mask count: 36
- mask animation: discrete + eased timing

That meant the final ~64 ms of bitmap-mask swaps overlapped the first window/list resize
frames. With only 36 discrete masks, the eased timing also concentrated visible state
changes toward portions of the animation.

## v3.5 erosion pacing

- Fragment masks: **96**
- Normalized mask size: 112 × 70
- Temporal key spacing: **linear**
- Erosion duration: hand-off time minus one nominal 60 Hz frame
- FLIP hand-off remains at 80%
- Dust/haze remains free to continue across the hand-off

96 frames across the shortened erosion phase produce roughly **120 mask states per
second**. A 60 Hz display naturally coalesces frames; a high-refresh display has enough
intermediate states to avoid the old visible stepping.

The important choreography is now:

1. Thumbnail pixels finish their irregular erosion.
2. One display-frame-sized settle gap passes.
3. Stable-ID FLIP begins.
4. Dust and haze continue as a compositor-only tail.

No final mask upload competes with the first panel-resize frame.

## Lower bandwidth and first-close latency

The old atlas stored every mask as 32-bit RGBA. v3.5 stores compact grayscale+alpha
masks, halving bytes per pixel while preserving the same alpha information.

Both directional atlases and the particle texture are also prewarmed on a utility queue
before the first close interaction. The click path only selects already-built assets and
starts Core Animation.

## Existing motion architecture retained

- Real target window closes immediately.
- Source tile becomes a hidden visual ghost after snapshot capture.
- Snapshot pixels genuinely erode.
- Dust emitter follows the moving erosion front.
- Reflow starts at the existing 80% hand-off.
- Window, glass, surviving cards, scroll geometry, controls, and focus ring use the
  Stable-ID unified FLIP transaction.
- Reduce Motion skips the decorative delay.
- No display link or per-frame CPU particle simulation.

## Build

- Marketing version: **3.5.0**
- Internal build: **30500**
- Minimum macOS: **14.0**
- Architectures: **arm64 + x86_64 (Universal 2)**
- Bundle ID: `com.zhangqiaoran.myalttab`
- App signing: ad-hoc community build
- Update integrity: Sparkle EdDSA
