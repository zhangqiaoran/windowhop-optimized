# my-alt-tab

由 **zhangqiaoran** 维护的原生 macOS 窗口切换器。

**当前版本：v3.4.0** · macOS 14+ · Swift / AppKit · GPL-3.0

## 安装

1. 打开 GitHub **Releases**。
2. 下载 `my-alt-tab-3.4.0.zip`。
3. 解压后得到 **my-alt-tab.app**。
4. 把 **my-alt-tab.app** 拖进 **应用程序**。
5. 首次启动授予 **辅助功能** 权限；只有使用窗口缩略图时才需要 **屏幕录制** 权限。

## v3.4.0

- **数值越大越液态，数值越小越乳白**：100% 时乳白层为 0，同时把原生 Clear Glass 本体降低到约 60% surface alpha，让壁纸颜色和光影更明显地透进来；越往 0% 拉，玻璃本体逐步恢复到 100%，乳白层按感知曲线逐渐加厚，0% 可达到约 72% 的半透明乳白层。
- 玻璃背景、乳白 Density、缩略图/文字/蓝框现在是三套独立层级；调玻璃不会再让前景内容跟着变淡。
- **窗口缩小改成 Stable-ID FLIP**：NSWindow、玻璃、前景 Chrome、ScrollView、存活卡片、按钮和蓝色选中框全部由同一个 `NSAnimationContext`、同一条缓动曲线驱动，不再混用 NSWindow 动画与独立 CA 卡片动画。
- 移除了选中卡片额外的 1.018× 缩放，避免它和列表收缩叠加产生轻微抖动。
- 保留 3.3.0 的 36 帧真实缩略图侵蚀、跟随侵蚀边缘的粒子以及粒子 80% 后再开始列表收缩。

## v3.3.0

- **真正的透明玻璃**：100% 时不再叠任何白色密度；即使拉到 0%，额外密度最高也只到 20%，桌面背景始终能明显透过玻璃看到。
- macOS 26+ 继续使用原生 `NSGlassEffectView.Style.clear`，不再通过乳白层强行制造“磨砂感”。
- **缩略图本体真的会消散**：抓取 Snapshot 后，底下原来的 Tile 会视觉隐藏，只保留布局占位；因此 Mask 挖掉哪里，那里就真的露出后面的玻璃，不会再看到一张完整缩略图垫在粒子下面。
- 使用缓存的 **36 帧不规则 Alpha Mask**，通过细粒度 + 粗粒度确定性噪声制造缺口、碎块、孤岛和侵蚀边缘。
- 粒子发射器改成跟随侵蚀边缘移动的窄带，灰尘从正在消失的图片边缘产生，而不是整张卡片同时喷粒子。
- 保留粒子达到 80% 后再开始 0.42 秒柔和缩小的节奏。

## v3.2.0

- **顶部真正透明**：窗口列表上方的空白操作区不再铺乳白层；macOS 26+ 外层保持 Clear Glass，磨砂密度只作用在下方窗口内容区，并在三点按钮区域前柔和淡出。
- **蓝色选中框**：选中的窗口不再叠灰白填充，也不再覆盖第二层玻璃；只保留 **2px 固定系统蓝描边 + 轻微蓝色 Glow**，缩略图内容保持原样清晰。
- **粒子 80% 后再缩小**：点击关闭后真实窗口立即关闭，但切换器中的视觉卡片和面板尺寸先冻结；约 **0.816 秒（粒子生命周期 80%）** 后，才开始 0.42 秒的柔和列表收拢。
- WindowStore 刷新期间会保留正在消散的视觉卡片，快速松开快捷键也会自动跳过已经关闭的 Ghost，不会误激活死窗口。
- 继续保持 Universal 2 与 Sparkle EdDSA 应用内更新。

## v3.1.0

- 毛玻璃重新校准为更接近 macOS 控制中心的 **Frosted Glass**，100% 仍保留明显磨砂和景深。
- 窗口列表缩小时，面板、存活窗口和选中层统一使用同一条无回弹缓动曲线，不再混用系统 resize 与 spring，减少“像掉帧”的速度突变。
- 关闭窗口的消散改为 GPU `CAEmitterLayer`：约 300～400 个微尘粒子、柔和烟尘、方向性侵蚀以及随侵蚀移动的亮边，更贴近参考视频的灰飞烟灭效果。
- 正式发布链已经准备固定 Developer ID 签名 + Apple 公证，以便后续正式签名版本更新能够稳定继承 macOS 权限。

## v3.0.0

- **窗口列表优雅收缩**：窗口关闭后，不再瞬间硬跳。通过稳定窗口 ID 匹配存活卡片，并从当前真实渲染位置进行弹性重排，同时面板使用原生 AppKit 动画居中缩小。
- **全新风尘消散引擎**：固定 56 粒子预算，使用 R2 低差异分布覆盖整个窗口表面，并结合渐变侵蚀和三次贝塞尔风向轨迹，形成更飘逸的逐步风化效果。
- **连续快速关闭也不会跳帧**：下一次动画直接读取 Core Animation presentation layer 的当前视觉位置，而不是从旧布局重新开始。
- **更新中心升级**：打开“设置 → Updates”会静默检查签名版本源；发现新版后可直接点击 **Update Now…** 进入 Sparkle 验证安装流程。
- **保持极低空闲开销**：没有新增 display link、循环粒子定时器或常驻动画；仅在实际操作发生时工作，并遵守 macOS“减少动态效果”。
- 清理了一批历史遗留、已经没有使用价值的 UI Token。

## v2.4.0

- **液态玻璃透明度改为真正的 0～100% 语义**：数值越高越透明，100% 为最通透的原生 Liquid Glass。
- macOS 26+ 主面板和被选中的窗口都使用原生 `NSGlassEffectView.Style.clear`。
- 不再只通过 `tintColor` 模拟透明度，新增独立背景密度层；调节透明度不会让缩略图、图标和文字一起变淡。
- 100% = 0% 额外密度，90% = 10%，50% = 50%，0% = 最大密度。
- 保留 Sparkle 自动更新、Universal 2、右下防裁切和窗口关闭粒子动画。

## v2.3

- 增加右侧和底部留白，最右侧缩略图不再贴边。
- 右上角 **三点 (…)** 放进独立的顶部操作区，不再覆盖缩略图。
- 点击关闭后，窗口会立即从切换列表移除，同时播放更密集的 28 粒子消散动画。
- 正式发布包继续兼容 Intel + Apple Silicon。

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
artifacts/my-alt-tab-3.4.0.zip
```

GitHub 正式发布包会验证为 **Universal 2**，同时兼容 **Intel（x86_64）** 和 **Apple Silicon（arm64 / M 系列）**。

## 项目信息

- 作者 / 维护者 / 发行者：**zhangqiaoran**
- Bundle ID：`com.zhangqiaoran.myalttab`
- License：GNU GPL-3.0
- 上游归属：[`UPSTREAM.md`](UPSTREAM.md)
