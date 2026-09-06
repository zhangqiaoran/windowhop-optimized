# my-alt-tab v3.4.4

**Author / maintainer / release owner: zhangqiaoran**

## Rapid Alt / Option + Tab switching fixed

- Fixed an input race that could make very fast 1↔2 window toggling occasionally do nothing.
- The event tap now leaves the held session synchronously when Alt/Option is released instead of waiting for the main thread to process the semantic release.
- A second Alt/Option+Tab pressed immediately after release is therefore a fresh trigger, not a stale step belonging to the previous session.
- The controller no longer rewrites the event tap's held/sticky state while showing the panel, so delayed UI work cannot overwrite a newer physical shortcut sequence.
- The committed target window is promoted to MRU immediately before asynchronous AX focus confirmation, keeping repeated rapid toggles deterministic.
- Regression tests reproduce a second chord arriving before the previous release has been handled on main.

## New app icon and visual GitHub introduction

- v3.4.4 now ships the new neon stacked-window **my-alt-tab app icon** as the canonical application icon.
- The same committed source image drives the packaged `.icns`, README icon, and documentation favicon so product branding cannot drift between builds and GitHub.
- GitHub README is now image-first instead of release-note-first: the icon, animated switcher demo, three-step installation flow, and compact feature overview appear before detailed version history.
- Added an animated README demo that emphasizes **lightweight operation, rapid 1↔2 switching, particle-dissolve closing, and smooth list reflow**.

## Retained from v3.4.3

- English / 中文 live Settings localization.
- Retired Show tab counts preference.
- Click-through and panel mouse-ownership fixes.
- Native macOS 26 Clear Liquid Glass with background-only material.
- 96-state dissolve and Stable-ID FLIP reflow.
- Reduce Motion support.
- Universal 2: arm64 + x86_64.
- Sparkle EdDSA update verification.
- Minimum macOS: 14.0.
- Bundle ID: `com.zhangqiaoran.myalttab`.
- Marketing version: **3.4.4**.
- Internal build: **30607**.
