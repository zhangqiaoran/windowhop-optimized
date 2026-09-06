# my-alt-tab v3.3.0

**Author / maintainer / release owner: zhangqiaoran**

## Clear Glass, not white frosted plastic

v3.3.0 changes the appearance model after comparing the 3.2 UI against the desired
transparent-glass reference.

- **100% transparency = 0 added white/neutral density.**
- Lower slider values linearly add only a restrained content-zone density.
- The maximum added density is capped at **20%**, even at 0%.
- macOS 26+ continues to use native `NSGlassEffectView.Style.clear`.
- No global glass tint is applied.
- The thin glass rim and the fixed 2 pt system-blue selection outline remain.
- Preview pixels, icons, titles, and labels are never alpha-faded by the glass slider.

The result is meant to read as a refractive transparent pane over the desktop rather
than an opaque milky panel.

## Why the old thumbnail did not really disappear

3.2 intentionally kept a closing tile in the list until dust reached 80%, so the
switcher would not shrink too early. The particle effect rendered a captured snapshot
above that tile.

That created a visual bug: when the snapshot mask became transparent, the **unchanged
original tile was still directly underneath it**. The user therefore saw particles,
but the thumbnail itself appeared intact.

3.3 fixes the source of that illusion.

1. Capture the tile into a one-shot snapshot.
2. Keep the tile's layout slot reserved.
3. Hide the pooled source tile visually and from accessibility.
4. Animate only the snapshot.
5. When the snapshot mask removes pixels, the clear glass behind the card is actually exposed.
6. At the existing 80% hand-off, remove the ghost slot and start list reflow.

Store-driven panel rebuilds preserve the hidden-ghost state until the closing ID leaves
the session, so a WindowServer notification cannot accidentally make the original tile
visible again during the dissolve.

## True fragment erosion

The old moving gradient mask is replaced by a cached fragment-mask atlas.

- **36 mask frames** per erosion direction.
- **112 × 70** normalized mask resolution.
- Fine deterministic noise creates small holes and frayed edges.
- Coarse deterministic noise creates larger chunks and temporary islands.
- A directional threshold advances across the image.
- A narrow feather keeps the edge organic rather than blocky.
- The first frame is fully opaque; the final frame is fully transparent.
- Core Animation swaps the cached mask frames; there is no per-frame CPU image processing.
- The atlas is lazy and reusable between closes.

This means the card image itself visibly develops holes and broken regions until nothing remains.

## Dust follows the disappearing image

The particle system remains GPU/compositor driven, but its source geometry changes.

Instead of a full-card rectangle emitting dust everywhere:

- the emitter is a **narrow vertical strip**;
- the strip moves across the card with the erosion front;
- micro dust, normal dust, subtle blue glints, and low-alpha haze originate close to
  the currently disappearing pixels;
- particle lifetime continues beyond emission, preserving the drifting tail.

The nominal combined birth rate is about **640 particles/second** over a **0.74 second**
emission phase, while only four `CAEmitterCell` definitions are maintained.

## Timing retained

- Actual AX window close: immediate.
- True image erosion: begins immediately.
- Panel/list geometry: frozen.
- Reflow hand-off: **80% of 1.02 s = about 0.816 s**.
- Smooth list/panel reflow: **0.42 s**.
- Dust/haze tail: continues independently.
- Reduce Motion skips the visual delay.

## Performance

- No display link.
- No per-frame CPU particle simulation.
- No runtime random-number generator.
- No Core Image filter chain.
- Fragment masks are deterministic and cached.
- Particle motion is handled by `CAEmitterLayer` / Core Animation.
- Existing O(1) selection updates are preserved.

## Signing and updates

3.3.0 remains an ad-hoc signed community release. Sparkle verifies the update archive
with the project's EdDSA key. Accessibility / Screen Recording may need to be granted
again after replacing an ad-hoc build.

## Build

- Marketing version: **3.3.0**
- Internal build: **30300**
- Minimum macOS: **14.0**
- Architectures: **arm64 + x86_64 (Universal 2)**
- Bundle ID: `com.zhangqiaoran.myalttab`
