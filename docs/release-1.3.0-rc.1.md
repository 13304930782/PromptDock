# PromptDock 1.3.0-rc.1 / Build 10

## Candidate changes / 候选版更新

- Reuse a single library window from settings, import and the Show Library command.
  设置、导入与“显示资料库”统一唤起唯一资料库窗口，关闭窗口后保留后台快捷调用。

- Explicit sample installation, stable sample IDs, import preview and navigation to imported records.
  空库可主动添加样例；导入后可查看本次新增或更新内容。
- Duplicate prompts with organization and variable metadata; reset template fields; recent usage shared with Widget.
  复制为新提示词，保留分类、标签及变量；模板重置；主窗口、快搜和 Widget 记录最近使用。
- Trash is now in the main sidebar, with selection, restore and confirmed permanent deletion.
  回收站移到主窗口侧栏，支持选择、恢复和确认后永久删除。
- Editable AI rewrite suggestions, line differences, variable protection and stale-record checks.
  AI 建议支持编辑、逐行对比、变量保护及原记录冲突检查。
- Test entry point runs without constructing SwiftUI windows.
  自动测试宿主不创建 SwiftUI 窗口。

- DeepSeek streamed thinking and live draft, elapsed time and cancellation; goal-specific rewrite instructions.
  DeepSeek 思考内容与正文分开展示，显示耗时并可取消；改写目标使用明确编辑规则。
- API key saving is reachable on the left and via Return, with focus dismissed on save.
  API Key 保存按钮移到左侧，支持回车保存并收起输入焦点。

## Verified locally / 本地验证

96 automated tests passed, including mocked DeepSeek streaming, interrupted output rejection and variable preservation. No paid API calls run in the automated suite. Public distribution and manual accessibility gates below remain pending.

## Build and package / 构建与打包

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project PromptDock.xcodeproj -scheme 'PromptDock Dev' -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
xcodebuild -project PromptDock.xcodeproj -scheme PromptDock -configuration Release -destination 'generic/platform=macOS' ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
./scripts/package-macos.sh internal /tmp/PromptDock-candidate
```

Internal DMG uses the Dev identity and Apple Development signing. It is not notarized and is not a public distribution artifact. Do not rename it to overwrite production.
内部包独立存储数据，不能当作已公证公开版发布。

Public packaging requires an existing Developer ID Application identity and notarytool Keychain profile:

```sh
export PROMPTDOCK_DEVELOPER_ID='Developer ID Application: YOUR SIGNING IDENTITY'
export PROMPTDOCK_NOTARY_PROFILE='YOUR_EXISTING_KEYCHAIN_PROFILE'
./scripts/package-macos.sh public /tmp/PromptDock-public-candidate
```

The script verifies both architectures, signs the DMG, waits for notarization acceptance, staples and validates the ticket, assesses Gatekeeper, then emits SHA-256. It never creates certificates or publishes a release. Do not place credentials in the repo or logs.

## Install, protect, recover / 安装、保护与恢复

1. Export a complete JSON backup from the currently installed application before an upgrade. Keep an external copy.
2. For development, install **PromptDock Dev.app** beside production and manually import the backup only if needed.
3. For release upgrade acceptance, use a separate macOS test account and a test library. Verify the original IDs, metadata, trash and history after installation.
4. To recover content, preview a complete JSON backup before importing. A replacement requires a successful safety backup. Do not open a migrated store with an older app as a rollback strategy; use a compatible exported backup.
5. Launch tests must not request Full Disk Access, reset privacy permissions, or access the user's production library.

## Release gates / 尚需人工验收

These are requirements, not claims of completion:

- Real permission refusal and explicit retry without repeated prompts; signed Widget interaction.
- V1/V2 upgrade and V3 recovery using test libraries, clean installation and upgrade on another Mac.
- English/Chinese, light/dark, VoiceOver and keyboard-only use.
- At least 20 warmed end-to-end 10k searches (snapshot + UI) on a fixed machine, P95 ≤300ms; cancellable 100k operations. Unit-test worker latency does not satisfy this gate.
- Seven days of real use after freeze with no unresolved data loss, startup, permission-loop or recovery blockers.
- Public Developer ID, notarization and downloaded-package Gatekeeper checks on another Mac.
- Separate approval before merging main or publishing GitHub Release. Existing PRs remain unmerged until approved.

## Build 10 window acceptance / 窗口人工验收

- Repeatedly choose Show Library (Command-Shift-N), Open Library in Settings, and View Imported after import: the same library window should come forward.
- Minimize the library and invoke Show Library: restore the existing window.
- Close the library with the red button, then reopen it from the app menu or Dock. The menu-bar/global-shortcut services should remain available.
- Settings and Template Variables Guide may remain separate utility windows.
- Perform this after quitting the old app and installing Build 10. This does not close windows belonging to an already running older process.
