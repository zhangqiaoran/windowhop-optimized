# Changelog

All my-alt-tab releases from v1.0.0 onward are authored, maintained, and published by **zhangqiaoran**.

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
