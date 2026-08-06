# PromptDock 1.2 代码审计辩论与裁决报告

> 审计对象：`codex/promptdock-1.2-local-workflow`  
> 审计提交：`5bbfe006f1d7ae4ff01f94299b644e6067fdadfd`  
> DeepSeek 报告 SHA-256：`dba860d79bd20ecbf0fa17abd7565b76be63f7b25768a446ec6288a9faa77687`  
> 复核日期：2026-08-06

## 1. 结论先行

DeepSeek 报告发现了两个真实问题，但把多个设计选择、SwiftUI/Swift 语言行为和本轮范围外的代码误判成了高危缺陷。

经调用链和实现逐项复核：

- **没有证据支持 P0 数据丢失。**
- **没有证据支持报告所列的 6 个 P1。**
- 确认两个需要修复的问题：
  1. 删除提示词后，没有同步删除 `PromptVersion` 和 `TemplateVariableDefinition`，会留下孤立记录。
  2. `NSTextView` 接收编程式正文更新时没有保存并恢复光标范围，可能发生光标跳转。
- 另外有四项适合顺手加固，但不是发布阻断：
  1. `restore` 使用统一的 `saveOrRollback`。
  2. “最近更新”在服务内部再做一次显式排序，避免未来调用方传入无序数组。
  3. AI 改写接受前检查原文是否已被其他窗口修改。
  4. 为“编辑已有提示词不会丢失标签和变量定义”补回归测试。
- SSRF、DNS 重绑定、Emoji 被截断、`let Prompt` 不刷新、内联 `Binding` 必然错选等结论不成立。
- 报告中的后端认证、Turnstile 和网站测试项不属于提交 `5bbfe00`，不应计入 PromptDock 1.2 的本轮风险。

因此，原报告“1 个 P0、6 个 P1、总体中高风险”的摘要需要撤回。更准确的结论是：

| 级别 | 数量 | 结论 |
|---|---:|---|
| P0 | 0 | 未发现确定性数据丢失或密钥泄露 |
| P1 | 0 | 未发现可稳定复现的核心功能阻断 |
| P2 | 2 | 删除清理不完整、编辑器光标可能跳转 |
| P3 / 加固 | 4 | 事务一致性、排序防御、并发覆盖提示、回归测试 |

## 2. 辩论规则

本文件不是为了证明某个模型“更正确”，而是让结论可以被代码复核。

采用以下规则：

1. 以提交 `5bbfe00` 的实际调用链为准，不根据函数名猜测行为。
2. 区分“当前可触发的缺陷”“未来可能的风险”“产品设计选择”和“范围外问题”。
3. 只有能说明触发路径、实际影响和代码证据的问题，才保留 P0/P1。
4. 安全结论必须先定义信任边界和攻击者；不能把用户主动配置自己的本地 API 当作远程攻击。
5. SwiftUI、SwiftData 和 Unicode 的判断必须符合 macOS 14+ / Swift 的实际语义。

## 3. 第一轮：`PromptDraft` 是否造成 P0 数据丢失

### DeepSeek 观点

`PromptDraft.init(prompt:)` 将 `tagIDs`、`variableDefinitions` 和 `newTagNames` 初始化为空。若该草稿随后用于保存，标签会被移除、变量元数据会被重置，因此应判为 P0。

### Codex 复核

单看初始化器确实容易产生这个怀疑，但真实调用链不是“初始化后直接保存”。

当前唯一调用点位于 `EditorView.init`：

```swift
let base = prompt.map(PromptDraft.init(prompt:))
    ?? PromptDraft(category: initialCategory)

_title = State(initialValue: base.title)
_category = State(initialValue: base.category)
_content = State(initialValue: base.content)
_isFavorite = State(initialValue: base.isFavorite)
_selectedTagIDs = State(initialValue: selectedTagIDs)
_variableDrafts = State(
    initialValue: variableDefinitions
        .map(TemplateVariableDraft.init)
        .sorted { $0.order < $1.order }
)
```

`MainView` 打开编辑器时又明确传入当前提示词的标签和变量定义：

```swift
selectedTagIDs: Set(tags.filter { tag in
    editorPrompt.map { tag.promptIDs.contains($0.id) } ?? false
}.map(\.id)),
variableDefinitions: variableDefinitions.filter {
    $0.promptID == editorPrompt?.id
}
```

保存时生成的新 `draft` 使用的是 `_selectedTagIDs` 和 `_variableDrafts`，不是 `base` 中的空数组：

```swift
PromptDraft(
    title: title,
    category: category,
    content: content,
    isFavorite: isFavorite,
    tagIDs: selectedTagIDs,
    variableDefinitions: variableDrafts,
    newTagNames: newTagNames
)
```

全仓搜索也确认 `PromptDraft.init(prompt:)` 只有这一个调用点。

### 裁决

**DeepSeek 的 P0 结论不成立。**

初始化器自身不是一个“完整聚合快照”接口，但当前编辑器有意把关系数据分开注入。正常的“打开已有提示词 → 修改 → 保存”不会因为该初始化器而丢失标签或变量定义。

合理动作不是加入会误伤“无标签/无变量提示词”的 `precondition`，而是：

- 添加一项端到端回归测试，固定当前调用约定。
- 可选地把初始化器改名为更准确的 `init(promptFields:)`，降低以后误用的概率。

最终级别：**误报；补测试，不按 P0 修复。**

## 4. 第二轮：删除提示词是否留下孤立数据

### DeepSeek 观点

单条删除只删除 `Prompt`；批量删除只清理标签并删除 `Prompt`，没有删除版本历史和变量定义。

### Codex 复核

该结论有直接代码证据：

```swift
static func delete(
    prompts: [Prompt],
    tags: [PromptTag],
    in context: ModelContext
) throws {
    let ids = Set(prompts.map(\.id))
    for tag in tags {
        tag.promptIDs.removeAll(where: ids.contains)
    }
    for prompt in prompts {
        context.delete(prompt)
    }
    try saveOrRollback(context)
}
```

`PromptVersion` 和 `TemplateVariableDefinition` 通过 `promptID` 手动关联，没有 SwiftData 级联删除。单条删除路径也没有统一进入上述服务。

实际影响是：

- 数据库留下无法从 UI 访问的历史记录和变量定义。
- 数据库体积可能缓慢增长。
- 不会删除其他仍存在的提示词，也不会立刻破坏当前资料库。

### 裁决

**问题成立，但严重度应从 P1 调整为 P2。**

修复应统一单条和批量删除路径，并在同一事务中：

1. 从所有标签移除提示词 ID。
2. 删除对应 `PromptVersion`。
3. 删除对应 `TemplateVariableDefinition`。
4. 删除 `Prompt`。
5. 保存失败时整体回滚。

智能集合引用的是标签 ID 和筛选条件，不直接引用 Prompt ID，因此删除提示词时无需清理智能集合。

## 5. 第三轮：变量切换是否会损坏正文

### DeepSeek 观点

`setRepeatable` 使用 `replacingOccurrences`，会替换正文中所有 `{{name}}`，包括示例或代码块中的文本，属于 P1 数据损坏。

### Codex 复核

PromptDock 的模板语法定义是：正文里出现的每个 `{{name}}` 或 `{{name[]}}` 都是占位符。当前没有转义语法，也没有“代码块中的占位符不生效”的规则。

产品计划还明确要求：

> 切换普通/可重复类型时，统一更新正文中的同名占位符。

因此全量替换同名占位符正是既定行为。即使改用模板解析器，解析器也会把所有相同语法识别为模板字段，结果不会改变。

### 裁决

**不是缺陷，是符合规格的实现。**

如果未来希望正文展示字面量 `{{name}}`，需要先设计转义语法，例如 `\{{name}}`，并同步更新解析、预览、复制和迁移逻辑；本轮不应仅修改 `setRepeatable`。

最终级别：**误报 / 新需求候选。**

## 6. 第四轮：SwiftUI 是否不会刷新或会错选

### 6.1 `let prompt: Prompt?` 是否不会重绘

#### DeepSeek 观点

`PromptDetailView` 使用 `let prompt: Prompt?`，没有 `@ObservedObject` 或 `@Bindable`，因此模型改变后详情不会刷新。

#### Codex 复核

`Prompt` 是 SwiftData `@Model`，在 macOS 14+ 使用 Observation。SwiftUI 在 `body` 读取模型属性时会追踪这些访问。`@Bindable` 用于生成可写绑定，不是读取更新的必要条件；`@ObservedObject` 是旧 Combine 模型的机制，也不能直接这样套在可选 SwiftData 模型上。

父视图还持有 `@Query`，模型变更会推动父子视图重新计算。

#### 裁决

**结论错误。** 不应为了消除误报而改写数据流。

### 6.2 内联 `Binding(get:set:)` 是否必然重置选择

#### DeepSeek 观点

每次 `body` 重算都会创建新的 Binding，所以 List 会闪烁或错选。

#### Codex 复核

`Binding(get:set:)` 是 SwiftUI 官方和常见的适配方式。视图身份由视图结构和显式 ID 等决定，不由 Binding 值的实例地址决定。报告没有给出可复现步骤或 SwiftUI 文档依据。

用户此前报告的“启动后首项高亮但编辑为空”属于主选中项与集合选择同步问题，不能反向证明这里的 Binding 构造本身有错。

#### 裁决

**证据不足，不能列为 P1。** 若未来出现可复现错选，应针对 `selectedPromptID` 与 `selectedPromptIDs` 的同步状态修复，而不是把标准 Binding 写法替换成第二套状态。

## 7. 第五轮：编辑器光标与并发编辑

### 7.1 `NSTextView` 光标跳转

#### DeepSeek 观点

`updateNSView` 直接执行 `textView.string = text`，没有保存普通选区，编程式更新后可能重置光标。

#### Codex 复核

代码只在存在 `selectionToken` 时显式设置选区。变量类型切换或 AI 内容写回等其他编程式变更没有恢复原来的 `selectedRange`。

#### 裁决

**问题成立，定级 P2。**

修复时应：

1. 写入新字符串前保存 `selectedRange`。
2. 写入后把范围限制到新文本长度内并恢复。
3. 如果存在 `selectionToken`，令 token 定位优先于旧选区。

### 7.2 Editor Sheet 是否持有“过期 Prompt”

#### DeepSeek 观点

Sheet 捕获 `editorPrompt`，另一个窗口修改后会被旧草稿覆盖，应判 P1。

#### Codex 复核

SwiftData `@Model` 是引用类型；捕获的不是值类型快照。另一方面，编辑器的文本字段本来就会在打开时形成草稿，以避免用户输入被后台刷新突然改写。这是标准编辑器行为。

真正存在的是一般性的并发编辑冲突：两个窗口同时编辑同一条记录时，后保存者覆盖先保存者。当前应用没有账号、云同步和多人编辑，这个窗口级冲突概率低，但可以加固。

#### 裁决

**原 P1 不成立；并发覆盖是 P3 加固项。**

建议打开编辑器时记录 `updatedDate`，接受 AI 改写或保存前若时间戳变化，则提示用户重新确认，而不是在 Editor 内再增加一个 `@Query`。

## 8. 第六轮：AI URL、SSRF 与 DNS 重绑定

### DeepSeek 观点

自定义 AI URL 允许私网、IPv6 环回和 DNS 重绑定，可能把提示词发送到攻击者控制的内部服务。

### Codex 复核

这是桌面应用，不是替陌生互联网用户发请求的服务器代理。URL 由本机用户在设置页主动输入，并且每次 AI 改写前都会展示服务商、模型和发送范围，由用户主动点击生成。

允许本地和私网 OpenAI 兼容服务是产品能力，例如 Ollama、LM Studio、局域网推理服务。若禁止私网地址，反而会破坏明确支持的自定义接口用途。

现有规则已经做到：

- 互联网地址必须使用 HTTPS。
- 明文 HTTP 仅允许 `localhost` 和 `127.0.0.1`。
- URL 禁止嵌入用户名和密码。
- URLSession 仍会执行 HTTPS 证书校验。
- 应用不会自动或后台发送提示词。

所谓 DNS 重绑定还需要攻击者先控制用户主动填写的域名及其 DNS；这不构成应用对远程非信任输入的 SSRF。

### 裁决

**三项 SSRF/DNS 重绑定结论均不适用于当前威胁模型。**

不应加入私网封锁、自定义 DNS 解析器或请求前后 IP 固定逻辑。更合适的安全边界是继续明确显示目标主机、仅在用户确认后发送，并保持互联网 HTTPS 要求。

## 9. 第七轮：AI 接受流程是否会误覆盖

### DeepSeek 观点

AI 改写接受没有额外确认对话框，可能误点覆盖正文；并可能覆盖另一个窗口的修改。

### Codex 复核

当前流程已经分为：选择目标 → 主动生成 → 查看原文/改写版 → 点击接受。最后的“接受改写”本身就是确认动作。接受后还会通过现有历史机制保存旧版本。

再增加系统确认框只会重复确认，降低效率。

并发覆盖与上一节相同，是低概率窗口级冲突，可通过 `updatedDate` 检查加固。

### 裁决

- “缺少确认”：**误报。**
- “并发覆盖”：**P3 加固项。**

## 10. 第八轮：数据模型和事务

### 10.1 没有 SwiftData `@Relationship`

#### DeepSeek 观点

UUID 手动关联缺乏引用完整性，应在公开测试前改成 `@Relationship`。

#### Codex 复核

这是当前 Schema V2 的明确模型设计，并非 SwiftData 不支持关系导致的疏漏。改成 `@Relationship` 会改变持久化模型，需要新增 Schema 版本和显式迁移，直接违反本阶段“沿用 Schema V2，不新增数据库迁移”的约束。

当前真实问题不是“必须换关系模型”，而是删除路径没有完成手动关联应有的清理。

#### 裁决

**架构建议，不是当前缺陷。** 本轮修复删除服务即可；是否迁移到关系模型应放进单独的数据迁移版本评估。

### 10.2 `restore` 直接 `context.save()`

#### DeepSeek 观点

恢复历史版本没有复用 `saveOrRollback`，失败时内存上下文可能保留未保存更改。

#### Codex 复核

成立。虽然调用方会显示错误，统一回滚语义更安全、也更容易维护。

#### 裁决

**P3 加固项。** 改成 `try saveOrRollback(context)`。

## 11. 第九轮：排序、收藏和智能集合

### 11.1 “最近更新”未排序

#### DeepSeek 观点

`filteredPrompts` 对输入直接 `prefix(20)`，可能返回最旧 20 条。

#### Codex 复核

`MainView` 的数据来源是：

```swift
@Query(sort: \Prompt.updatedDate, order: .reverse)
private var prompts: [Prompt]
```

当前调用链保证输入已经按更新时间降序，所以用户界面不会显示最旧 20 条。

#### 裁决

**当前缺陷不成立；建议做防御性 P3 加固。** 服务内部显式排序可避免未来新增调用方误用。

### 11.2 收藏是否应更新 `updatedDate`

#### DeepSeek 观点

收藏状态变化不更新时间，导致条目不会进入“最近更新”。

#### Codex 复核

这取决于产品定义。“最近更新”可以指正文/组织内容更新，也可以指任意元数据更新。当前批量标签添加同样不更新时间，说明实现倾向前一种语义。

#### 裁决

**产品语义问题，不是 P2。** 若产品决定所有元数据变更都算“更新”，应统一处理收藏和标签，而不是只改 `toggleFavorite`。

### 11.3 智能集合全文搜索“误报”

#### DeepSeek 观点

标题、分类和正文拼接后执行包含匹配，可能匹配到用户不期望的位置。

#### Codex 复核

智能集合的搜索词本来就定义为匹配标题、分类和正文；报告描述的是设计行为，没有给出违反规格的实例。

#### 裁决

**误报。** 若未来需要字段级筛选，应作为新功能设计。

## 12. 第十轮：Unicode Emoji

### DeepSeek 观点

`emoji.first` 只保留第一个 Unicode 标量，会破坏肤色、ZWJ 组合和旗帜。

### Codex 复核

Swift 的 `String.first` 返回 `Character`，而 `Character` 表示一个扩展字素簇，不是一个 Unicode scalar。

因此以下内容会作为一个 `Character` 保留：

- 带肤色修饰符的 Emoji。
- ZWJ 家庭/职业组合。
- 两个区域指示符组成的旗帜。

代码随后用 `character.unicodeScalars` 检查该完整字素簇是否含 Emoji 属性，逻辑与需求一致。

### 裁决

**语言语义误判，结论错误。** 不应修改现有实现；应保留对应测试来防止未来回归。

## 13. 其他问题逐项裁决

| 原报告条目 | 裁决 | 说明 |
|---|---|---|
| `SearchHighlightedText` O(n×m) | P3 性能观察 | 缺少基准数据，不是当前正确性缺陷；真正达到大数据量后再按 profile 优化 |
| 每次按键执行 `synchronizeVariables` | P3 性能观察 | 当前解析是本地线性操作，常规提示词规模可接受；先保留即时变量 UI |
| `isRepeatable` 被解析器覆盖 | 符合设计 | 正文语法是变量类型的唯一真相来源 |
| Keychain 可访问性与 Widget | 误报 | Widget 不读取 AI API Key；两者没有因果关系 |
| `promptRevision` 忽略标题/正文 | 误报 | 标题/正文保存会更新 `updatedDate`，revision 会变化并刷新搜索 |
| `CategoryIconPreview` 固定 folder | 非本轮缺陷 | 自定义分类编辑只提供 Emoji/本地图片；内置 SF Symbol 分类不允许编辑 |
| Widget 快照没有 schema version | 未来兼容建议 | 当前结构未发生不兼容变化；需要改格式时再加入版本和兼容解码 |
| Bootstrap 详情暴露类型名 | 低风险且有意 | 仅本地恢复页供用户复制诊断，不上传、不展示给远程用户 |
| OSLog 使用 `.public` | P3 日志卫生 | 应确保错误不含隐私数据，但这不是 API Key 泄露证据 |
| `xcstrings` 中 new/stale | P3 发布卫生 | 做专门本地化检查即可，不构成数据或安全问题 |
| Widget 没有多样时间线/收藏优先 | 功能建议 | 不属于缺陷 |
| `CopyPromptIntent` 允许空字符串 | P3 边界体验 | 可加空内容保护，但正常快照不会产生空提示词 |
| 后端 `auth.js` / `auth.test.js` | 范围外 | `5bbfe00` 没有修改后端文件 |
| Turnstile 反馈表单 | 范围外 | 属于 CueGrove 网站，不属于 PromptDock 1.2 应用提交 |

## 14. 最终整改清单

### 合并前建议完成

1. 统一单条和批量删除入口。
2. 删除提示词时清理标签 ID、历史版本和变量定义，并在保存失败时整体回滚。
3. 添加删除清理集成测试。
4. 添加“编辑已有提示词后标签和变量定义保持不变”回归测试。
5. `SelectablePromptTextEditor` 在编程式文本变化时保存并恢复合法选区。
6. `Phase1Service.restore` 使用 `saveOrRollback`。
7. “最近更新”在 `filteredPrompts` 内显式按 `updatedDate` 降序排序后取前 20 条。

### 可以随后加固

1. 编辑器或 AI 改写打开时记录原始 `updatedDate`，接受前发现变化则提示冲突。
2. 给 `CopyPromptIntent` 增加空正文保护。
3. 发布前完成一次中英文字符串和 VoiceOver 标签检查。

### 明确不做

1. 不把 UUID 关联立即改成 `@Relationship`，避免无计划的 Schema 迁移。
2. 不屏蔽局域网或本机 AI 服务地址。
3. 不实现自定义 DNS 解析与 DNS pinning。
4. 不为 AI“接受改写”再叠加一个重复确认框。
5. 不重写 Swift Emoji 截取逻辑。
6. 不为 List 引入第二套本地选择状态。

## 15. 给 DeepSeek 的复审要求

可将下面内容连同本报告发给 DeepSeek：

> 请针对本报告逐项复审你之前的 PromptDock 1.2 审计结论。必须沿着实际调用链验证，不得仅根据初始化器或属性声明推断行为。重点回答：
>
> 1. 在 `EditorView` 独立注入 `selectedTagIDs` 和 `variableDefinitions` 后，原 P0 是否仍有可触发调用路径？请列出具体调用点。
> 2. 请解释 SwiftData `@Model` 在 SwiftUI Observation 中是否必须使用 `@ObservedObject`，并提供适用于 macOS 14+ 的依据。
> 3. 请解释 Swift `String.first` 返回的是 `Character` 还是 Unicode scalar，并重新判断 ZWJ/旗帜结论。
> 4. 在自定义 URL 由桌面端本机用户主动配置、局域网模型属于支持场景时，请重新定义 SSRF 的攻击者与非信任输入来源。
> 5. 请将提交 `5bbfe00` 没有修改的后端和网站问题移出本轮风险统计。
> 6. 对仍坚持的 P0/P1，请给出可执行复现步骤、完整调用链和会受损的持久化记录；没有这些证据时请下调等级。

## 16. 最终裁决

DeepSeek 的审计有价值，因为它准确指出了删除清理和 `NSTextView` 光标管理两个盲点；但其执行摘要的风险统计不可靠，原因主要是：

- 没有完成 `PromptDraft` 的真实调用链核对。
- 对 SwiftUI Observation 和 Swift `Character` 的语义判断错误。
- 没有先确定桌面端自定义 AI 接口的威胁模型。
- 把功能建议、未来兼容性、产品语义和范围外后端问题混入当前发布阻断项。

PromptDock 1.2 当前不应被描述为存在 P0/P1。完成第 14 节的七项小范围整改后，可继续进入合并候选和 DMG 阶段；无需进行 Schema 重构、网络栈重写或大规模 UI 状态重构。
