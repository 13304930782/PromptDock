# PromptDock 代码审查报告

## 项目概况

| 项目 | 详情 |
|------|------|
| 仓库 | [13304930782/PromptDock](https://github.com/13304930782/PromptDock) |
| 语言 | Swift 100%（SwiftUI + SwiftData） |
| 平台 | macOS 14.0+ |
| 版本 | 1.0.0 (build 1) |
| 审查日期 | 2026-07-22 |
| 第三方依赖 | 无（仅 Apple 原生框架） |

**项目简介：** PromptDock 是一个原生 macOS 应用，用于在本地管理和组织 AI 提示词库。主要功能包括三栏布局（侧边栏分类 / 提示词列表 / 提示词详情）、菜单栏图标、全局快捷键快速搜索（默认 Cmd+Shift+P），以及 WidgetKit 通知中心小组件。

---

## 一、代码安全性审查

### 1.1 网络安全

**结论：✅ 优秀。** 应用完全不发起任何网络请求。在全部 Swift 源文件中不存在 `URLSession`、`URLRequest`、任何 HTTP 客户端或 WebSocket 调用。这是一个完全离线的应用，不存在数据外泄的网络攻击面。

### 1.2 认证与凭证

**结论：✅ 优秀。** 应用中无任何 API Key、Token、Secret、密码等凭证。无硬编码密钥，无环境变量加载密钥，无认证系统、无登录流程、无用户账户管理。设置页的隐私选项卡明确标注 "No Account"（无账户）。

### 1.3 数据存储

**结论：✅ 良好。** 全部数据使用 Apple SwiftData 存储在本地：

- **存储位置：** App Group 容器 `L96B6KHL5Y.PromptDock/Library/Application Support/default.store`
- **Schema 版本：** 1.0.0（`PromptDockSchemaV1`）
- **数据模型：** `Prompt`（id, title, category, content, createdDate, updatedDate, isFavorite）和 `PromptCategory`（id, name, systemImage, sortOrder, createdDate, isBuiltIn, iconKind, iconEmoji, iconImageData）
- **分类图片：** 128x128 像素 PNG（源文件限制 20MB），使用 `@Attribute(.externalStorage)` 外部存储
- **无数据库服务器、无云同步、无远程存储。**

### 1.4 沙盒与运行时加固

**结论：✅ 优秀。** 从 `project.pbxproj` 确认：

- `ENABLE_APP_SANDBOX = YES`（Debug 和 Release 均启用）
- `ENABLE_HARDENED_RUNTIME = YES`（Debug 和 Release 均启用）
- 权限申请：仅 `com.apple.security.app-sandbox`、`com.apple.security.files.user-selected.read-write`、App Group `L96B6KHL5Y.PromptDock`

权限最小化原则执行得很好。

### 1.5 剪贴板访问

**结论：✅ 良好。** `ClipboardService` 仅写入剪贴板（`NSPasteboard.general.setString()`），从不读取。Widget 扩展的 `CopyPromptIntent` 同样仅写入。无剪贴板窥探风险。

### 1.6 全局快捷键

**结论：⚠️ 轻微关注。** `GlobalHotKeyService.swift` 使用 Carbon `RegisterEventHotKey` API（已弃用但仍可用）。优点：

- 检查 macOS 系统快捷键冲突（通过 `CopySymbolicHotKeys`）
- 检查 PromptDock 自身菜单快捷键冲突
- 验证必须包含修饰键（Cmd、Opt、Ctrl 之一）
- 禁用工况下不注册

**问题：**
- Carbon `RegisterEventHotKey` API 已被 Apple 弃用，未来 macOS 版本可能移除
- 硬编码签名 `0x50444F43`（"PDOC"），可能与其他应用碰撞
- Carbon 热键注册不经过 macOS 协调，可能与其他应用的 Carbon 热键冲突而不被检测到

### 1.7 备份系统安全性

**结论：✅ 良好。** 备份系统有完善的验证机制：

- 文件大小限制：100 MB（`maximumBackupByteCount`）
- 条目数限制：100,000 个提示词、10,000 个分类
- 重复 ID 检测
- 重复分类名检测
- 必填字段验证（title、category、content 不能为空）
- 分类图标验证（Emoji 必须是单字符、本地图片验证）
- 版本号验证（仅支持 formatVersion 1）
- Replace 模式自动创建安全备份

**发现的问题（低风险）：**

`SettingsView.swift` 中的 `loadImportCandidate` 方法先通过 `resourceValues` 检查文件大小，再调用 `Data(contentsOf:)` 读取。存在理论上的 TOCTOU（Time-of-check to time-of-use）风险——文件可能在两次操作之间被替换。对此 macOS 本地应用而言，风险极低。

### 1.8 输入验证

**结论：⚠️ 轻微关注。** 用户输入（提示词标题、内容、分类名）进行了空白字符修剪（`trimmingCharacters(in: .whitespacesAndNewlines)`），但：

- 无字符串长度上限限制——超大输入可能导致 UI 性能问题
- 无内容类型验证（但对于纯本地文本存储的应用，这不太可能被利用）
- 无 HTML/脚本内容过滤（当前无 WebView 渲染，不存在 XSS 风险，但如果未来版本添加 WebView 渲染提示词内容则需关注）

### 1.9 CI/CD

**结论：⚠️ 需改进。** 仓库中完全没有任何 CI/CD 配置。没有 `.github/workflows/` 目录，无自动化测试、无构建验证流程。

---

## 二、功能隐私性审查

### 2.1 隐私清单

**结论：✅ 优秀。** `PrivacyInfo.xcprivacy` 声明：

- `NSPrivacyAccessedAPITypes`：空数组（无 required-reason API 使用）
- `NSPrivacyCollectedDataTypes`：空数组（不收集任何数据）
- `NSPrivacyTracking`：false
- `NSPrivacyTrackingDomains`：空数组

### 2.2 数据分析与追踪

**结论：✅ 优秀。** 全代码库零分析框架、零遥测、零崩溃报告 SDK、零广告标识符。设置页隐私选项卡明确声明 "No analytics or advertising"。

### 2.3 数据本地化

**结论：✅ 优秀。** 隐私选项卡明确告知用户：

- "PromptDock stores this information locally and does not upload it"
- "No cloud sync"
- 备份导出/导入完全由用户主动触发
- 系统备份（Time Machine 等）说明由用户系统设置控制

### 2.4 用户透明性

**结论：✅ 良好。** 菜单栏图标默认可见，用户可以清楚知道应用正在运行。设置页提供清晰的隐私说明。

### 2.5 可访问性 API

**结论：✅ 良好。** 应用仅使用标准 SwiftUI 可访问性修饰符（`.accessibilityLabel`），无屏幕录制、无键盘监控（除已注册的单个热键）。

### 2.6 Widget 扩展隐私

**结论：✅ 良好。** Widget 扩展通过 App Group 共享数据，数据流向为：主应用 → WidgetSnapshotService → App Group 文件。Widget 仅展示用户已创建的提示词，Copy 按钮通过 `CopyPromptIntent` 写入剪贴板。无额外数据收集。

---

## 三、代码功能性审查

### 3.1 测试覆盖

**结论：✅ 良好。** `PromptDockTests.swift` 包含 20+ 个测试用例，覆盖：

- 模型初始化与持久化
- ViewModel CRUD 操作与收藏功能
- 搜索过滤（标题、内容、分类、精确/前缀/包含匹配）
- 搜索与边栏分类组合过滤
- 搜索结果导航（上下移动、循环）
- 热键组合验证与序列化
- 剪贴板服务
- 语言切换
- Widget 快照存取
- 分类服务（创建、去重、重排序、重命名、删除、内置分类保护）
- 分类图标处理
- 图片处理器（验证、拒绝无效输入）
- 备份往返（编码/解码、合并、替换、验证拒绝）
- Schema 版本迁移

### 3.2 错误处理

**结论：✅ 良好。** 应用一致使用 Swift 结构化错误处理：

- `throws` / `do-catch` 模式
- 自定义 `LocalizedError` 类型提供用户可读的错误信息
- 数据库操作失败时执行 `context.rollback()`
- UI 层通过 Alert 向用户展示错误

### 3.3 Actor 隔离

**结论：✅ 良好。** `@MainActor` 对 UI 相关代码使用一致，纯函数正确标记 `nonisolated`。`GlobalHotKeyService` 的回调中使用 `Task { @MainActor in ... }` 正确切回主线程。

### 3.4 内存管理

**结论：✅ 良好。** 闭包中正确使用 `[weak self]`（如事件监控器、Popover 回调），无发现明显的循环引用风险。`GlobalHotKeyService.deinit` 中正确注销热键和移除事件处理器。

### 3.5 发现的功能性问题

#### 问题 1：分类名标准化 locale 不一致（中等风险）

`BackupService.normalized()` 使用 `Locale(identifier: "en_US_POSIX")`，但 `CategoryService.normalizedKey()` 使用 `Locale.current`。在某些 locale（如土耳其语，其中 'i'/'I' 大小写规则特殊）下，两者可能产生不同的标准化结果。例如 "RESEARCH" 在土耳其语 locale 下折叠为 "researcı" 而非 "research"。这可能导致：
- 备份验证拒绝在土耳其语系统上创建的分类名
- 分类去重逻辑与备份验证逻辑不一致

涉及文件：`BackupService.swift`、`PromptCategory.swift`

#### 问题 2：Widget 快照双写机制可能导致数据不一致（低风险）

`WidgetSharedStore.save()` 同时写入文件（主要传输方式）和 `UserDefaults`（向后兼容）。如果文件写入成功但 `UserDefaults` 写入静默失败（返回 `false` 的设置不抛出），Widget 读取时可能因文件优先而正常，但任何仅读取 `UserDefaults` 的遗留路径可能获得过期数据。

涉及文件：`WidgetPromptSnapshot.swift` 中的 `WidgetSharedStore`

#### 问题 3：TOCTOU 潜在风险（低风险）

`SettingsView.loadImportCandidate()` 先通过 `resourceValues` 检查文件大小，再读取文件内容。虽然对本地应用风险极低，但严格来说存在检查和读取之间的时间窗口。

涉及文件：`SettingsView.swift`

#### 问题 4：默认分类名硬编码（低风险）

"Teaching"、"Coding"、"AI"、"Writing" 四个默认分类名称硬编码在 `CategoryService` 中。EditorView 的 `PromptDraft` 默认分类也硬编码为 "Teaching"。中文界面下，默认分类名仍显示为英文。

涉及文件：`PromptCategory.swift`、`PromptViewModel.swift`、`EditorView.swift`

#### 问题 5：偏好设置存储路径不统一（低风险）

SwiftUI 视图中使用 `@AppStorage`，而 `MenuBarController`、`QuickSearchPanelController` 等服务层使用 `UserDefaults.standard.string(forKey:)`。虽然指向相同底层存储，但存在两套代码路径。

涉及文件：`SettingsView.swift` 对比 `QuickSearchPanelController.swift`

#### 问题 6：MigrationsPlan 为空（信息性）

`PromptDockMigrationPlan.stages` 为空数组，当前只有 v1.0.0 schema。这在初期版本正常，但需注意未来 schema 变更时需添加相应迁移阶段。

涉及文件：`DataService.swift`

#### 问题 7：搜索性能（信息性）

`QuickSearchView` 使用 `@Query` 获取全部提示词后在客户端过滤。对于极大型库（10,000+ 条提示词），可能影响性能。当前因限制显示 12 条结果，实际影响有限。

涉及文件：`QuickSearchView.swift`

#### 问题 8：fatalError 替代方案（低风险）

`PromptDockApp.init()` 在 ModelContainer 创建失败时调用 `fatalError`，这会导致应用直接崩溃而非向用户展示错误信息。

涉及文件：`PromptDockApp.swift`

---

## 四、整改方案

### 4.1 高优先级（建议尽快修复）

无。本次审查未发现高危安全漏洞或隐私问题。

### 4.2 中优先级

#### 整改 1：统一字符串标准化 locale

**问题：** 分类名标准化在 BackupService 使用 `en_US_POSIX`，CategoryService 使用 `.current`

**方案：** 将 `CategoryService.normalizedKey()` 改为使用 `Locale(identifier: "en_US_POSIX")`

```swift
// PromptCategory.swift - CategoryService
private static func normalizedKey(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")  // 改为 POSIX
        )
}
```

#### 整改 2：添加提示词内容长度上限

**方案：** 在 `PromptDraft.isValid` 或 `PromptViewModel.validatedValues()` 中添加长度验证：

```swift
// PromptViewModel.swift
static let maxTitleLength = 500
static let maxContentLength = 100_000

private func validatedValues(from draft: PromptDraft) throws -> (...) {
    // 现有验证...
    guard title.count <= Self.maxTitleLength else {
        throw PromptValidationError.titleTooLong
    }
    guard content.count <= Self.maxContentLength else {
        throw PromptValidationError.contentTooLong
    }
    // ...
}
```

#### 整改 3：添加 CI/CD 配置

**方案：** 创建 `.github/workflows/ci.yml`，在 macOS runner 上运行 `xcodebuild test`。

### 4.3 低优先级

#### 整改 4：简化 Widget 快照存储

**方案：** 考虑在后续版本中移除 UserDefaults 的 Widget 快照路径，统一使用文件存储。或添加版本标记以检测过期数据。

#### 整改 5：本地化默认分类名

**方案：** 将默认分类名称移入 `Localizable.xcstrings` 目录。

#### 整改 6：统一偏好设置访问模式

**方案：** 考虑创建统一的 `AppPreferences` 封装层，同时服务于 SwiftUI 视图（`@AppStorage`）和服务层（UserDefaults 直接访问）。

#### 整改 7：添加用户友好的启动错误处理

**方案：** 将 `PromptDockApp.init()` 中的 `fatalError` 替换为向用户显示错误对话框后优雅退出。

#### 整改 8：添加 README

**方案：** 仓库完全没有 README 文档。建议添加包含项目描述、功能列表、构建说明、隐私说明和截图的项目文档。

#### 整改 9：为未来 Schema 迁移添加占位代码

**方案：** 在 `PromptDockMigrationPlan` 添加注释，提醒开发者后续版本添加迁移阶段。

#### 整改 10：考虑迁移到现代热键 API

**方案：** 评估将 Carbon `RegisterEventHotKey` 替换为现代 API（如 `NSEvent.addGlobalMonitorForEvents` 或 `CGEvent` tap），权衡沙盒兼容性和功能性。在 macOS 15+ 中 Carbon API 仍然可用，但未来可能被移除。

---

## 五、总结

PromptDock 是一款代码质量较高的 macOS 本地应用。核心结论：

| 审查维度 | 评级 | 说明 |
|----------|------|------|
| 网络安全 | ✅ 优秀 | 完全离线，零网络请求 |
| 认证安全 | ✅ 优秀 | 无认证系统，无凭证存储 |
| 数据存储 | ✅ 优秀 | 纯本地 SwiftData，无云同步 |
| 沙盒加固 | ✅ 优秀 | App Sandbox + Hardened Runtime 均启用 |
| 隐私保护 | ✅ 优秀 | 隐私清单完整，零追踪零分析 |
| 错误处理 | ✅ 良好 | 一致的 throw/catch/rollback 模式 |
| 测试覆盖 | ✅ 良好 | 20+ 测试覆盖核心路径 |
| 代码质量 | ✅ 良好 | 规范的 Swift 6 并发模式，少量不一致 |
| CI/CD | ⚠️ 缺失 | 无自动化构建/测试流程 |
| 文档 | ⚠️ 缺失 | 无 README |

**总体评价：** PromptDock 是一款设计良好、注重隐私的 macOS 应用。它完全离线运行，所有数据存储在本地，不发起任何网络请求，不包含任何凭证，没有认证系统，不依赖第三方库，并且同时启用了 App Sandbox 和 Hardened Runtime。发现的问题均为低到中等风险，没有高危安全漏洞。推荐按照整改方案逐步优化。
