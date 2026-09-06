# my-alt-tab v2.3.0

**Author / maintainer / release owner: zhangqiaoran**

## Install

1. Download `my-alt-tab-2.3.0.zip`.
2. Unzip to get `my-alt-tab.app`.
3. Drag it into `/Applications`.
4. Grant Accessibility permission. Screen Recording is only needed for window previews.

## Changes

- Refreshed v2.3.0 as build 20301 so existing 2.3.0 installations can detect this signed update.
- Enabled the zhangqiaoran-owned Sparkle update channel with signed GitHub release archives, automatic update checks, and the native Check for Updates flow.
- Added a live Glass transparency control in Appearance from 0% to 100%, persisted in preferences and applied immediately to the switcher panel.
- Refined the About interface with unified my-alt-tab branding, a centered product hero, version/build details, and compact Website / GitHub / Report Issue actions.
- More right and bottom breathing room.
- Patch: fixed right/bottom Glass Focus clipping by reserving real NSClipView document gutters for lens glow and selected-tile scale.
- Ellipsis (…) action moved into its own top chrome strip so it never covers a thumbnail.
- Closing a window removes it from the current switcher list immediately.
- Denser 28-particle deterministic dissolve finishes in about 0.29s with fixed cost.
- Universal 2 release package supports Intel + Apple Silicon.

Update checks are handled only by Sparkle; no telemetry, analytics, accounts, or additional runtime dependency was added.
