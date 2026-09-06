# my-alt-tab

Native macOS window switcher maintained by **zhangqiaoran**.

**Current release: v2.1.0** · macOS 14+ · Swift / AppKit · GPL-3.0  
中文说明：[`README.zh-CN.md`](README.zh-CN.md)

## Install

1. Open **Releases**.
2. Download `my-alt-tab-2.1.0.zip`.
3. Unzip it to get **my-alt-tab.app**.
4. Drag **my-alt-tab.app** into **Applications**.
5. On first launch, grant **Accessibility** permission. Grant **Screen Recording** only if you use window previews.

## v2.1

- More bottom breathing room so the last row no longer feels pressed against the panel edge.
- The selected preview uses one shared translucent **glass focus lens** instead of per-card blur.
- Closing a window plays a short bounded particle-dissolve effect with no idle animation cost.
- Fast two-window switching is locked in: current window stays first, previous window stays second, and normal switching starts on the second item.

## UI

### Window previews
![my-alt-tab window previews](docs/screenshots/switcher-previews-light.png)

### Dark appearance
![my-alt-tab dark window previews](docs/screenshots/switcher-previews-dark.png)

### Settings
![my-alt-tab settings](docs/screenshots/settings-appearance.png)

## Build from source

```bash
git clone https://github.com/zhangqiaoran/my-alt-tab.git
cd my-alt-tab
chmod +x scripts/package-app.sh
./scripts/package-app.sh
```

Output:

```text
build/my-alt-tab.app
artifacts/my-alt-tab-2.1.0.zip
```

The v2.1 packaging pipeline targets a Universal 2 app; the release is published only after CI verifies both **arm64** and **x86_64** slices.

## Project

- Author / maintainer / release owner: **zhangqiaoran**
- Bundle ID: `com.zhangqiaoran.myalttab`
- License: GNU GPL-3.0
- Upstream attribution: [`UPSTREAM.md`](UPSTREAM.md)
