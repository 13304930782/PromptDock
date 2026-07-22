# PromptDock

[English](#english) · [简体中文](#简体中文)

## 简体中文

PromptDock 是一款原生 macOS 提示词资料库。它使用 SwiftUI 和 SwiftData 构建，提供分类管理、精确搜索、菜单栏快搜、全局快捷键、备份导入导出和桌面小组件。

### 功能

- 创建、编辑、收藏、分类和拖动排序提示词。
- 搜索标题、正文和分类，并高亮关键词、显示命中数量和支持上下导航。
- 使用菜单栏或默认全局快捷键 `⇧⌘P` 打开快搜；方向键选择，`Return` 复制，`Esc` 关闭。
- 自定义分类支持系统 Emoji 和本地图片。图片会裁剪为 128×128 PNG 后保存在本机，不持续访问原文件。
- 备份采用 JSON 格式，支持合并或替换导入；替换前会先创建安全备份。
- Widget 显示可快速复制的最近或收藏提示词。
- 设置页提供语言、菜单栏、登录启动、全局快捷键和隐私说明。

### 系统要求

- macOS 14 或更高版本
- Xcode 16 或更高版本
- 不依赖第三方运行时框架

### 隐私设计

PromptDock 当前不包含账号、广告、分析、网络上传或云同步功能。提示词、分类 Emoji、分类图片和 Widget 快照均保存在这台 Mac。PromptDock 不会主动上传这些数据；Time Machine、磁盘同步和其他系统备份由用户的 macOS 设置决定。

### 在 Xcode 中构建

1. 克隆仓库并打开 `PromptDock.xcodeproj`。
2. 在项目设置的 **TARGETS → PromptDock → Signing & Capabilities** 中选择你的 Team。
3. 在 **TARGETS → PromptDockWidget → Signing & Capabilities** 中选择同一个 Team。
4. 选择 `PromptDock` Scheme 和 `My Mac`，按 `⌘R` 运行。

App Group 标识由构建设置自动生成为 `$(DEVELOPMENT_TEAM).PromptDock`，主应用、Widget、entitlements 和运行时代码共用同一个值。切换 Team 后不需要修改 Swift 源码。现有维护者的 Team 会继续解析为 `L96B6KHL5Y.PromptDock`，因此已有数据目录保持不变。

如果修改代码后界面没有刷新，请先停止旧进程（`⌘.`），再执行 **Product → Clean Build Folder**（`⇧⌘K`）并重新运行。

### 测试

```bash
xcodebuild \
  -project PromptDock.xcodeproj \
  -scheme PromptDock \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/PromptDockTests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

GitHub Actions 会在 Pull Request 和推送到 `main` 时运行完整 Debug 测试及 Release 无签名构建。CI 不需要证书或 Apple 账号。

### 备份与数据兼容

备份 JSON 格式当前为版本 1。SwiftData 当前保持 `PromptDockSchemaV1`，空迁移阶段是有意保留的。未来任何 SwiftData 模型变更都必须新增 Schema 版本和对应迁移阶段，不能直接修改 V1。

### Personal Team、DMG 与发布

- 免费 Apple ID / Personal Team 足以在自己的 Mac 上通过 Xcode 运行和测试主应用及 Widget。
- 可以自行生成 DMG；DMG 只是安装容器，不等于代码签名或公证。
- 没有付费 Apple Developer Program 时，无法获得用于公开分发的 Developer ID 签名和 Apple 公证。其他用户首次打开未公证应用时可能看到 Gatekeeper 警告。
- Mac App Store、Developer ID 公证发行仍需要 Apple Developer Program。

### 许可

PromptDock 使用 [MIT License](LICENSE)。

## English

PromptDock is a native macOS prompt library built with SwiftUI and SwiftData. It includes categories, deterministic search, menu-bar quick search, a configurable global shortcut, JSON backups, and a WidgetKit extension.

### Highlights

- Create, edit, favorite, categorize, and reorder prompts.
- Search titles, content, and categories with highlighting, match counts, and keyboard navigation.
- Open Quick Search from the menu bar or with `⇧⌘P`; use arrow keys to select, `Return` to copy, and `Esc` to close.
- Use system Emoji or imported local images for custom categories. Images are normalized to a local 128×128 PNG and the original file is not accessed afterward.
- Merge or replace version-1 JSON backups. Replace import creates a safety backup first.
- Show recent or favorite prompts in a macOS widget.
- Configure language, menu-bar presence, launch at login, the global shortcut, and privacy settings.

### Requirements and privacy

PromptDock requires macOS 14+ and Xcode 16+. It has no third-party runtime dependencies. The current app has no accounts, advertising, analytics, network upload, or cloud sync. Prompts, category icons, and widget snapshots stay on this Mac, subject to the user's system backup and disk-sync settings.

### Build and run

1. Open `PromptDock.xcodeproj`.
2. Select your Team under **TARGETS → PromptDock → Signing & Capabilities**.
3. Select the same Team for **PromptDockWidget**.
4. Choose the `PromptDock` scheme and `My Mac`, then press `⌘R`.

The App Group is derived from `$(DEVELOPMENT_TEAM).PromptDock` and shared by both targets, their entitlements, and runtime code. A new developer only needs to choose a Team; no Swift source edits are required.

Run tests with the command in the Chinese section above. CI runs Debug tests and an unsigned Release build on `macos-15` without Apple credentials.

The backup format and SwiftData schema both remain at version 1. Future model changes must introduce a new schema version and migration stage instead of modifying V1 in place.

A free Personal Team supports local development and widget testing. A DMG can be created without a paid account, but public Developer ID signing, notarization, and Mac App Store distribution require the Apple Developer Program. An unsigned or unnotarized DMG may trigger Gatekeeper warnings on other Macs.

PromptDock is available under the [MIT License](LICENSE).
