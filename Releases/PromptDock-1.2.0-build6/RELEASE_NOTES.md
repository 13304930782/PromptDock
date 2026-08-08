# PromptDock 1.2.0 (Build 6) — Early Access

PromptDock is a native macOS prompt library and local workflow tool designed for fast, private use.

PromptDock 是一款原生 macOS 提示词资料库与本地工作流工具，专注于快速、私密的使用体验。

## What's new / 本次更新

- Reorganized the sidebar around Library, Smart Collections, Categories, and Tags.
- Added native multi-selection and batch organization for prompts.
- Integrated categories, tags, and template-variable definitions directly into the editor.
- Added repeatable variables, configurable labels and defaults, ordering, and live template filling.
- Added AI Rewrite with before/after comparison and version-history preservation.
- Improved Chinese and English localization and fixed mixed-variable, editor-selection, and asynchronous rewrite-state issues.
- Replaced the previous ad-hoc distribution signature with the valid Apple Development identity while preserving the existing App Group.

- 侧栏按“资料库、智能集合、分类、标签”重新组织。
- 新增原生多选与批量整理。
- 将分类、标签和模板变量管理整合进编辑器。
- 支持可重复变量、显示名称、默认值、填写顺序和实时填写预览。
- 新增 AI 改写、原文对比及版本历史保留。
- 完善中英文翻译，并修复混合变量、首次编辑选择和异步改写状态问题。
- 使用有效 Apple Development 身份替代旧版临时签名，同时保留现有 App Group 数据容器。

## Upgrade safety / 升级安全

Build 6 preserves the existing `L96B6KHL5Y.PromptDock` App Group, so no data migration is required. Exporting a JSON backup before replacing an Early Access build is still recommended.

Build 6 保留现有的 `L96B6KHL5Y.PromptDock` App Group，因此不需要迁移数据。替换 Early Access 版本前仍建议先导出一份 JSON 备份。

## Privacy / 隐私

Prompts, categories, tags, collections, history, backups, and imported category images stay on this Mac. API keys are stored in Keychain. PromptDock sends only the current prompt text and rewrite instruction to the selected AI provider after explicit confirmation.

提示词、分类、标签、智能集合、历史版本、备份和分类图片保存在本机，API Key 存入钥匙串。只有用户主动确认后，PromptDock 才会向所选 AI 服务发送当前提示词正文与改写要求。

## Installation / 安装

1. Requires macOS 14 or later.
2. Open `PromptDock-1.2.0-build6.dmg` and drag PromptDock into Applications.
3. This Personal Team Early Access build is Apple Development signed but not notarized. If Gatekeeper blocks the first launch, Control-click PromptDock and choose Open.

1. 需要 macOS 14 或更高版本。
2. 打开 `PromptDock-1.2.0-build6.dmg`，将 PromptDock 拖入“应用程序”。
3. 此 Personal Team Early Access 版本具有 Apple Development 签名，但未经公证。若首次启动被阻止，请按住 Control 点击 PromptDock 并选择“打开”。

## Compatibility / 兼容性

- Apple Silicon and Intel Macs / Apple Silicon 与 Intel Mac
- macOS 14+ / macOS 14 及以上
- No automatic updater, account system, cloud sync, analytics, ads, or tracking / 暂无自动更新、账号、云同步、分析、广告或跟踪

## Integrity / 完整性校验

The SHA-256 checksum is provided in `PromptDock-1.2.0-build6.dmg.sha256`.

SHA-256 校验值见 `PromptDock-1.2.0-build6.dmg.sha256`。
