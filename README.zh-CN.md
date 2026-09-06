# my-alt-tab

**zhangqiaoran 维护的原生 macOS 窗口切换器。**  
当前版本线：**v2.0.0** · macOS 14+ · Swift / AppKit · GPL-3.0

my-alt-tab 从 v1.0.0 起由 **zhangqiaoran** 作为当前项目作者、维护者和发行者。2.0 开始进入新的产品阶段：**UI 更高级，但绝不靠堆 Blur、堆动画、堆后台任务换视觉效果。**

> 继承代码所需的 GPL-3.0 上游来源与版权信息继续保留在 [`UPSTREAM.md`](UPSTREAM.md) 和 [`LICENSE`](LICENSE) 中。

## 2.0：Glass Focus Engine

2.0 的缩略图列表采用**共享毛玻璃平面**：

- macOS 26+：系统原生 `NSGlassEffectView`；
- macOS 14 / 15：原生 `NSVisualEffectView` 回退；
- 不给每个缩略图单独创建 Blur View；
- 不让 GPU / 合成开销随着窗口数量线性叠加。

选中反馈重新设计成三层：

1. **Focus Lens**：只有一个高亮镜片，跟随当前选中缩略图移动；
2. **Optical Lift**：当前缩略图轻微放大 2.2%，焦点非常明确；
3. **Distance-Adaptive Motion**：相邻 Tab 切换更快，跨行方向键移动稍微延长运动时间，让视线能跟上。

系统开启“减少动态效果”后，移动动画自动关闭。

## 热路径算法

| 场景 | 2.0 实现 | 复杂度 / 收益 |
|---|---|---|
| 选中窗口移动 | 预缓存 Lens Frame + 只修改旧/新 Tile | **O(1)** |
| 选中动画 | 1 个共享 Lens + 最多 2 个 Tile Transform | **常数级 compositor 工作量** |
| Preview 回填 | Window ID Hash 索引 | 平均 **O(1)** |
| Preview 刷新规划 | 无排序 Priority Buckets | **O(n)** |
| 缩略图匹配 | PID 分桶 + Flat Score Matrix + Dense Mask | 减少无意义跨 App 比较 |
| 截图任务 | Session in-flight 去重 | 同一窗口不重复抓图 |
| EventTap | 128-bit BitSet 快路径 | 常规键码不走 Set 分配 |
| 会话列表刷新 | 预分配 Hash + 单次遍历 | 降低 Chrome / IDEA / Finder 高频变化时的临时对象 |
| 缩略图内存 | 约 64 MiB 字节预算缓存 + transient release | 长时间运行内存有上限 |

这里不会为了“算法听起来高级”而硬塞复杂结构。例如扩展屏定位仍然使用 O(屏幕数) 的 point-in-rect，因为现实里通常只有 1～4 块屏幕，比维护 R-Tree / QuadTree 更轻。

## UI 为什么更高级但更轻

2.0 不采用“每张卡片一个实时毛玻璃层”的方式。整个列表只保留一个系统 Blur Surface，选中态使用轻量 Lens + Transform。

因此仍然坚持：

- 无每卡实时阴影；
- 无无限 Skeleton 动画；
- 连续按 Tab 不触发整列表 Layout；
- Preview 只做短时 Crossfade；
- 隐藏 Tile 主动释放重图片引用；
- 关闭按钮视觉紧凑，但仍保留 44×44 点击区域；
- 左 / 中 / 右缩略图排版继续保留。

## 多扩展屏

开启 Focused multi-display mode：

- 鼠标在哪块屏，面板只出现在哪块屏；
- 候选窗口仍然包含所有扩展屏符合规则的窗口；
- 只在打开切换器时解析鼠标所在屏；
- 不持续监听 `mouseMoved`；
- 不增加后台轮询 Timer。

## 关闭窗口

- 关闭按钮：直接关闭当前窗口；
- Delete / Backspace：直接关闭当前窗口；
- Finder：只关闭当前 Finder 窗口；
- my-alt-tab 不增加“关闭窗口还是退出应用”的二次确认；
- 如果目标 App 自己有“文件未保存”确认，仍然尊重它。

## 产品界面

仓库截图来自项目自己的 UI / Demo Harness。不同 macOS 版本的系统玻璃材质会存在轻微视觉差异。

![my-alt-tab 缩略图界面](docs/screenshots/switcher-previews-light.png)

![my-alt-tab Windows 设置](docs/screenshots/settings-windows.png)

## 快捷键

| 快捷键 | 功能 |
|---|---|
| **⌘⇥** | 打开 / 向前切换 |
| **⇧⌘⇥** | 向后切换 |
| **松开 ⌘** | 激活当前窗口 |
| **← → ↑ ↓** | 导航 |
| **Return / Space** | 确认 |
| **Esc** | 取消 |
| **Delete / Backspace** | 关闭当前窗口 |
| **⌘,** | 设置 |

## 隐私与资源原则

- 原生 Swift / AppKit；
- ScreenCaptureKit 只允许存在于 PreviewProvider；
- 截图只存在内存，不写磁盘、不上传；
- 无账号、无遥测、无 Analytics SDK；
- 2.0 不新增后台轮询；
- 2.0 不新增运行时依赖；
- zhangqiaoran 自有签名 / appcast 更新链完成前，社区版自动更新保持关闭。

## 构建

```bash
git clone https://github.com/zhangqiaoran/my-alt-tab.git my-alt-tab
cd my-alt-tab
chmod +x scripts/package-app.sh
./scripts/package-app.sh
```

输出：

```text
build/my-alt-tab.app
artifacts/my-alt-tab-2.0.0.zip
```

没有 Developer ID 时使用 ad-hoc 签名。

## 版本线

- **v1.0.0**：zhangqiaoran 正式基线；
- **v1.1.0**：热路径优化、缩略图内存预算、O(1) 选中刷新；
- **v2.0.0**：Glass Focus Engine、共享毛玻璃、常数级选中运动、更加明确的焦点视觉。

完整发行说明：[`RELEASE_NOTES_v2.0.0.md`](RELEASE_NOTES_v2.0.0.md)

## 项目信息

- 作者 / 维护者 / 发行者：**zhangqiaoran**
- 当前版本：**2.0.0**
- Build：**20000**
- Bundle ID：`com.zhangqiaoran.myalttab`
- GitHub：`zhangqiaoran/my-alt-tab`
- License：GNU GPL-3.0
