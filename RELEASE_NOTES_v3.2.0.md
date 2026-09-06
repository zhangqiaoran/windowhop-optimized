# my-alt-tab v3.2.0

**Author / maintainer / release owner: zhangqiaoran**

## Transparent chrome

The upper reserved chrome area is now visually separated from the frosted content density.

- macOS 26+ uses native **Clear Glass** for the outer panel.
- No global white tint is applied to that glass.
- The user-controlled milky density layer is limited to the window-content region.
- A vertical mask softly fades the density layer before the ellipsis row.
- The result is a transparent top area that shows the desktop/background instead of a large white slab.

## Blue selection focus

Selection no longer modifies the selected window's interior.

- No selected-tile fill.
- No second selected-window glass material.
- One shared moving focus view draws a **2 pt system-blue outline**.
- A small blue glow adds depth without obscuring preview pixels.
- The blue is fixed to macOS system blue rather than following an arbitrary user Accent Color.
- The focus ring remains O(1): only one moving selection layer exists regardless of window count.

## 80% dust-to-reflow choreography

The close sequence is now deliberately split into two phases.

### Phase 1 — dissolve first

1. The target window receives its real AX close immediately.
2. A snapshot-based GPU dust/erosion effect begins.
3. The switcher keeps the closing card as a temporary visual ghost.
4. Panel size and surviving card geometry remain frozen.
5. WindowStore refreshes are allowed, but the pending ghost is explicitly preserved.

The freeze lasts until **80% of the 1.02 second dust lifetime**, approximately **0.816 seconds**.

### Phase 2 — graceful reflow

At the 80% hand-off:

1. The ghost is removed from the session list.
2. Selection is resolved to a still-live window.
3. The panel and surviving cards start the synchronized **0.42 second** non-overshooting reflow.
4. The final dust/haze tail continues briefly while the list begins to close the gap.

This keeps the dense particle effect visible before layout motion competes for attention.

## Interaction correctness

- Closing the selected window immediately moves focus to a nearby live card without changing layout.
- Releasing the modifier during the dust phase cannot activate the already-closed ghost.
- Repeated close requests on the same ghost are ignored.
- Multiple pending closes retain independent visual completion work items.
- Ending the switcher session cancels any outstanding delayed visual-close work.
- Reduce Motion skips the delay.

## Performance

- The real close action remains on the immediate hot path.
- Dust remains compositor-driven through `CAEmitterLayer`.
- No display link or per-frame CPU particle simulation is introduced.
- The delayed hand-off uses one short-lived `DispatchWorkItem` per pending close and has no idle cost.

## Signing and updates

This 3.2.0 community release remains **ad-hoc signed** because no Apple Developer
Developer ID certificate is configured. Sparkle still verifies update archives with the
project's EdDSA key. Accessibility / Screen Recording may need to be authorized again
after an ad-hoc update.

## Build

- Marketing version: **3.2.0**
- Internal build: **30200**
- Minimum macOS: **14.0**
- Architectures: **arm64 + x86_64 (Universal 2)**
- Bundle ID: `com.zhangqiaoran.myalttab`
