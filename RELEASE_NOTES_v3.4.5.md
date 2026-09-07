# my-alt-tab v3.4.5

**Author / maintainer / release owner: zhangqiaoran**

## External / extended display previews fixed

- Window Preview cards now use the aspect ratio of the display where the switcher panel is actually shown.
- The previous fallback to the primary display could give ultrawide or differently-shaped external monitors the wrong preview canvas geometry.
- Preview capture targets now follow the live target display set instead of a primary-screen assumption.
- Mixed display backing scales are respected; a 1x external monitor no longer inherits a hard-coded Retina interpretation.
- ScreenCaptureKit snapshots now keep pixel-native `NSImage` dimensions instead of always dividing width and height by 2.

## Smoother thumbnail reflow

- When a thumbnail disappears, surviving cards now move forward with a **0.52 s non-bouncy ease-out** rather than an abrupt-looking shift.
- Stable-ID FLIP still starts from current presentation-layer geometry, so movement begins from the pixels actually on screen.
- Reflow transactions now carry a generation token. If another layout update starts before an older animation completes, the old completion is ignored instead of snapping the window/cards back to a stale target.
- Reduce Motion continues to bypass animated reflow.

## Regression coverage

- Explicit ultrawide placement-display preview aspect.
- 1x external-display capture target sizing.
- Smooth reflow duration contract.
- Existing click ownership, Liquid Glass, particle dissolve, rapid Alt/Option+Tab, bilingual Settings and update tests remain intact.

## Retained

- Canonical neon my-alt-tab app icon.
- Native macOS 26 Clear Glass background.
- Fast deterministic 1↔2 Alt/Option+Tab switching.
- 96-state particle dissolve close animation.
- English / 中文 Settings.
- Universal 2: Apple Silicon + Intel.
- Sparkle EdDSA update verification.
- Minimum macOS: 14.0.
- Marketing version: **3.4.5**.
- Internal build: **30608**.
