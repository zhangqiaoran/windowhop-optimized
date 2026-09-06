# my-alt-tab v2.1.0

**Author / maintainer / release owner: zhangqiaoran**

## Install

1. Download `my-alt-tab-2.1.0.zip`.
2. Unzip it to get `my-alt-tab.app`.
3. Drag the app into `/Applications`.
4. Grant Accessibility permission. Screen Recording is only needed for window previews.

## What changed

- More breathing room at the bottom edge of the switcher.
- One shared translucent glass focus lens for the selected preview.
- Short fixed-cost particle dissolve when closing a window.
- Fast two-window MRU behavior is regression-tested: current window first, previous window second, default selection starts on the previous window.
- Release packaging targets Universal 2 and must pass CI verification for arm64 + x86_64 before publication.

No background polling, idle animation loop, or new runtime dependency was added.
