# PromptDock 1.2.0 (Build 5) — Early Access

PromptDock is a native macOS prompt library and local workflow tool designed for fast, private use.

PromptDock 是一款原生 macOS 提示词资料库与本地工作流工具，专注于快速、私密的使用体验。

## What's new / 本次更新

- Reorganized the sidebar around Library, Smart Collections, Categories, and Tags.
- Added native multi-selection and batch organization for prompts.
- Integrated categories, tags, and template-variable definitions directly into the editor.
- Added repeatable variables, configurable labels and defaults, ordering, and live template filling.
- Added AI Rewrite with concise, contextual, structural, tone, and custom rewrite goals.
- Added a before/after comparison before accepting an AI rewrite.
- Preserved the original prompt through version history when an accepted rewrite is saved.
- Improved Chinese and English localization and fixed mixed-variable and asynchronous rewrite-state issues.

- 侧栏按“资料库、智能集合、分类、标签”重新组织。
- 新增原生多选与批量整理，可批量移动分类、管理标签、收藏或删除。
- 将分类、标签和模板变量管理直接整合进编辑器。
- 支持可重复变量、显示名称、默认值、填写顺序和实时填写预览。
- 新增 AI 改写，支持精简表达、补全上下文、优化结构、调整语气和自定义要求。
- 接受 AI 改写前可对照查看原文与改写版。
- 接受并保存改写后，通过版本历史保留原始提示词。
- 完善中英文翻译，并修复混合变量与异步改写状态问题。

## Privacy / 隐私

Prompts, categories, tags, collections, history, backups, and imported category images stay on this Mac. API keys are stored in Keychain. PromptDock sends only the current prompt text and the rewrite instruction to the selected AI provider after you explicitly choose Generate Rewrite. It does not send your prompt library, categories, tags, history, or local images.

提示词、分类、标签、智能集合、历史版本、备份和导入的分类图片保存在本机，API Key 存入钥匙串。只有在用户主动点击“生成改写”后，PromptDock 才会向所选 AI 服务发送当前提示词正文与改写要求；不会发送提示词库、分类、标签、历史版本或本地图片。

## Installation / 安装

1. Requires macOS 14 or later.
2. Download `PromptDock-1.2.0-build5.dmg`.
3. Open the DMG and drag PromptDock into Applications.
4. This Early Access build is locally signed but is not notarized. If macOS blocks the first launch, Control-click PromptDock in Applications and choose Open.
5. To upgrade, quit PromptDock and replace the old copy in Applications. Existing local data should remain available; exporting a JSON backup first is recommended.

1. 需要 macOS 14 或更高版本。
2. 下载 `PromptDock-1.2.0-build5.dmg`。
3. 打开 DMG，将 PromptDock 拖入“应用程序”。
4. 此 Early Access 版本使用本地签名，但未经 Apple 公证。若 macOS 阻止首次启动，请在“应用程序”中按住 Control 点击 PromptDock，然后选择“打开”。
5. 升级时先退出 PromptDock，再替换“应用程序”中的旧版本。原有本地数据应继续保留，但建议先导出 JSON 备份。

## Compatibility / 兼容性

- Apple Silicon and Intel Macs / 支持 Apple Silicon 与 Intel Mac
- macOS 14+ / macOS 14 及以上
- No automatic updater, account system, cloud sync, analytics, ads, or tracking / 暂无自动更新、账号、云同步、分析、广告或跟踪

## Integrity / 完整性校验

The SHA-256 checksum is provided in `PromptDock-1.2.0-build5.dmg.sha256`.

SHA-256 校验值见 `PromptDock-1.2.0-build5.dmg.sha256`。
