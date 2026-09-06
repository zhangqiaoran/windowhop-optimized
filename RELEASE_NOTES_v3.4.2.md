# my-alt-tab v3.4.2

**Author / maintainer / release owner: zhangqiaoran**

## Click-through fixed

- The switcher remains a borderless `nonactivatingPanel`, but is explicitly mouse-owning and can become Key when the user deliberately clicks it.
- `ignoresMouseEvents` is forced off, first-mouse is accepted, and the root host view has no transparent hit-test holes.
- `SwitcherPanel.sendEvent` resolves ordinary window cards as well as Close, Settings, and permission actions from final host-space geometry.
- The session-wide outside-click monitor remains geometry-gated, so only clicks truly outside every visible switcher cancel the session.
- Result: clicking my-alt-tab no longer activates or clicks the real application window underneath.

## Liquid Glass corrected

- macOS 26+ uses native `NSGlassEffectView.Style.clear`.
- Glass is a **background-only sibling** below the switcher chrome; previews, labels, buttons, and selection visuals are not children of the Glass view.
- Native Glass uses no white tint and no manual CALayer border.
- At 100% transparency the Glass background surface is approximately **0.48 alpha** with zero additional milk.
- Lower percentages progressively restore Glass surface strength and add a separate perceptual milk layer.
- Foreground content and hit targets remain at full opacity at every slider value.

## Existing behavior retained

- 96-state deterministic grayscale+alpha erosion.
- Immediate real AX window close with short-lived visual ghost.
- 80% dust-first hand-off into synchronized Stable-ID FLIP reflow.
- Reduce Motion support.
- Universal 2 (arm64 + x86_64).
- Sparkle EdDSA update verification.
- Minimum macOS: 14.0.
- Bundle ID: `com.zhangqiaoran.myalttab`.
- Marketing version: **3.4.2**.
- Internal build: **30603**.
