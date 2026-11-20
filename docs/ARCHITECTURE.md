# iOS 架构边界与当前实现

更新：2026-11-20。最低 iOS 17，原生 SwiftUI。当前为单模块工程，职责分层见下表；后续需要时再拆 SPM 包或 framework，拆分不改变依赖方向。

```text
Features / SharedUI
        ↓
App 中的导航与依赖组装 → Domain 用例与接口
                              ↑
                  Data 与 Platform 的可替换适配
```

| 目录 | 责任 | 禁止耦合 | 当前内容 |
|---|---|---|---|
| App | 依赖组装、会话启动/失效、导航和深链上下文 | 不集中实现全部业务或保存明文密码 | `AppSession`、`AppEnvironment`、`RootView`、`MainTabView`、配置 |
| Domain | 领域模型、错误、权限投影、业务端口和幂等规则 | 不依赖 SwiftUI/UIKit、HTTP DTO 或存储 SDK | `User`、`CapabilitySnapshot`、`AppError`、分页、`AuthService`/`CatalogService`、格式化 |
| Data | 既有 API 的 DTO 映射、错误/分页/时间/金额解析、缓存和持久化 | 不绕过后端，不向页面泄露数据库实体 | `APIClient`、`APIRequest`、包络/错误映射、CookieJar、CSRF、`RemoteAuthService`、`RemoteCatalogService` |
| Platform | Keychain、相册/文件、系统分享、剪贴板、通知及生命周期 | 不决定审核、处罚、账号资格等业务结论 | `KeychainStore`、`KeychainCookieArchive`、安装标记；相册/通知待接入 |
| Features | 按功能组合用例和界面状态，处理输入与重试 | 不拼通用万能 action，不把所有页面塞进一个大对象 | 登录/验证码、食堂→档口→菜品、个人页、受限申诉占位 |
| SharedUI | 手账色彩/字体/图标、空错状态、图片与可访问控件 | 不直接执行领域写操作或隐藏服务端错误 | `Zine` 令牌、纸质背景、`PaperCard`、`InkButtonStyle`、加载/空/错状态 |

层边界由 `scripts/check_ios_architecture.py` 静态检查：Domain 不得引用 SwiftUI/UIKit/网络/Keychain；Data 不得引用页面；Platform 不得引用业务 HTTP；Features/SharedUI 不得直接使用 URLSession、Keychain、APIClient。检查是护栏，不是编译器；代码审查仍以本文件为准。

## 共用后端的契约

- 复用 `/api/v1`、`ApiResponse`、Cookie 会话、CSRF、能力、revision、错误码和幂等标识。
- 数据传输对象、领域对象和界面状态分开；服务地址、系统能力和存储实现通过注入替换。
- 普通分页与 cursor 分页分别建模；金额用 `Decimal` 且 null 不当 0；时间携带时区并遵守 UTC+8 展示。
- 服务地址、系统能力和存储实现通过注入替换；本机测试不能默认写入生产服务。
- 共享文件和图片关联失败时复用合法上传引用，避免重复提交；先验证上传所属账号。

## 会话、并发与缓存

- `AppSession` 是页面级身份状态的唯一入口：启动恢复、登录、退出、401、能力快照和受限申诉状态。
- `APIClient` 用 `SessionEpoch` 校验迟到响应；退出/401/切号会旋转 epoch，旧响应抛 `staleSession`，不得写入新账号。
- Cookie 按服务源保存；URLSession 负责请求期 Cookie，Keychain 只做同源归档。退出只清 `FOODTIME_SESSION`，保留 `foodtime_device`。
- 能力快照含 `capabilities`+`revision`；读取失败保持空并可重试，退出/切号/角色变化清空。管理入口只按能力名显示，服务端仍逐次校验。
- 204/205 空 body 视为成功；写请求不自动重试，靠 `clientRequestId`/`expectedRevision` 等业务幂等。

## 导航与页面状态

- 每个 Tab 独立 `NavigationStack`；当前只接入“食堂”和“我的”，社区/管理随波次增加。
- 页面用 `@StateObject` 持有本页状态，读取成功后才替换数据；网络/5xx 保留旧内容，401 清空。
- 加载、空、错三种状态必须显式设计；错误提供重试，不用占位数据冒充成功。
- 食堂→档口→菜品页面只读，不写库、不伪造评分或价格。

## 设计与资源

- 色板/字号/圆角/阴影集中在 `Sources/SharedUI/Theme.swift`，页面不新写十六进制色值。
- 保持浅色纸张主题、墨棕描边、硬边投影和手账层级；移动端触控目标不小于 44pt。
- 字体、地图、插画、平面 Emoji 尚未接入；复用前先核对 OFL/来源许可，并保留许可说明。
- 动态字体、VoiceOver、安全区、iPad/横屏属于 W7 专项，不能以当前 iPhone 布局通过代替。

## 测试

- `Tests/Unit`：网络包络/错误、204、CSRF、会话状态、金额/时间格式化；用 `StubHTTPTransport`，不连真实服务。
- 后续增加 Domain/Data 契约测试、真实测试后端联调、Apple Simulator UI 测试与真机平台测试。
- 仓库检查与 macOS 编译/单测都不能替代业务验收；未执行的项目如实记录。
