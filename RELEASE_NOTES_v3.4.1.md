# my-alt-tab v3.4.1

**Author / maintainer / release owner: zhangqiaoran**

## Liquid Glass corrected

- macOS 26+ uses `NSGlassEffectContainerView → NSGlassEffectView → contentView → switcher chrome`.
- The large switcher and contextual ellipsis use native Regular Liquid Glass.
- Native Glass remains alpha 1.0 at every slider value.
- 100% adds no white tint; lower values add a nonlinear milky tint without weakening native refraction, adaptive background response, or highlights.
- Real `NSGlassEffectView` uses AppKit's native dynamic edge treatment instead of a custom CALayer white border.
- `effectIsInteractive` is enabled only when the running AppKit exposes the beta selector, keeping the release compatible with the current Xcode 26 SDK overlay.

## Pointer routing fixed

- Close, Settings, and preview-permission clicks are resolved at the `SwitcherPanel` boundary from final host-space rectangles.
- Global panel buttons accept first mouse in the nonactivating panel.
- Close routing no longer depends on nested Glass / ScrollView `hitTest` forwarding.
- Visible controls therefore remain clickable even when the native Liquid Glass hierarchy changes internally.
- The session-wide global mouse monitor now checks the click's AppKit screen coordinate against every visible switcher panel before calling `outsideClick()`. A click inside a nonactivating panel can no longer cancel the whole switcher before its local control/tile handler runs.

## Dissolve tail refined

- 96 deterministic grayscale+alpha erosion-mask states.
- Linear temporal pacing with assets prewarmed off the close hot path.
- Pixel erosion ends one nominal 60 Hz frame before the 80% Stable-ID FLIP hand-off.
- Dust and haze remain compositor-driven and may continue across the hand-off.
- The real target window still closes immediately; the switcher tile is only a short-lived visual ghost.

## Compatibility

- Marketing version: **3.4.1**
- Internal build: **30602**
- The build number intentionally remains above the briefly published 3.5/3.6 builds, and 30602 supersedes the first 3.4.1 package so existing installations receive this input-routing hotfix.
- Minimum macOS: **14.0**
- Architectures: **arm64 + x86_64 (Universal 2)**
- Bundle ID: `com.zhangqiaoran.myalttab`
- App signing: ad-hoc community build
- Update integrity: Sparkle EdDSA
