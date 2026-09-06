# my-alt-tab v3.0.0

**Author / maintainer / release owner: zhangqiaoran**

## Why 3.0

3.0 is a motion-and-responsiveness architecture release. The switcher still keeps the
same lightweight AppKit core, signed Sparkle updates, and zero-telemetry policy, but
window removal, panel resizing, close feedback, and the Updates pane have been rebuilt
to feel substantially more fluid without introducing permanent background work.

## Fluid window-list reflow

- Closing a window no longer makes every remaining tile snap instantly into its new slot.
- Surviving entries are matched by **stable window ID** in one O(n) pass.
- Their next animation begins from the **Core Animation presentation layer** — the exact
  position currently visible on screen — so repeated fast closes can interrupt an
  in-flight spring cleanly instead of jumping back to stale geometry.
- Moving cards use a bounded `CASpringAnimation`.
- The centered switcher panel resizes with native AppKit window-frame animation.
- Newly appearing windows remain immediate so they are reachable without waiting for motion.
- macOS **Reduce Motion** disables the reflow animation.

## Dusting close engine

The old 28-particle, 0.29-second burst has been replaced with a softer one-shot
disintegration designed to read as the window surface turning into drifting dust.

- **56 fixed particles**, bounded at compile time.
- **R2 low-discrepancy sampling** based on the plastic constant spreads origins across the
  full card surface with less clumping than ordinary pseudo-random placement.
- A moving **gradient erosion mask** removes the snapshot progressively instead of fading
  the entire rectangle at once.
- Dust follows **cubic Bézier wind paths** with deterministic variation in size, spin,
  launch time, and lateral drift.
- The plume is biased **inward and upward**, which keeps it visible while the centered
  panel simultaneously becomes smaller.
- The whole effect is Core Animation driven after the click: no display link, no repeated
  timer, no random-number generator, and no per-frame CPU loop.
- Particle count stays fixed regardless of the number of open windows.
- Reduce Motion removes the effect immediately.

## Faster, clearer Updates pane

- Opening **Settings → Updates** now calls Sparkle's information-only probe
  (`checkForUpdateInformation()`).
- This reads the signed appcast and updates the pane **without showing a modal
  “You're up to date” dialog**.
- When a newer version exists, the pane exposes a prominent **Update Now…** button.
- Update Now hands control to Sparkle's standard verified update session, which handles
  downloading, EdDSA verification, installation, and relaunch.
- The existing **Automatically check for updates** preference remains available.
- Scheduled background checks and automatic installation remain Sparkle-managed.

## Lightweight cleanup

- Removed obsolete Settings/chrome design tokens that no longer had runtime callers.
- No new runtime dependency was added; Sparkle remains the only runtime dependency.
- No telemetry, analytics, accounts, advertising, or system-profile reporting.

## Existing 2.x behavior retained

- Clear Liquid Glass with literal 0–100% transparency.
- Native selected-window Liquid Glass focus on macOS 26+.
- Universal 2 support for Apple Silicon and Intel.
- Fast MRU switching and keyboard navigation.
- Direct native window close behavior.
- Clip-safe right/bottom selection glow and the dedicated ellipsis chrome.

## Build

- Marketing version: **3.0.0**
- Internal build: **30000**
- Minimum macOS: **14.0**
- Bundle ID: `com.zhangqiaoran.myalttab`
