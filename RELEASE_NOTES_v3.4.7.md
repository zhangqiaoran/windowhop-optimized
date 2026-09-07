# my-alt-tab v3.4.7

**Author / maintainer / release owner: zhangqiaoran**

## Fixed: outer panel shake after thumbnail reflow

The surviving thumbnail layers in 3.4.6 were already moving smoothly, but the surrounding panel could still visibly shake after a close. The remaining cause was not the animation curve.

A real AX window close can emit several follow-up WindowStore changes. Those updates often had the exact same visible stable-ID order, yet the controller still called the full panel layout path. A full update increments the reflow generation and may commit/recenter the NSWindow, which can interrupt the structural compositor transaction already in flight.

v3.4.7 compares the current and next stable-ID order directly:

- Same order → **content-only refresh**.
- Real structural list change → structural FLIP.
- Search filtering → search-only tile reflow.

Content-only refresh does not touch NSWindow, Glass/chrome geometry, clip bounds, selection-lens geometry, or structural animation generation.

## Search no longer resizes the switcher

Search is now a dedicated rendering path instead of pretending matched windows are physically closed windows.

While typing:

- NSWindow frame stays fixed.
- Liquid Glass / chrome stays fixed.
- ScrollView viewport and document canvas stay fixed.
- Pin, Search and … stay fixed.
- Search field stays at the same frame and retains its field editor.
- Only matching stable-ID thumbnail layers pack/reflow inside the existing viewport.

This also removes the compounded parent/child resize motion that produced the compressed-card appearance shown when only a few matches remained.

## Fixed: zero search matches

A zero-result query is now a first-class state:

- Original panel size is retained.
- No tiny fallback panel is calculated.
- Every old thumbnail is hidden.
- Selection lens is hidden.
- One centered **No matching windows** message is shown.
- Editing remains active so Backspace can immediately recover results.

## Fixed: Backspace / Delete in the search field

The search field now pre-arms editing from the panel's mouseDown path before the next key event can reach the global event tap.

During search editing:

- Character input passes to AppKit.
- Backspace passes to AppKit.
- Forward Delete passes to AppKit.
- Arrow/text navigation passes to AppKit.
- The configured Alt/Option+Tab switcher chord remains owned by my-alt-tab so native macOS switching cannot leak through.

Because search no longer moves/resizes the field, the field editor also stays first responder across every result update.

## Lower hot-path cost

- Query result-order comparison is allocation-free; temporary ID arrays were removed.
- Same-result query edits perform no switcher UI update.
- Same-ID AX refreshes avoid all layout work.
- Availability-set calculation is skipped when geometry did not change.
- Search motion and structural panel motion use separate generation tokens.
- No polling loop, display link, high-frequency timer, or per-frame CPU search work was added.
- Stable-ID physical NSView/CALayer reuse from 3.4.6 remains intact.

## Regression coverage

Tests now verify:

- Search filtering does not change outer panel/Glass/grid/search-field geometry.
- Stable-ID tile view identity survives filtering.
- Zero matches retain full panel geometry and hide the selection lens.
- Backspace and Forward Delete are passed through in search mode.
- A same-ID metadata refresh arriving during a structural close reflow cannot interrupt the final NSWindow frame commit.

## Release identity

- Marketing version: **3.4.7**
- Internal build: **30610**
- Minimum macOS: **14.0**
- Package: **Universal 2** (arm64 + x86_64)
- Signing: ad-hoc app / community build
- Updates: Sparkle EdDSA signed archive
