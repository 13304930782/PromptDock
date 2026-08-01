# PromptDock 开发路线

## 总体方向

PromptDock 的长期定位是：面向学生与个人创作者的本地优先、跨平台、可协作 AI 提示词工作台。

发展原则：

- 当前本地功能永久免费、无需账号，并且在服务器不可用时仍能正常使用。
- 下一客户端优先 iPhone 和 iPad，之后通过 Web/PWA 覆盖 Windows、Linux 等平台。
- 当前 AI 第一阶段只提供用户主动触发的模板生成；后续再增加提示词改写、评估和版本对比，不扩张成通用聊天软件。
- 云同步采用端到端加密；只有用户主动点击 AI 功能时，当前文本才临时发送处理。
- 实时协作以“共享资料库”为单位，放在个人同步和 iOS 稳定之后。
- 在线服务按“全球区”和“中国大陆区”分离部署：共用接口规范和数据格式，但不共用数据库，不默认跨境复制用户数据。
- 默认按个人开发者 18–24 个月的节奏推进；在线内测初期限制在 50 人以内，并设置严格的云成本上限。

## Phase 0：稳定发布 1.0（现在至 1 个月）

- 先交付 `1.0.0` Build 2（RC3）：提交模板变量、可选 AI 模板助手和隐私说明修正，确认 GitHub CI 通过。
- 使用 DMG 完成主窗口、快搜、备份往返、Widget、重启、覆盖安装和干净安装测试。
- 暂停增加大型功能，只处理数据安全、崩溃、快捷键和 Widget 问题。
- 第一周招募 5 名测试用户，没有阻断问题后扩大到最多 10 名；通过用户主动提交的反馈收集问题，不接入广告或行为分析 SDK。
- Early Access 阶段由用户提供 DeepSeek 或兼容服务 API Key；密钥保存在 Keychain。只有用户明确确认后，当前需求和模板语法手册才会发送给所选服务商。

发布门槛：连续两周没有已知的数据丢失、启动阻断或备份无法恢复问题；覆盖安装保留数据，AI 发送范围与隐私说明一致。

## Phase 1：本地专业能力与共享核心（1–3 个月）

- 在仓库中建立 `PromptDockCore` Swift Package，抽离模型 DTO、搜索、模板解析、版本管理和 Repository 协议，供 macOS 与未来 iOS 共用。
- 将现有 `{{variableName}}` 和 `{{variableName[]}}` 模板语法升级为可持久化的变量定义，保存标签、默认值、顺序和重复项配置，同时兼容当前正文解析方式。
- 新增标签、智能集合和提示词版本历史；手动保存、接受 AI 修改和备份导入都生成可恢复版本。
- 新增 `PromptDockSchemaV2` 和 V1→V2 显式迁移，创建默认个人资料库并保留现有 ID、分类、图片和提示词内容，不直接修改 V1。
- 备份格式升级为版本 2，同时继续兼容版本 1。

发布门槛：V1 数据迁移、V1/V2 备份往返和 100,000 条数据压力测试全部通过。

## Phase 2：账号与端到端个人同步（4–6 个月）

- 首期只开放全球测试区：后端采用 Supabase Auth、PostgreSQL、Row Level Security 和 Realtime，Cloudflare 用于 DNS、CDN、WAF 和公开静态资源分发，降低个人开发者的运维成本。[Supabase Swift 文档](https://supabase.com/docs/reference/swift/installing)
- Cloudflare CDN 只缓存官网、文档、DMG 和其他公开静态资源；不缓存登录、加密同步、提示词或 AI 请求。
- 提供邮件魔法链接登录；取得付费 Apple Developer 账号后增加“通过 Apple 登录”。
- 不使用 CloudKit 作为核心同步层，避免未来被限制在 Apple 平台；SwiftData CloudKit 同步本身也需要相应开发者能力。[Apple SwiftData 同步说明](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- 每个资料库生成独立 AES-GCM 密钥；设备私钥保存在 Keychain，服务器只保存密文、加密密钥包和必要元数据。[Apple CryptoKit AES-GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm)
- 首台设备生成 24 词恢复短语；新设备通过已有设备批准或恢复短语取得解密能力。服务器和账号密码不能恢复遗失密钥。
- 离线时继续读写本地 SwiftData，恢复网络后按操作日志同步，网络错误不能阻止本地使用。

发布门槛：两台设备在断网、乱序、重复消息和同时编辑后最终一致；服务器数据库不能出现提示词明文。

## Phase 2.5：中国大陆独立服务区（全球同步稳定后）

- 在出现稳定的中国大陆测试需求前，不提前承担大陆云资源和备案成本。
- 腾讯云或阿里云二选一，不同时维护两套大陆云；使用其大陆 CDN、对象存储、API 服务和数据库。
- 普通 Cloudflare 全球网络不作为中国大陆 CDN。Cloudflare China Network 属于企业级服务，需要 ICP 备案等条件，不作为个人开发初期方案。[Cloudflare China Network](https://developers.cloudflare.com/china-network/)
- 大陆公网服务上线前完成适用的 ICP 备案、APP 备案、隐私政策、用户协议和数据处理检查。[工信部 APP 备案通知](https://www.miit.gov.cn/zwgk/zcwj/wjfb/tz/art/2023/art_920db564162e4312916a01bed6540ad8.html%EF%BC%9B)
- 建议域名分区：`api.promptdock.app` 和 `download.promptdock.app` 服务全球区；`api-cn.promptdock.app` 和 `download-cn.promptdock.app` 服务中国大陆区。
- 账号创建时让用户明确选择“全球区”或“中国大陆区”，保存为不可被地理 IP 静默改变的 `homeRegion`。
- 两区共用 OpenAPI 接口、客户端模型、加密格式和数据库迁移规范，但账号、数据库、对象存储、日志和密钥服务物理分离。
- 不自动跨境复制账号、成员关系、用量或日志。端到端加密可以保护提示词正文，但不代表账号和其他元数据自动免除跨境合规要求。
- 中国大陆区的 AI 请求默认只调用境内合规且已完成所需备案的模型服务；不默认将大陆用户的明文发送给境外模型。
- 同一版本的网站资源和 DMG 按哈希校验后，分别发布到 Cloudflare R2 与大陆 COS/OSS，确保两区的公开下载内容一致。

发布门槛：备案与隐私文档已完成，大陆数据不会被默认跨境复制，同一账号不会被 DNS 或 IP 定位自动切换数据库，大陆 API 在真实网络环境下完成同步和故障恢复测试。

## Phase 3：AI 改写、评估与订阅（7–9 个月）

- 建立服务端多模型网关，客户端只依赖统一的 `AIReviewService`，可按成本、质量和地区切换模型供应商。
- AI 返回固定结构：总分、清晰度、上下文、约束、输出格式、问题列表、改进版本、模型和供应商标识。
- AI 结果先显示差异对比；用户接受后创建新版本，不直接覆盖原文。
- 只有用户点击“评估”或“改写”时才解密并发送当前版本；网关不记录正文，只记录请求时间、模型、token、错误和费用。
- 免费账号初始每月提供 20 个标准 AI 积分；Plus 初始每月提供 500 个积分，不允许无提示超额扣费。
- Apple 平台使用 StoreKit 2；服务器通过 App Store Server API 和通知维护跨 macOS、iOS 权益。[Apple 订阅说明](https://developer.apple.com/documentation/StoreKit/handling-subscriptions-billing)
- 初始产品标识使用 `promptdock.plus.monthly` 和 `promptdock.plus.annual`；具体价格在发布前根据实际模型成本决定。

发布门槛：模型失败可安全重试或切换供应商，配额不能被客户端绕过，日志和错误报告不包含提示词正文。

## Phase 4：iPhone 与 iPad（10–12 个月）

- 新增原生 SwiftUI iOS/iPadOS Target，复用 `PromptDockCore`、加密、同步和 AI 接口。
- 首版包含资料库、精确搜索、模板变量填写、复制、收藏、AI 评估、离线缓存和 Widget。
- iPad 使用三栏布局；iPhone 使用列表—详情导航，不直接照搬 macOS 界面。
- 增加 Share Extension，将浏览器或其他应用中的文本保存为新提示词。
- 暂不加入复杂批量操作和实时光标，优先保证浏览、编辑、复制和同步可靠。

公开 TestFlight 和 App Store 发布作为加入付费 Apple Developer Program 的明确预算节点。

## Phase 5：端到端实时协作（13–18 个月）

- 协作单元固定为共享资料库，角色为 Owner、Editor 和 Viewer。
- 使用 Automerge 文档及其传输无关的同步协议：一个资料库清单文档管理分类、标签、顺序和提示词引用，每条提示词使用独立文档。[Automerge Swift 同步文档](https://automerge.org/automerge-swift/documentation/automerge/sync/)
- Realtime 只转发加密后的 Automerge 消息；PostgreSQL 保存加密快照和操作日志。
- 资料库密钥分别包装给每位成员；移除成员时轮换未来版本的密钥。
- 界面必须提示：成员已经解密、复制或导出的历史内容无法被远程收回。
- AI 请求由发起者设备主动解密并提交；服务器不能自动读取整个共享资料库。
- 支持实时正文合并、在线状态、评论和版本恢复；暂不加入语音、聊天和企业审批流。

发布门槛：至少五个设备在并发编辑、掉线重连、成员移除和密钥轮换后收敛且没有越权读取。

## Phase 6：Web/PWA 与更广平台（19–24 个月）

- 使用与 Apple 客户端相同的同步协议、加密格式和 Automerge 文档结构实现 Web/PWA。
- 首先覆盖 Windows/Linux 浏览器和移动浏览器；只有出现明确的系统级快捷键或桌面集成需求时再开发 Windows 原生客户端。
- 恢复短语、密钥包装、备份格式和 AI API 必须保持跨平台兼容。
- 社区模板市场、公开发现和内容评分继续延后，等账号、同步、付费和协作稳定后单独立项。

## 核心接口与数据边界

客户端核心接口：

- `PromptRepository`：本地增删改查、版本和标签。
- `LibraryRepository`：个人及共享资料库、成员和权限。
- `SyncEngine`：操作队列、离线重试、快照和收敛状态。
- `LibraryCryptoService`：资料库密钥、设备密钥、恢复短语和成员密钥包装。
- `AIReviewService`：版本化的改写与评估请求和响应。
- `EntitlementService`：免费额度、订阅状态和权益缓存。
- `AccountService`：登录、设备登记、账号导出和删除。

后端接口统一置于 `/v1`：

- `/auth`：身份交换与设备登记。
- `/sync`、`/realtime`：加密快照、操作日志和 WebSocket 消息。
- `/ai/review`：用户主动发起的 AI 改写与评估。
- `/entitlements`：订阅和额度。
- `/account/export`、`/account/delete`：数据可携带和账号删除。

服务器允许读取账号、成员关系、时间、对象大小、额度和计费元数据，但不得读取提示词、分类名称、标签、评论或版本正文。

区域路由与数据边界：

- `Region.global` 与 `Region.chinaMainland` 是客户端和服务端共享的类型，账号的 `homeRegion` 决定 API、WebSocket、AI 和账单端点。
- CDN 和智能 DNS 可以为公开资源就近分发，但不得为已登录账号改变 `homeRegion` 或数据库。
- 跨区迁移、跨区共享资料库和跨区实时协作单独立项；在合规、密钥转移、失败回滚和用户明示授权完成前不开放。

## 测试与验收

- 数据：V1→V2 迁移、V1/V2 备份兼容、失败回滚、超大资料库和损坏文件。
- 加密：固定测试向量、篡改检测、错误密钥、恢复短语、新设备批准和密钥轮换。
- 同步：重复、乱序、断线、并发修改、长期离线和服务器重建。
- 权限：RLS 越权、成员移除、邀请过期、Viewer 写入拒绝和账号删除。
- AI：结构化响应验证、供应商故障转移、正文日志检查、配额和成本上限。
- 付费：StoreKit 沙盒购买、续订、退款、宽限期、恢复购买和跨设备权益。
- 客户端：macOS、iPhone、iPad 无障碍、深浅色、后台恢复、Widget、Share Extension 和低内存。
- 正式上线前进行独立安全审查，并确认数据库、日志、备份和供应商控制台均无提示词明文。

## 暂不开发

- 广告和用户行为分析 SDK。
- 公开提示词社区与内容市场。
- 企业 SSO、组织审计和复杂审批流。
- 通用 AI 聊天客户端。
- 自建大模型推理集群。
- 在完成备案、跨境数据评估和明示用户授权前开放跨区账号自动迁移或跨区共享。
- 同时运营腾讯云和阿里云两套中国大陆后端。
- 在同步和账号体系稳定前开发 Windows 原生客户端。
