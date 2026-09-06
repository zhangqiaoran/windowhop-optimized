# my-alt-tab v2.1.1

Build hotfix for local packaging.

- `./scripts/package-app.sh` now detects whether SwiftPM's Swift Build backend is usable.
- Macs with only Command Line Tools automatically fall back to a current-architecture Release build.
- The local result is still `build/my-alt-tab.app` plus `artifacts/my-alt-tab-2.1.1.zip`.
- Official GitHub release builds continue to require Universal 2 and verify both arm64 and x86_64.

Author / maintainer: **zhangqiaoran**
