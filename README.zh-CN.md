# my-alt-tab

由 **zhangqiaoran** 维护的原生 macOS 窗口切换器。

**当前版本：v2.1.0** · macOS 14+ · Swift / AppKit · GPL-3.0

## 安装

1. 打开 GitHub **Releases**。
2. 下载 `my-alt-tab-2.1.0.zip`。
3. 解压后得到 **my-alt-tab.app**。
4. 把 **my-alt-tab.app** 拖进 **应用程序**。
5. 首次启动授予 **辅助功能** 权限；只有使用窗口缩略图时才需要 **屏幕录制** 权限。

## v2.1

- 增加底部留白，最后一排缩略图和标题不再贴近面板边缘。
- 选中态改成单一共享的**半透明毛玻璃 Focus Lens**，不为每个缩略图单独创建 Blur。
- 删除窗口时加入短促的粒子消散效果，固定粒子数量、一次性执行，不增加空闲后台开销。
- 双窗口快速切换逻辑固定：当前窗口第 1、上一个窗口第 2，正常切换默认从第 2 个窗口开始选择。

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
artifacts/my-alt-tab-2.1.0.zip
```

v2.1 的打包流程以 **Universal 2** 为目标；只有 CI 同时验证 **arm64（M 系列）** 和 **x86_64（Intel）** 两个架构后才正式发布。

## 项目信息

- 作者 / 维护者 / 发行者：**zhangqiaoran**
- Bundle ID：`com.zhangqiaoran.myalttab`
- License：GNU GPL-3.0
- 上游归属：[`UPSTREAM.md`](UPSTREAM.md)
