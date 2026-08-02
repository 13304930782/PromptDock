# PromptDock `main` 审查整改报告

**审查基线**：`main` / `b5acc09`
**整改日期**：2026-08-02
**输入报告**：`promptdock-main-review.md`
**整改原则**：优先修复可利用的安全问题和可复现的可靠性问题；对误报给出代码依据，不为了“消除报告条目”增加无用抽象。

## 结论

原报告中的 2 个 High 问题均已处理：

- 管理员会话增加服务端版本校验，密码重置、MFA 变更和登出均可立即吊销旧 JWT。
- 键盘布局读取移除了 `unsafeBitCast`；Carbon 回调继续使用 `passUnretained`，因为事件处理器在对象销毁前被移除，改为 `passRetained` 反而会制造泄漏。

11 个 Medium 项中：8 项已整改或加固，3 项经代码核对属于误报或现有实现已经满足要求。低优先级项按风险处理，没有对正常的本地存储、系统剪贴板和用户主动导出的明文备份做破坏性改造。

本轮没有修改 SwiftData Schema，也没有引入 Redis、第三方 CSRF 库或新的运行时依赖。

## High 整改

| 编号 | 状态 | 整改结果 |
|---|---|---|
| H1 JWT 无法吊销 | 已修复 | 新增 `admin_users.token_version`；JWT 携带版本；认证中间件每次与数据库比对。密码重置、MFA 开启/关闭、登出、owner 重置其他管理员密码和命令行重设管理员密码时均递增版本。旧版不含版本字段的 JWT 自动失效。 |
| H2 `unsafeBitCast` / Carbon 指针 | 已修复并校正建议 | 使用 `Unmanaged.fromOpaque(...).takeUnretainedValue()`、`NSData` 条件转换和长度检查读取键盘布局数据。保留 `passUnretained(self)`：handler 在 `deinit` 中先注销，生命周期闭合；`passRetained` 若无精确 release 会产生泄漏。 |

### H1 的行为变化

- 部署数据库迁移后，现有管理员会话会被要求重新登录，这是预期的安全行为。
- MFA 密码阶段成功不再提前清零失败计数；MFA 失败同样累计，连续 5 次失败后锁定 15 分钟。
- 登出接口需要有效管理员会话，并在清除 cookie 前使当前版本失效。
- MFA challenge 也绑定 `token_version`，账号安全状态变化后旧 challenge 无法继续使用。

## Medium 整改

| 编号 | 状态 | 结论与处理 |
|---|---|---|
| M1 Early Access 设置权限 | 已修复 | 写接口 `PUT /settings/early-access` 改为仅 owner。读接口保留已登录管理员可用，因为审批界面需要读取非敏感的可用状态；普通管理员无法修改 URL、cohort 或通知邮箱。前端也隐藏非 owner 编辑表单。 |
| M2 MFA 重置脚本 | 已修复 | 仅允许 TTY 交互运行，要求重新输入目标邮箱确认；操作后递增 `token_version`，并记录时间、系统用户和目标邮箱。删除了无意义的当前进程环境变量清理。 |
| M3 反馈 token 位于 URL | 已修复并兼容旧邮件 | 新邮件使用 `/feedback/portal#token=...`；fragment 不会发送到服务器。页面通过 POST body 将 token 交换为 `HttpOnly`、`Secure`、`SameSite=Strict` cookie，并立即清理地址栏。旧 `/feedback/:token` 邮件链接继续可用，进入后同样完成交换和清理。 |
| M4 CSRF | 已加固 | 现有服务端已对所有写请求强制校验同源 `Origin`，并要求自定义请求头；管理员 cookie 进一步改为 `SameSite=Strict`。当前是同域应用，不再引入同步 token 和额外状态。 |
| M5 SMTP 密码静默缺失 | 原报告已过时 | 当前实现已在启用认证邮件且缺少用户名/密码时拒绝保存；不重复增加第二套校验。 |
| M6 邮件状态无认证 | 误报并进一步收紧 | `admin` router 在该路由之前已经统一执行 `requireAdmin`，端点并非公开。本轮进一步改为 `requireOwner`。 |
| M7 历史记录无限抓取 | 已修复 | SwiftData `FetchDescriptor` 增加 `fetchLimit = Phase1Service.maximumPromptVersions`，界面最多加载 50 条。 |
| M8 分类删除部分保存 | 误报 | SwiftData `ModelContext.save()` 是事务提交，失败后现有代码调用 `rollback()`；不存在报告描述的“部分 save 成功后 rollback 不完整”。未添加容易与模型状态冲突的手工快照。 |
| M9 审批无确认 | 已修复 | 批准和拒绝前均显示包含申请人姓名和不可逆提示的确认框。 |
| M10 API Key CR/LF | 已修复 | 去除首尾空白后拒绝仍含 CR/LF 的 Key；新增单元测试。 |
| M11 UUID 提示状态竞争 | 误报 | 旧任务只有在 token 仍是自己时才清状态；最新任务最终会清除最新 token，不会永久卡住。改成可取消 Task 会增加 4 组状态而没有修复实际问题，因此保留现有实现。 |

## Low 项处理

### 已整改

| 编号 | 处理 |
|---|---|
| L4 | 自定义 AI URL 现在拒绝内嵌用户名或密码，避免凭证随 URL 明文进入 UserDefaults。 |
| L6 | owner 重置管理员密码时写入包含时间、操作者和目标用户的审计日志，并吊销目标账号旧会话。 |
| L13 | 图片解码前通过 ImageIO 校验像素尺寸，拒绝超过 16384 边长或 1 亿像素的图片，降低解压炸弹风险。 |
| L15 | Turnstile 网络异常记录错误类型，不记录 token 或表单隐私内容，仍然 fail closed。 |
| L16 | MFA 失败纳入登录失败计数和锁定机制。 |
| L20 | 反馈状态更新后的刷新改为顺序执行，避免 `Promise.all` 导致详情读取旧数据。 |

### 经核对无需修改

| 编号 | 原因 |
|---|---|
| L1 | 本地 SwiftData 明文是产品当前的明确存储模型；应用已经说明数据保存在本机。数据库加密需要独立密钥生命周期设计，不能作为小补丁加入。 |
| L2 | JSON 是用户主动导出的可移植备份；改为专有加密格式会破坏恢复与互操作。 |
| L3 | “复制提示词”本来就必须写入系统剪贴板；这是功能边界，不是实现缺陷。 |
| L8 | React 默认转义文本，服务端保存原文有利于正确往返；在输入端做 HTML 清洗反而可能损坏普通文本。 |
| L9 | 产品此前明确选择不限制编辑器标题和正文长度；外部文件导入已有资源边界。 |
| L10 | Swift 的 `.first` 返回 `Character`，`Character` 是扩展字素簇；肤色、ZWJ 家族和旗帜不会按 Unicode scalar 截断。 |
| L14 | ViewModel 将保存错误抛给界面是正常错误传播，不应在中间层静默吞掉。 |
| L17 | 静态、编译期固定且已有测试覆盖的正则初始化失败属于编程错误；不是用户输入可触发路径。 |
| L18 | 启动恢复页由用户主动点“重试”，不存在后台无限自动重试。 |
| L21 | `React.memo` 的浅比较已经适用于当前 props；没有证据显示自定义比较函数会带来收益。 |

### 保留为后续度量项

| 编号 | 后续条件 |
|---|---|
| L5 | 邮件设置对象只通过 owner 端点返回；若未来增加非 owner 邮件运维角色，再拆分公开状态 DTO。 |
| L7 | TOTP SHA-1 是 RFC 6238 和主流 Authenticator 的兼容默认值；只有在客户端生态确认支持后再提供 SHA-256。 |
| L11 | 快搜重建先做 Instruments 测量；没有性能数据前不引入节流状态。 |
| L12 | Forward Delete 键码属于当前 macOS 虚拟键码处理；未来若扩展特殊键录制，再集中抽取符号常量。 |
| L19 | 本轮新增会话版本和反馈 token 流程测试；完整数据库集成测试仍应随 CI 测试数据库环境建设推进。 |

## 其他可靠性加固

- 自定义 AI 服务 URL 除 HTTPS/允许的 HTTP 规则外，额外拒绝 URL userinfo。
- Early Access 批准和拒绝操作增加明确的不可逆确认。
- 反馈管理状态变化和回复后的刷新顺序固定，避免界面显示旧线程。
- 新反馈链接不把 secret 放在 query/path，服务器日志、CDN 请求 URL 和 Referer 不再获得新 token。

## 测试与验证

| 检查 | 结果 |
|---|---|
| `git diff --check` | 通过 |
| 后端 JavaScript 语法检查 | 通过 |
| 后端单元测试 | 27/27 通过；其中 `app.test.js` 需要正常本地监听权限运行 |
| 新增 JWT 版本测试 | 通过：版本匹配、版本不匹配、旧 JWT 无版本三种情况 |
| 新增反馈 URL 测试 | 通过：token/report 只存在于 fragment，不在 path/query |
| TypeScript `tsc --noEmit` | 通过 |
| Vite 生产构建 | 通过，1678 modules transformed |
| macOS Debug 构建 | `BUILD SUCCEEDED`（主应用与 Widget，无签名构建） |
| macOS 单元测试 | 本次命令行环境未取得完整结果：无签名 runner 无法启动；签名 runner 结束测试阶段后卡在 Xcode 的 `waiting for record to finish saving`，结果包没有完成，不能宣称通过或断言失败。运行时系统中另有已安装 PromptDock 正在运行。合入前应退出正在运行的 PromptDock 后在 Xcode 中再次执行 Test。 |

## 上线注意事项

1. 必须先执行数据库迁移 `006_admin_session_version.sql`，否则新认证中间件无法读取 `token_version`。
2. 迁移上线后所有管理员需要重新登录。
3. 已发送的旧反馈链接仍可用；新发送邮件自动使用 fragment + cookie 流程。
4. 部署后检查密码重置、MFA 开关、登出、owner 重置密码是否立即使旧 cookie 失效。
5. 本轮没有 Nginx 配置变化。

## 未纳入本轮整改的工作区改动

以下修改在整改开始前已存在，已原样保留，不能归因于本报告：

- `PromptDock.xcodeproj/project.pbxproj` 的 Widget Release 签名设置。
- `PromptDock/Views/MainView.swift` 的编辑器请求修复。
