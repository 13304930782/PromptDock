# PromptDock 1.1.0 (Build 4) — Early Access

PromptDock is a native macOS prompt library and workflow tool designed for fast, private, local-first use.

PromptDock 是一款原生 macOS 提示词资料库与工作流工具，专注于快速、私密和本地优先的使用体验。

## What's new / 本次更新

- Fixed an issue where editing the initially selected prompt after launch could open an empty editor.
- Added prompt version history with preview and restore.
- Added tags and Smart Collections for organizing prompts across categories.
- Added reusable template variables, repeatable list variables, live preview, and one-click copy.
- Added optional AI-assisted template writing with DeepSeek and compatible custom endpoints.
- Improved Chinese and English localization throughout the app.
- Strengthened backup validation, startup recovery, URL validation, and local data safety.

- 修复应用启动后直接编辑首个高亮提示词时，编辑器可能显示为空的问题。
- 新增提示词版本历史，可预览并恢复旧版本。
- 新增标签与智能集合，可跨分类组织提示词。
- 新增普通变量、可重复列表变量、实时预览和一键复制。
- 新增可选的 AI 模板编写助手，支持 DeepSeek 与兼容的自定义接口。
- 完善应用内中英文翻译。
- 加强备份校验、启动恢复、URL 校验和本地数据安全。

## Privacy / 隐私

Prompts, categories, backups, and imported category images stay on this Mac. API keys are stored in Keychain. PromptDock sends data to an AI provider only after you explicitly start an AI request; it sends the current template-writing request and syntax guide, not your saved prompt library.

提示词、分类、备份和导入的分类图片保存在本机，API Key 存入钥匙串。只有在用户主动发起 AI 请求时，PromptDock 才会向所选服务发送当前模板编写需求和语法手册，不会发送已保存的提示词库。

## Installation / 安装

1. Requires macOS 14 or later.
2. Download `PromptDock-1.1.0-build4.dmg`.
3. Open the DMG and drag PromptDock into Applications.
4. This Early Access build is signed with a Personal Team certificate but is not notarized. If macOS blocks the first launch, Control-click PromptDock in Applications and choose Open.
5. To upgrade, quit PromptDock and replace the old copy in Applications. Existing data should remain available; exporting a JSON backup first is still recommended.

1. 需要 macOS 14 或更高版本。
2. 下载 `PromptDock-1.1.0-build4.dmg`。
3. 打开 DMG，将 PromptDock 拖入“应用程序”。
4. 此 Early Access 版本使用 Personal Team 证书签名，但未经 Apple 公证。若 macOS 阻止首次启动，请在“应用程序”中按住 Control 点击 PromptDock，然后选择“打开”。
5. 升级时先退出 PromptDock，再替换“应用程序”中的旧版本。原有数据应继续保留，但仍建议先导出 JSON 备份。

## Compatibility / 兼容性

- Apple Silicon and Intel Macs / 支持 Apple Silicon 与 Intel Mac
- macOS 14+ / macOS 14 及以上
- No automatic updater, account system, cloud sync, analytics, ads, or tracking / 暂无自动更新、账号、云同步、分析、广告或跟踪

## Integrity / 完整性校验

The SHA-256 checksum is provided in `PromptDock-1.1.0-build4.dmg.sha256`.

SHA-256 校验值见 `PromptDock-1.1.0-build4.dmg.sha256`。
