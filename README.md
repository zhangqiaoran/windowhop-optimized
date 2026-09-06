# my-alt-tab

Native macOS window switcher maintained by **zhangqiaoran**.

**Current release: v2.2.0** · macOS 14+ · Swift / AppKit · GPL-3.0  
中文说明：[`README.zh-CN.md`](README.zh-CN.md)

## Install

1. Open **Releases**.
2. Download `my-alt-tab-2.2.0.zip`.
3. Unzip it to get **my-alt-tab.app**.
4. Drag **my-alt-tab.app** into **Applications**.
5. On first launch, grant **Accessibility** permission. Grant **Screen Recording** only if you use window previews.

## v2.2

- More right-side breathing room for the preview grid.
- Top-right Settings control is now a compact **ellipsis (…)** action.
- Window close uses a richer fixed-cost particle dissolve with two visual waves.
- Keeps the shared glass focus lens, fast two-window switching, and lightweight event-driven behavior.

## UI

### Window previews
![my-alt-tab window previews](docs/screenshots/switcher-previews-light.png)

### Dark appearance
![my-alt-tab dark window previews](docs/screenshots/switcher-previews-dark.png)

### Settings
![my-alt-tab settings](docs/screenshots/settings-windows.png)

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
artifacts/my-alt-tab-2.2.0.zip
```

Official GitHub releases are verified as **Universal 2** builds for both **Intel (x86_64)** and **Apple Silicon (arm64)**.

## Project

- Author / maintainer / release owner: **zhangqiaoran**
- Bundle ID: `com.zhangqiaoran.myalttab`
- License: GNU GPL-3.0
- Upstream attribution: [`UPSTREAM.md`](UPSTREAM.md)
