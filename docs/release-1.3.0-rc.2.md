# PromptDock 1.3.0-rc.2 / Build 11

Development candidate only. Apple Development signing does not replace Developer ID or notarization.
开发测试候选包，尚未作为正式公开分发版本验收。

## Changes / 更新

- Replacement safety backups accept an explicit destination. Tests cannot resolve the user's default backup folder. A failed safety backup leaves the library untouched.
  整库替换的安全备份支持显式目录，测试不能隐式访问用户备份目录；备份失败不修改资料库。
- Disk recovery tests verify prompts, tags, variable definitions, history and Trash. Legacy backup imports and V2 migration preserve metadata.
  增加真实磁盘恢复、旧备份导入和 V2 迁移元数据检查。
- AI rewrite supports Escape dismissal and explicit VoiceOver labels for the suggestion editor and diff lines.
  AI 改写支持 Esc 关闭，为建议编辑器和新增/删除/未改变行增加读屏标签。
- Search debounce is reduced from 120 ms to 40 ms; superseded queries exit before worker launch.
  缩短查询等待，已过期的查询不启动后台搜索。
- Empty library/Quick Search queries no longer construct full-library search snapshots.
  主窗口和快搜在查询为空时跳过整库搜索快照。
- Packaging validates the signed app and Widget sandbox, identifiers and shared App Group. Public packaging also rejects missing Hardened Runtime.
  打包检查实际签名权限和 App/Widget 隔离配置。

## Reproduce / 复现

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project PromptDock.xcodeproj -scheme 'PromptDock Dev' -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
xcodebuild -project PromptDock.xcodeproj -scheme PromptDock -configuration Release -destination 'generic/platform=macOS' ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
./scripts/package-macos.sh internal /tmp/PromptDock-rc2-build11
```

The search pipeline test records two retained text attachments in the xcresult (all results / 12 results). Each uses 10,000 synthetic prompts, three warm-up queries and 20 measured queries. The timing includes snapshots, 40 ms debounce, ranking and mapping IDs to models. It excludes SwiftUI rendering and is not the end-to-end release gate. No prompt content or API keys are recorded. The 100,000-record test checks cancellation/result isolation, not UI responsiveness.

## Installation / 安装

Save edits, export a full JSON backup and quit the old PromptDock Dev before replacing it in Applications. Keep the production app unchanged. Use a separate test account and synthetic library for upgrade and permission-denial experiments. Never reset privacy permissions or grant Full Disk Access for this validation.
先保存并备份，退出旧开发版后再替换 PromptDock Dev。正式资料库不用于破坏性实验。

## Acceptance record / 验收记录

Automated evidence is recorded in `rc2-validation.md`. Do not mark these manual gates complete based on unit tests:

- [ ] Signed app: minimize/reopen, red-button close/reopen, Dock/menu/settings/import all reuse one library window; global shortcut remains available.
- [ ] Real permission refusal stays stable; explicit Retry makes one new attempt. Signed Widget can read only its matching environment.
- [ ] Separate account or Mac: clean install, Build 10 → 11 upgrade and restore from full backup.
- [ ] Chinese/English, light/dark, smallest supported window, keyboard-only workflow and VoiceOver.
- [ ] Fixed-machine end-to-end UI search: at least 20 warmed queries, 10k P95 ≤300ms. 100k long operations show responsive progress and cancel when supported. The current synchronous import commit/preview path still needs a responsiveness assessment before claiming this gate.
- [ ] Seven days of real use after freeze without data loss, startup blocks, permission loops or failed recovery.
- [ ] Developer ID, accepted notarization, stapled ticket and downloaded-package Gatekeeper check on another Mac.

No paid model requests are needed for this candidate's automated tests. PRs and GitHub Releases require separate approval before merge/publication. Prior rc.1 Release draft remains unchanged.

For an optimized, synthetic search measurement with isolated test hosting:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/benchmark-search.sh /tmp/PromptDock-search-benchmark
```

`ENABLE_TESTABILITY=YES` is limited to this benchmark command; Release optimization remains enabled. Results are retained as xcresult attachments. This command does not launch the regular app UI or initialize the production library.
