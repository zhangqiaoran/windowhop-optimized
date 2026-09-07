# Changelog

All my-alt-tab releases from v1.0.0 onward are authored, maintained, and published by **zhangqiaoran**.

## 3.4.7 — 2026-09-07 — zhangqiaoran

- Removed outer-panel shake caused by redundant AX/WindowStore refreshes interrupting an in-flight structural FLIP. Same stable-ID order now uses a geometry-free content refresh.
- Split search filtering from structural window-list layout. Search changes only thumbnail/lens layers inside the existing viewport and never changes NSWindow, Glass, chrome, ScrollView, or search-field geometry.
- Fixed zero-result search so the existing panel remains stable, all tiles are hidden, the selection lens disappears, and one centered empty state is shown.
- Pre-arms search editing on mouseDown and keeps EventTap in search mode before subsequent keyboard events, ensuring Backspace and Forward Delete remain normal field-editor commands.
- Added a separate search reflow generation so query edits cannot cancel/commit structural close motion.
- Removed redundant per-query temporary ID arrays, availability sets, selection announcements and UI work when the stable result order is unchanged.
- Added regression coverage for search geometry lock, empty search, delete routing, and content-only refreshes during active structural reflow.
- Internal build: **30610**.

Full notes: [`RELEASE_NOTES_v3.4.7.md`](RELEASE_NOTES_v3.4.7.md).

## 3.4.6 — 2026-09-07 — zhangqiaoran

- Added a hover-only **Pin** control that converts the active held session to sticky/persistent mode without rebuilding the grid; modifier release becomes inert immediately.
- Added a hover-only **window search field** filtering app name + title while preserving session order. Search editing temporarily yields ordinary keyboard input to AppKit while still owning the configured Alt/Tab trigger chord.
- Pin, Search and More Options now share one contextual visibility rule: hidden by default, shown on switcher hover, with search kept visible while its field editor is active.
- Re-architected shrink/reflow around one stationary NSWindow compositor space: Glass, chrome, scroll/document geometry, stable thumbnail layers, focus ring and global controls animate on one Core Animation clock, then the real window frame is atomically committed.
- Added the missing clip-view bounds animation/commit, eliminating multi-row scroll geometry jumps.
- Preserved physical SwitcherTileView/CALayer identity by stable window ID across removals so trailing cards move existing layers instead of rebinding every card before FLIP.
- Added a pre-normalized, array-aligned search index. No idle polling/display link was introduced; the query is normalized once per edit and the hot path is linear in the visible session list.
- Kept the v3.4.5 placement-display preview aspect, target backing-scale capture sizing and 1x external-display fixes.
- Added regression coverage for pinning, zero-result search, search-mode event interception, normalized matching, hover-only chrome, stable tile identity and synchronized stationary-window reflow.
- Internal build: **30609**.

Full notes: [`RELEASE_NOTES_v3.4.6.md`](RELEASE_NOTES_v3.4.6.md).

## 3.4.5 — 2026-09-07 — zhangqiaoran

- Fixed Window Preview geometry on external/extended displays by deriving tile aspect ratio from the panel's actual placement screen instead of `NSScreen.main`.
- Capture sizing now follows the live target display set, including mixed backing scales and 1x external monitors.
- Removed the hard-coded 2x Retina assumption from captured `NSImage` sizing so 1x displays no longer upscale correctly captured thumbnails.
- Refined Stable-ID list reflow to a 0.52 s non-bouncy ease-out so surviving thumbnails visibly glide forward instead of appearing to jump.
- Made reflow completions generation-safe: any newer layout invalidates older completion handlers, preventing interrupted/repeated removals from snapping geometry back to stale targets.
- Added regression coverage for explicit ultrawide preview aspect, 1x target capture geometry, and the smoother reflow cadence.
- Retains v3.4.4's rapid Alt/Option+Tab race fix, canonical neon icon, bilingual Settings, Clear Glass, 96-state particle dissolve, Universal 2 packaging, and Sparkle verification.
- Internal build: **30608**.

Full notes: [`RELEASE_NOTES_v3.4.5.md`](RELEASE_NOTES_v3.4.5.md).

## 3.4.4 — 2026-09-06 — zhangqiaoran

- Adopted the new **canonical neon stacked-window app icon** for v3.4.4 packaged builds; the README icon, favicon, and generated macOS `.icns` now share one committed source image.
- Reworked the GitHub README into an image-first introduction with an animated lightweight / rapid-switch / particle-dissolve demo and concise three-step installation guide.
- Fixed the rapid Alt/Option+Tab **release/repress race**: modifier release returns the event tap to watching synchronously, before the semantic release reaches the main thread.
- Removed the controller's redundant show-time tap-mode rewrite so delayed UI work cannot overwrite a newer physical shortcut sequence.
- Promoted committed activation targets into MRU order immediately before asynchronous AX focus confirmation, making repeated 1↔2 toggling deterministic.
- Added regression coverage for a second Alt/Option+Tab arriving before the previous release has been processed on main.
- Retains v3.4.3's bilingual Settings, retired tab-count preference, click ownership, Clear Liquid Glass, dissolve, and Stable-ID FLIP fixes.
- Internal build: **30607**.

Full notes: [`RELEASE_NOTES_v3.4.4.md`](RELEASE_NOTES_v3.4.4.md).

## 3.4.3 — 2026-09-06 — zhangqiaoran

- Fixed the rapid Alt/Option+Tab **release/repress race**: the event tap now returns to watching synchronously on modifier release, before the semantic event reaches main.
- Removed the controller's redundant show-time tap-mode rewrite so delayed main-thread work cannot overwrite a newer physical shortcut sequence.
- Committed activation targets are promoted into MRU order immediately before asynchronous AX focus confirmation, eliminating stale-order failures during repeated 1↔2 toggling.
- Added a persisted **Settings language** preference with explicit **English / 中文** choices and immediate runtime switching.
- Localized every Settings pane toolbar title plus General, Shortcuts, Windows, Appearance, Updates, About, permission status, update status, shortcut-recorder labels, and validation copy.
- The toolbar and current Settings window title relabel in place when the language changes; no restart is required.
- Retired the low-value **Show tab counts** preference. Existing stored values are ignored, the setting row is removed, and tab-count metadata remains disabled.
- Corrected the Liquid Glass explanatory copy in Appearance so it describes the actual v3.4.2 background-only Clear Glass architecture rather than the superseded contentView/Regular Glass model.
- Added deterministic localization/persistence tests and kept the existing click-through, root routing, clear-glass, dissolve, and reflow regression coverage.
- Internal build: **30605**.

Full notes: [`RELEASE_NOTES_v3.4.3.md`](RELEASE_NOTES_v3.4.3.md).

## 3.4.2 — 2026-09-06 — zhangqiaoran

- Restored the interaction-safe switcher topology: native Glass is background-only while all cards and controls are ordinary foreground siblings.
- Made the borderless nonactivating panel explicitly mouse-owning and key-capable on deliberate clicks, preventing pointer events from falling through to the underlying application window.
- Extended root-level pointer routing to ordinary window cards in addition to Close, Settings, and preview-permission actions.
- Returned macOS 26+ to native **Clear Liquid Glass** with no tint and no manual native border.
- Restored literal transparency by varying only the background Glass surface alpha (about 48% at 100%) plus a separate perceptual milk layer; foreground content never fades.
- Preserved the 96-state erosion atlas, immediate AX close, 80% visual hand-off, synchronized Stable-ID FLIP reflow, Universal 2 packaging, and Sparkle EdDSA verification.
- Internal build: **30603**.

Full notes: [`RELEASE_NOTES_v3.4.2.md`](RELEASE_NOTES_v3.4.2.md).

## 3.4.0 — 2026-09-06 — zhangqiaoran

- Re-architected Liquid Glass into three independent visual layers: a material-only native glass background, a separate perceptual milky-density layer, and fully opaque foreground chrome. Changing glass strength can no longer fade thumbnails, labels, controls, or the blue focus ring.
- Defined the slider as a real **liquid ↔ milky continuum**: 100% uses zero milk and thins the native Clear Glass surface to about 60% alpha so wallpaper color reads through strongly; lower values progressively restore the glass surface and add milk using a perceptual `(1-liquid)^1.55` curve, reaching a translucent 72% milk layer at 0%.
- Verified the official Release compiler is Swift 6.3.3 targeting macOS 26, so the native `NSGlassEffectView.Style.clear` path is compiled into the shipped app.
- Rebuilt close-list resizing with **Stable-ID FLIP** in one `NSAnimationContext`: NSWindow frame, glass material, foreground chrome, scroll/document geometry, surviving tiles, controls, and the blue focus ring now share one animation clock and one timing curve.
- Removed the old independent Core Animation position reflow and the selected-tile 1.018× scale animation that could combine with NSWindow live resize and look like a small hitch or dropped frame.
- Reflow interruption starts from presentation-layer geometry by stable window ID, preserving smooth repeated closes.
- Preserved 3.3's true 36-frame thumbnail erosion, moving dust front, 80% dust-before-reflow hand-off, Universal 2 packaging, and Sparkle EdDSA updates.

Full notes: [`RELEASE_NOTES_v3.4.0.md`](RELEASE_NOTES_v3.4.0.md).

## 3.3.0 — 2026-09-06 — zhangqiaoran

- Returned the switcher to literal **Clear Glass** semantics. At 100% transparency, the panel adds **zero** neutral/white density; lower settings add only a restrained linear density capped at 20%, so the desktop remains visibly refracted instead of becoming a white slab.
- Kept macOS 26+ on native `NSGlassEffectView.Style.clear` with no tint while preserving the 2 pt fixed system-blue selection ring.
- Fixed the core reason the previous close effect looked like "particles over an unchanged thumbnail": the pooled source tile now becomes visually hidden after its snapshot is captured, while keeping its layout slot until the existing 80% hand-off.
- Replaced the old soft sweep with a cached **36-frame deterministic fragment-mask atlas**. Fine/coarse noise thresholds create holes, islands, and an irregular erosion front that actually removes snapshot pixels.
- Moved the `CAEmitterLayer` from a full-card emitter to a narrow moving strip that tracks the erosion front, so dust is emitted from the image regions that are disappearing.
- The fragment masks are low-resolution, deterministic, lazily cached, and composited by Core Animation; no display link, per-frame CPU image processing, or runtime random generator is used.
- Preserved the 80% dust-before-reflow choreography, 0.42 s synchronized list shrink, Universal 2 packaging, and Sparkle EdDSA updates.

Full notes: [`RELEASE_NOTES_v3.3.0.md`](RELEASE_NOTES_v3.3.0.md).

## 3.2.0 — 2026-09-06 — zhangqiaoran

- Made the reserved top chrome genuinely transparent on macOS 26+: the outer panel uses clear native glass with no white tint, while the adjustable frosted-density layer is localized to the window-content zone and fades out before the ellipsis row.
- Simplified selection to one transparent moving focus ring: no selected-tile fill and no second glass material. The selected window now gets a crisp **2 pt fixed system-blue outline** with a restrained blue glow, keeping preview pixels unobscured.
- Changed close choreography to a two-phase hand-off: the real window closes immediately, but the switcher card remains frozen as a visual ghost until the dust animation reaches **80%** of its 1.02 s lifetime (about 0.816 s).
- Only after the 80% hand-off does the card disappear from the session list and the existing synchronized **0.42 s** panel/tile reflow begin, keeping the dense GPU dust effect fully visible instead of shrinking it away immediately.
- Store refreshes explicitly preserve pending visual ghosts during the dust phase, and activation skips already-closed ghosts so rapid modifier release cannot target a dead window.
- Reduce Motion skips the visual delay and keeps the accessibility path immediate.
- Remains an ad-hoc signed community build with Sparkle EdDSA update verification; macOS Accessibility / Screen Recording may need re-authorization after an update.

Full notes: [`RELEASE_NOTES_v3.2.0.md`](RELEASE_NOTES_v3.2.0.md).

## 3.1.0 — 2026-09-06 — zhangqiaoran

- Recalibrated the switcher glass toward Control Center-style **Frosted Glass**: macOS 26+ uses native `NSGlassEffectView.Style.regular`, with a persistent milky blur body even at 100% transparency.
- Replaced mixed AppKit-resize + spring motion with one synchronized, non-overshooting cubic timing curve for the panel, surviving tiles, and selection lens, removing the hitch that could look like dropped frames during shrink.
- Rebuilt close dissolution around a compositor-owned `CAEmitterLayer`: roughly 300–400 micro-particles, soft haze, directional erosion, and a traveling highlight edge now create a denser drifting dust effect based on the supplied reference video.
- Kept animation work event-driven and GPU-oriented: no display link or per-frame CPU loop.
- Prepared official releases for one stable Developer ID Application identity, Hardened Runtime, Apple notarization, and stapling so macOS TCC permissions can remain stable across future signed updates.
- Existing ad-hoc builds may still require one final permission re-authorization when first migrating to the Developer ID-signed release.

Full notes: [`RELEASE_NOTES_v3.1.0.md`](RELEASE_NOTES_v3.1.0.md).

## 3.0.0 — 2026-09-06 — zhangqiaoran

- Rebuilt close motion into a 56-particle deterministic dusting engine using R2 low-discrepancy surface coverage, a gradient erosion front, and cubic inward/upward wind paths.
- Replaced rigid window-list shrink with stable-ID reflow: surviving windows animate from their current Core Animation presentation positions while the centered panel resizes with native AppKit motion.
- Repeated fast closes are interruptible and start from what is actually rendered on screen rather than stale model geometry.
- Added a silent signed Sparkle version probe whenever Settings → Updates opens, plus a prominent **Update Now…** path into Sparkle's verified installer.
- Preserved signed automatic updates, clear Liquid Glass transparency, Universal 2 support, MRU switching, and clip-safe selection.
- Removed obsolete layout tokens left from earlier Settings/chrome iterations.
- Motion remains event-driven: no display link, repeating particle timer, or idle animation loop was introduced; Reduce Motion is honored.

Full notes: [`RELEASE_NOTES_v3.0.0.md`](RELEASE_NOTES_v3.0.0.md).

## 2.4.0 — 2026-09-06 — zhangqiaoran

- Rebuilt Liquid Glass transparency around a literal 0–100 contract: higher values are genuinely more transparent.
- macOS 26+ now uses the native clear `NSGlassEffectView.Style.clear` for the panel and selected-window focus surface.
- Replaced the previous tint-only approximation with a dedicated background-density layer, so changing transparency affects the glass background without fading window previews, icons, labels, or controls.
- 100% adds no density, 90% adds 10%, 50% adds 50%, and 0% applies the maximum configured density.
- The selected window follows the same Liquid Glass level while retaining a restrained native accent tint, soft glow, and clip-safe right/bottom overflow.
- Preserved signed Sparkle updates, Universal 2 packaging, fast MRU switching, immediate window close, and the fixed-cost dismissal animation.

Full notes: [`RELEASE_NOTES_v2.4.0.md`](RELEASE_NOTES_v2.4.0.md).

## 2.3.1 — 2026-09-06 — zhangqiaoran

- Renamed the appearance control to **Liquid Glass** and aligned its behavior with that visual model.
- Replaced the linear transparency mapping with a perceptual density curve: 100% remains maximally clear while 90% is now visibly denser instead of nearly indistinguishable.
- On macOS 26+, the selected-window focus surface now uses its own native `NSGlassEffectView`, producing a layered Liquid Glass selection instead of a flat translucent highlight.
- Older macOS versions retain the closest native `NSVisualEffectView` fallback.
- Increased selection visual overflow to preserve the stronger Liquid Glass glow without reintroducing right/bottom clipping.
- Preserved the signed Sparkle update channel, automatic update checks, Universal 2 packaging, and all existing switcher behavior.

Full notes: [`RELEASE_NOTES_v2.3.1.md`](RELEASE_NOTES_v2.3.1.md).

## 2.3.0 — 2026-09-06 — zhangqiaoran

- Refreshed the public 2.3.0 package as build 20301 to make the signed update newer than the original 20300 build.
- Enabled signed Sparkle updates from the my-alt-tab GitHub release channel; automatic checks and automatic updates default to On.
- Added a persisted 0–100% Glass transparency control with immediate runtime updates in the Appearance pane.
- Refined the About interface and completed user-facing my-alt-tab branding across the project metadata.
- Patch: fixed the selected Glass Focus plate being clipped on the right/bottom document edges.
- Added dedicated right/bottom comfort spacing and a top chrome strip so the ellipsis no longer overlaps previews.
- Closing a window now removes it from the open switcher immediately instead of waiting for the AX destroy notification.
- Increased the close dissolve to a fixed 28-particle deterministic surface distribution with a shorter 0.29s animation.
- Preserved shared glass focus, fast two-window MRU switching, event-driven idle behavior, and Universal 2 packaging.

Full notes: [`RELEASE_NOTES_v2.3.0.md`](RELEASE_NOTES_v2.3.0.md).

## 2.2.0 — 2026-09-06 — zhangqiaoran

- Increased panel breathing room so the rightmost preview no longer crowds the edge.
- Replaced the top-right gear with a compact ellipsis action fully inset inside the panel.
- Upgraded window-close dissolution to a richer 18-particle two-wave effect with fixed O(1) cost.
- Preserved shared glass focus, fast two-window MRU switching, and event-driven idle behavior.

Full notes: [`RELEASE_NOTES_v2.2.0.md`](RELEASE_NOTES_v2.2.0.md).

## 2.1.1 — 2026-09-06 — zhangqiaoran

- Fixed local packaging on Macs that do not have the full Xcode/XCBuild stack.
- `./scripts/package-app.sh` now auto-detects Swift Build support and falls back to the current CPU architecture when needed.
- Official GitHub releases continue to require and verify Universal 2 (arm64 + x86_64).

## 2.1.0 — 2026-09-06 — zhangqiaoran

- Added more bottom breathing room for wrapped preview rows.
- Reworked the shared selection lens into one translucent native visual-effect surface.
- Added a fixed-size, one-shot particle dismissal effect for window close.
- Locked in the two-window MRU toggle invariant with regression tests.
- Packaging targets one Universal 2 `my-alt-tab.app` for Intel + Apple Silicon.

Full notes: [`RELEASE_NOTES_v2.1.0.md`](RELEASE_NOTES_v2.1.0.md).

## 2.0.0 — 2026-09-06 — zhangqiaoran

### Glass Focus Engine

- One shared native glass/visual-effect surface replaces per-thumbnail blur as the product rule.
- Added a single shared Focus Lens with semantic system focus color.
- Selected thumbnails receive a subtle 2.2% optical lift without changing layout geometry.
- Added O(1) distance-adaptive selection motion; rapid input retargets the current compositor animation.
- Reduce Motion disables focus motion automatically.

### Performance

- Selection target geometry is cached during layout and retrieved by index in O(1).
- Normal selection still updates only the old and new tile.
- The number of animated selection surfaces stays constant regardless of window count.
- Existing PID bucketing, dense preview matching, O(n) zero-sort refresh planning, capture deduplication, bounded preview memory, and EventTap bitset hot paths remain intact.

Full notes: [`RELEASE_NOTES_v2.0.0.md`](RELEASE_NOTES_v2.0.0.md).

## 1.1.0 — 2026-09-06 — zhangqiaoran

### Performance

- Selection traversal now updates only the previous and next selected tile instead of repainting the whole visible list.
- Preview matching keeps PID bucketing and a flat score matrix, and replaces per-round `Set`/winner dictionaries with dense active masks and winner arrays.
- Preview refresh planning can return request indices directly, eliminating a temporary ID-to-request dictionary.
- Preview capture tracks session in-flight IDs to suppress duplicate ScreenCaptureKit work during rapid AX/window-store updates.
- EventTap key-up suppression uses a compact 128-bit bitset for normal macOS keycodes, with a Set fallback only for unusual synthetic keycodes.
- Session reconciliation uses pre-sized, single-pass hash collections in high-churn multi-window applications.
- Hidden pooled tiles and expanded previews release heavy transient images immediately; the bounded preview cache is the sole between-session owner.

### Lightweight UI

- Compact panel, tile spacing, icon, badge, and preview dimensions.
- Removed per-preview drop shadows.
- Loading skeleton is static instead of running a perpetual animation.
- Selection and hover state no longer force geometry layout.
- Shorter preview refresh transitions.
- Visible close control is smaller while retaining a 44×44 hit target.

### Existing v1.0 behavior retained

- Pointer-display-only switcher with all-display window candidates.
- Left / center / right thumbnail-row alignment.
- Direct window close without the legacy close-vs-quit confirmation.
- Finder closes only the selected Finder window.
- Bounded in-memory preview caching, freshness-aware refresh, and EventTap recovery.

Full notes: [`RELEASE_NOTES_v1.1.0.md`](RELEASE_NOTES_v1.1.0.md).

## 1.0.0 — 2026-09-06 — zhangqiaoran

- Established the my-alt-tab release line under zhangqiaoran.
- Added focused multi-display placement: one switcher on the pointer display while listing eligible windows from every display.
- Added Left / Center / Right thumbnail-row alignment.
- Simplified close behavior to close the selected window directly.
- Added bounded/freshness-aware preview caching and stronger EventTap recovery.
- Established bundle ID `com.zhangqiaoran.myalttab` and disconnected the inherited automatic-update channel.

Full notes: [`RELEASE_NOTES_v1.0.0.md`](RELEASE_NOTES_v1.0.0.md).

## Earlier history

Inherited GPL source history and attribution are intentionally kept outside the current zhangqiaoran release changelog. See [`UPSTREAM.md`](UPSTREAM.md) and [`LICENSE`](LICENSE).
