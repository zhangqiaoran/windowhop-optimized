# my-alt-tab v3.4.6

**Author / maintainer / release owner: zhangqiaoran**

## Pin + Search

- Hover the switcher to reveal **Pin** at the top-left, **Search** in the top center, and **…** at the top-right.
- All three controls are hidden by default in both cycling and persistent modes.
- Clicking Pin converts the current held session into persistent mode immediately. Releasing Alt/Option after pinning does not dismiss or activate the selection.
- Search filters by **application name + window title** while preserving the original MRU/session order.
- Search supports case-insensitive, width-insensitive and diacritic-insensitive matching.
- While editing Search, normal typing is handed to AppKit instead of the global event tap. The configured Alt/Tab switcher chord remains intercepted so the native macOS app switcher cannot leak through.
- Zero search matches keep the pinned search session alive and show a quiet empty-result state.

## Truly synchronized thumbnail reflow

- v3.4.5 still drove the outer NSWindow through WindowServer while layer-backed thumbnail views moved through Core Animation. Matching duration/easing did not guarantee the same render clock.
- v3.4.6 keeps the **real NSWindow stationary during reflow**.
- Glass, foreground chrome, ScrollView, NSClipView bounds, document view, surviving thumbnail layers, selection ring, Pin/Search/… and permission controls move inside one layer-backed compositor coordinate space.
- At the end of the transaction the real NSWindow frame is committed and direct host children are normalized back to local coordinates without moving their screen-space pixels.
- If the outer panel does not need to resize, it stays still and only surviving thumbnail layers glide to their new positions.

## Stable-ID physical view reuse

- A/B/C/D no longer use index-based view rebinding during removals.
- Removing A keeps B on the original B NSView/CALayer, C on C, and D on D.
- Unchanged tiles already have a render signature, so their icon/text/preview state is not regenerated before motion.
- This reduces main-thread work immediately before the first reflow frame and removes a major source of perceived hitching with many windows.

## Low-overhead search + session work

- Searchable app/title strings are pre-normalized only when the session source list changes.
- Query normalization occurs once per text edit.
- The hot search path is an array-aligned linear scan with contiguous session order and no per-frame work.
- Newly appeared windows are captured only when they are visible under the active search query.
- AX/store notifications remain coalesced to one main-run-loop refresh.
- No display link, polling loop, high-frequency search timer, or idle animation loop was introduced.

## Retained fixes

- External/extended-display preview geometry and target backing-scale capture from v3.4.5.
- Fast deterministic 1↔2 Alt/Option+Tab switching from v3.4.4.
- Canonical neon app icon.
- Native macOS 26 Clear Glass.
- 96-state particle dissolve close.
- English / 中文 Settings.
- Universal 2: Apple Silicon + Intel.
- Sparkle EdDSA update verification.
- Minimum macOS: 14.0.
- Marketing version: **3.4.6**.
- Internal build: **30609**.
