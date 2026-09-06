# my-alt-tab

由 **zhangqiaoran** 维护的原生 macOS 窗口切换器。

**当前版本：v2.2.0** · macOS 14+ · Swift / AppKit · GPL-3.0

## 安装

1. 打开 GitHub **Releases**。
2. 下载 `my-alt-tab-2.2.0.zip`。
3. 解压后得到 **my-alt-tab.app**。
4. 把 **my-alt-tab.app** 拖进 **应用程序**。
5. 首次启动授予 **辅助功能** 权限；只有使用窗口缩略图时才需要 **屏幕录制** 权限。

## v2.2

- 增加右侧留白，最右边缩略图不再显得贴边。
- 右上角设置入口改成更轻量的 **三点 (…)** 按钮。
- 删除窗口时的粒子消散更生动，但仍然是固定数量、一次性动画。
- 保留共享毛玻璃选中态、双窗口快速切换和无空闲轮询的轻量架构。

## 界面

### 窗口缩略图
![my-alt-tab 窗口缩略图](docs/screenshots/switcher-previews-light.png)

### 深色模式
![my-alt-tab 深色模式](docs/screenshots/switcher-previews-dark.png)

### 设置
![my-alt-tab 设置](docs/screenshots/settings-windows.png)

## 源码构建

```bash
git clone https://github.com/zhangqiaoran/my-alt-tab.git
cd my-alt-tab
chmod +x scripts/package-app.sh
./scripts/package-app.sh
```

输出：

```text
build/my-alt-tab.app
artifacts/my-alt-tab-2.2.0.zip
```

GitHub 正式发布包会验证为 **Universal 2**，同时兼容 **Intel（x86_64）** 和 **Apple Silicon（arm64 / M 系列）**。

## 项目信息

- 作者 / 维护者 / 发行者：**zhangqiaoran**
- Bundle ID：`com.zhangqiaoran.myalttab`
- License：GNU GPL-3.0
- 上游归属：[`UPSTREAM.md`](UPSTREAM.md)
