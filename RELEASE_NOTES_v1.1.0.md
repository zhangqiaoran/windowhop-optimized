# WindowHop v1.1.0

**Author / maintainer / release owner: zhangqiaoran**
Release date: 2026-09-06

v1.1.0 is the first performance-and-UI optimization release after the frozen v1.0.0 baseline. It does not add a heavy framework or a background monitor. The goal is lower work per keystroke, less repeated capture, bounded memory, and a cleaner compact switcher.

## Performance changes

### O(1) selection repaint

Normal Tab/arrow traversal now updates only the old selected tile and the new selected tile. A full O(n) selection pass is reserved for an actual item-list rebuild.

### Dense preview-matching core

Preview matching keeps PID bucketing and the ambiguity-safe mutual-best rule, while replacing per-round Set/Dictionary bookkeeping with dense Boolean masks and winner arrays over a flat score matrix. This reduces allocation and hashing in apps with many same-process windows.

### Duplicate capture suppression

The preview session tracks IDs already in flight. Repeated AX notifications or window-store refreshes cannot schedule another ScreenCaptureKit capture for the same window until the current request completes.

### Direct index refresh planning

The O(n) preview refresh planner returns request indices directly, avoiding a temporary ID→request dictionary and second lookup pass.

### EventTap bitset

Suppressed key-up state for normal macOS keycodes is stored in two UInt64 values. The common event path therefore avoids Set hashing/allocation; an overflow Set exists only for unusual synthetic keycodes.

### Memory ownership cleanup

- Existing ~64 MiB cost-bounded preview cache remains the between-session thumbnail owner.
- Hidden pooled tiles release their transient preview images.
- Expanded dwell previews release the large image immediately when hidden.
- Expanded previews are not inserted into the ordinary tile cache.

## Lightweight UI

- More compact panel padding and tile gaps.
- Smaller tile/icon/preview dimensions while preserving readability.
- Static loading placeholder; the old perpetual skeleton animation is gone.
- Preview shadows removed to reduce compositor work.
- Hover/selection repaint no longer asks Auto Layout for a geometry pass.
- Shorter preview fade timings.
- Close button keeps an accessible 44×44 target with lighter visible chrome.

## Multi-display behavior

The v1.0 multi-display model remains unchanged: the switcher is shown only on the display containing the pointer, while the candidate list includes eligible windows from all displays. There is still no continuous mouse tracking or idle polling.

## Window closing

Close button and Delete/Backspace close the selected window immediately. Finder closes only the selected Finder window. WindowHop itself does not add a second close-vs-quit prompt; target applications can still show their own unsaved-document confirmation.

## Identity

- Version: **1.1.0**
- Build: **10100**
- Bundle ID: `com.zhangqiaoran.myalttab`
- Author / maintainer / release owner: **zhangqiaoran**
- License: GNU GPL-3.0

Inherited GPL attribution remains in `UPSTREAM.md` and `LICENSE`.
