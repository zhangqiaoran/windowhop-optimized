# my-alt-tab v3.6.0

**Author / maintainer / release owner: zhangqiaoran**

## Close-button regression fixed

3.5 moved switcher content into the native macOS 26 Liquid Glass hierarchy. That
improved material composition but exposed a hit-testing regression for the hover Close
control: the button intentionally overlaps the preview canvas edge, and the switcher is a
nonactivating NSPanel.

3.6 makes close routing independent of Glass implementation details:

1. `OverlayCloseButton.acceptsFirstMouse` always returns true.
2. The existing 44×44 close hit target remains unchanged.
3. `SwitcherPanel.sendEvent` checks visible close-hit regions before normal event dispatch.
4. If a close target is hit, the request is sent directly to the same close path used by Delete.
5. Normal clicks continue through AppKit unchanged when no close target is present.

This prevents private/internal Glass wrappers from making a visible Close button inert.

## Regular Liquid Glass

The native hierarchy remains:

`NSGlassEffectContainerView → NSGlassEffectView → contentView → switcher chrome`.

The material choice is now consistently **Regular** for the large switcher surface and
contextual ellipsis glass. The switcher contains previews, labels, and interactive controls,
so Regular Glass is the more appropriate adaptive material.

The slider contract is:

- **100%:** Regular Glass alpha = 1, white tint = 0.
- **Lower values:** Regular Glass stays alpha = 1; nonlinear white tint increases.
- **0%:** strongest configured milky tint.

No slider value fades the whole Glass view. Native refraction, adaptive background response,
and edge highlights therefore remain present at the liquid end.

## Native edge treatment

3.5 still applied a custom CALayer white border to native NSGlassEffectView. 3.6 removes
that border on macOS 26 so AppKit can render its own dynamic Liquid Glass edge treatment
without a static outline painted over it.

The manual semantic border remains only on the pre-macOS-26 NSVisualEffectView fallback.

## Beta interactive-glass compatibility

Apple currently documents `NSGlassEffectView.effectIsInteractive` as a beta property,
but the GitHub Release Xcode 26 Swift SDK used by this project does not expose the member
directly to Swift.

3.6 therefore uses a runtime bridge:

- probe `setEffectIsInteractive:` with `responds(to:)`;
- enable it through KVC only when the running AppKit implements the selector;
- otherwise continue with static Regular Glass.

This keeps the same binary compatible with the current Release SDK while allowing newer
runtime implementations to opt into interactive visual feedback.

## Dissolve and reflow retained

3.6 keeps the 3.5 motion pipeline:

- real window closes immediately;
- original tile is visually hidden after snapshot capture;
- 96 deterministic grayscale+alpha erosion masks;
- approximately 120 mask states/s with linear temporal pacing;
- erosion assets prewarmed off the close hot path;
- pixel erosion ends one nominal 60 Hz frame before the 80% reflow hand-off;
- dust/haze continues across the hand-off;
- Stable-ID unified FLIP performs the list/panel reflow;
- no display link or per-frame CPU particle simulation.

## Validation

The 3.6 implementation commit passed:

- Unit Tests
- Repository Validation
- Universal 2 packaging
- Bundle verification
- Artifact upload

## Build

- Marketing version: **3.6.0**
- Internal build: **30600**
- Minimum macOS: **14.0**
- Architectures: **arm64 + x86_64 (Universal 2)**
- Bundle ID: `com.zhangqiaoran.myalttab`
- App signing: ad-hoc community build
- Update integrity: Sparkle EdDSA
