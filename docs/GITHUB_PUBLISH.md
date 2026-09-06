# GitHub 发布与后续迭代

目标仓库：`https://github.com/zhangqiaoran/my-alt-tab`

## 第一次上传

仓库创建为空仓库后：

```bash
git init
git branch -M main
git add .
git commit -m "release: my-alt-tab v1.0.0 by zhangqiaoran"
git remote add origin git@github.com:zhangqiaoran/my-alt-tab.git
git push -u origin main
```

发布 1.0.0：

```bash
git tag -a v1.0.0 -m "my-alt-tab v1.0.0"
git push origin v1.0.0
```

`Release Community Build` Workflow 会自动测试、构建并创建 GitHub Release。

## 后续开发

正常迭代：

```bash
git checkout main
git pull
# 修改源码
git add .
git commit -m "feat: describe your change"
git push
```

发布新版本时，先同步修改：

- `Support/Info.plist` → `CFBundleShortVersionString`
- `Support/Info.plist` → `CFBundleVersion`
- `CHANGELOG.md`
- 对应 `RELEASE_NOTES_vX.Y.Z.md`（建议）

然后创建匹配 Tag：

```bash
git tag -a v1.1.0 -m "my-alt-tab v1.1.0"
git push origin v1.1.0
```

Tag 与 Info.plist 版本不一致时，Release workflow 会直接失败，避免错误发行。
