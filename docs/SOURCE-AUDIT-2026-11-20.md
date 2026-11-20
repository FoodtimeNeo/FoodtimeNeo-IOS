# iOS 移植源码审计（2026-11-20）

性质：开发前只读审计，不是构建、业务或设备验收。参照 Android main `32215aab169bfe9ca40d7189a09c59c325744f21`（v2.0.0β）、Android dev `ff1ed41c21b6361a3ec7ae0280878a2806c14a7a`、Backend main `e8f34998930781230711d8e8dd109c32d34b1ba8`、Web main `b6e2d8f7c49016c0d53aea94b0472f3f12595a7c`。

## 1. 基线与方法

- 逐项核对 [Android 功能对照](ANDROID-PARITY.md)、[coverage.json](parity/coverage.json)，再读 Android `MainActivity` 注册表、各 Screen/菜单/弹窗、`domain`、`data/remote`、图片/草稿/通知/更新实现和测试。
- 交叉核对 Backend Controller/DTO/文档、安全链、能力授权、Cookie/CSRF、验证码、限流与错误码。
- `python3 scripts/check_repository.py --android-repo ../FoodtimeNeo-Android`：102 项（72 路由 + 30 能力）、0 verified、路由注册表与 Android main/dev 匹配。
- 只读检查线上 Android/Backend/Web main 与 Android dev，SHA 与记录一致；未登录生产、未写入数据。

## 2. 覆盖表结论

- 72 个路由与 `MainActivity` 的 `screens` 注册表一致：main 71、dev 72，dev 仅多 `quick-review`。
- 30 项能力是防遗漏索引，不等于完整审计；缺少预登录页、对话框、菜单、缓存、通知调度、图片查看器、平台生命周期等横切行为。
- 明确写错/夸大：
  - `capability:map` 仍写“楼层入口”，但档口 `floor` 已于 2026-10-13 移除，地图实际只有区域→食堂入口。
  - `capability:search` 承诺“返回页码和位置”，Android main 只持久化关键词，筛选/排序/页码返回即重置。
  - `route:reply-create` 仅注册、全仓无入口，实际回复都在楼内完成。
  - `capability:chat` 写“删除会话”，Android 无 UI 调用；`capability:collections` 写帖子分组“新建/更名/排序/删除”，实际帖子分组只有新建，菜品分组才可改名/删除，均无排序 UI；`community-detail` 的“转发分享”只有分享 URL，没有转发创建。
- 源清单缺口：`CatalogList`/`CatalogSearch`/`RecommendationSection`、`ImageLoader`/`ImagePicker`/`PhotoImport`/`ImageDiskCache`、`DishReviewSection`/`EmbeddedReviewReplies`/`ReviewActions`、`PriceHistoryChart`/`PriceUnits`、`CampusMapGeometry`、`CatalogQuickActions`、`FeedbackDocuments`/`FeedbackJson`、`ReportManagementPolicy`、`AiAssessmentView` 等未列全。
- dev 的 quick-review 同时改造了 `ReviewScreen.create`，已发布的 `route:review` 行为也变化；不能只加一个路由。

## 3. 跨仓契约与已知缺陷

- **客户端标识**：Backend `CLIENT_HEADER_ALLOWED` 默认 `web,android`，`CLIENT_HEADER_MODE` 默认 `observe`。iOS 应发送 `X-Foodtime-Client: ios`；若线上 `enforce` 未加 `ios`，注册/发码 403 `CLIENT_UNKNOWN`。不能冒充 `android`/`web`。
- **204 空 body**：浏览历史记录/删除/清空、收藏分组删除、通知 delivered 等端点返回 204；Android `RemoteRepository.call()` 无条件 `new JSONObject(body)`，空 body 抛 `INVALID_RESPONSE`，导致通知游标不前进、历史记录被静默吞掉、删除/清空失败。iOS 已把 204/205 当成功；Android 需另修。
- **设备 Cookie**：服务端 `foodtime_device` 默认 365 天；Android 把所有 Cookie 截断到 7 天。iOS 按服务端有效期保存，退出只清 `FOODTIME_SESSION`。
- **CSRF**：读 `/auth/csrf` 的 `headerName`，回退 `X-CSRF-TOKEN`；只存内存；登录后重取；403 `CSRF_INVALID` 不自动重放写请求。
- **能力**：`GET /users/me/capabilities` 返回 `capabilities`+`revision`；全仓没有 `allowedActions` 字段。管理入口按能力名显示，写请求仍以 403/409 为准。`/admin/users|notices|feedback|reports` 在 URL 层限 superadmin；未来下放能力需改 `SecurityConfig`。
- **菜品点评无幂等键**：`POST /dishes/{id}/reviews` 只收 `{rating,content}`，同用户/菜品最多一条 pending；响应丢失后重试只得 409 `REVIEW_PENDING`。食堂/档口点评与回复有 `clientRequestId`。
- **举报决定无幂等键**：同一举报只能决定一次，重复 409；已处理列表 DTO 不返回 `internalNote`。追问按 `(author, clientRequestId)` 唯一，重放直接返回旧记录且不校验内容。
- **目录直编无 revision**：`/admin/catalog/*` PUT 不接受 `expectedRevision`，是后写覆盖；revision 只用于纠错提案的条件冲突。
- **历史 epoch**：Android 遇 `HISTORY_EPOCH_STALE` 会自动用同一事件重试，违反架构文档；iOS 只允许用户新的真实访问生成新事件。

## 4. 平台与体验结论

- Android 是单 Activity + 自定义 View，无法直接移植；iOS 是行为/契约级复刻。
- 图片：Android 仅头像分支应用 EXIF 方向，菜品/证据/投稿图会横躺；iOS 必须对所有图烘焙方向、HEIC 转 JPEG、最长边 1600/JPEG 0.9。
- 地图：六区域、5032×3579 WebP；iOS 直接全解码约 72MB，需降采样/切片/CATiledLayer；无楼层、无定位/路线；底图许可待确认。
- 草稿：发帖每账号一份、JSON 原子写、500ms 防抖；Android 注销时删图留 JSON 路径，可能恢复坏图；iOS 不应复制。
- 通知：七类、`afterSeq` 游标、`eventId` 去重、shown→delivered→checkpoint；Android JobScheduler 15 分钟周期在 iOS 不存在，BGTask 只能尽力而为；APNs 需后端设备 token/推送接口。
- 更新：APK/bsdiff/内容提供器安装不可移植；iOS 走 App Store/TestFlight/MDM，需要服务端 iOS 版本契约。
- Emoji/字体：Android 用系统 Emoji；Web 自托管 Noto Color Emoji（OFL）。iOS 默认 Apple Color Emoji，观感不同；若要统一需验证 TTF/OTF 或预渲染，成本/体积高。
- 字体：title/body/note 三套均 OFL，约 31MB；可打包并在 Info.plist 注册，需确认子集化与包体积。
- 已知 Android 缺陷不应复制：非头像 EXIF、点评编辑正文未回填、搜索返回状态丢失、访客写入口点击后才 403、删除会话无 UI、帖子分组能力描述夸大。

## 5. 需确认项

见 [IOS-DECISIONS.md](IOS-DECISIONS.md) 与交接对话中的 D1–D19：Bundle ID/Team/分发、iPad/方向、系统通知/APNs、更新方式、后端客户端白名单、测试后端、字体/地图/Emoji 许可、版本与 α/β、搜索返回状态、菜品点评幂等、visitor 写入口、列表价格单位、已知缺陷修正、管理端布局/分页/能力边界。

## 6. 实施波次

| 波次 | 分支（示例） | 交付 |
|---|---|---|
| W0 工程底座 | `feature/ios-foundation` | XcodeGen 工程、SwiftUI 外壳、网络/会话/CSRF、Keychain、登录/验证码、食堂只读纵切片、macOS CI、层边界检查、文档 |
| W1 身份与账号 | `feature/auth-registration`、`feature/auth-password`、`feature/profile-account`、`feature/appeal-session`、`feature/social-graph`、`feature/feedback` | 注册策略/邀请码/邮箱验证码、找回/改密、资料/头像/学校邮箱/注销、受限申诉、关注/粉丝/搜索/黑名单、反馈 |
| W2 目录与发现 | `feature/catalog-browse`、`feature/dish-search`、`feature/dish-detail-gallery`、`feature/price-history`、`feature/campus-map`、`feature/venue-reviews` | 三级目录、推荐、搜菜筛选排序、详情/图册/缩放、价格历史、地图、食堂/档口点评 |
| W3 点评与投稿 | `feature/dish-reviews`、`feature/review-replies`、`feature/submissions`、`feature/quick-review` | 菜品点评/点赞/我的、回复/楼中楼、图片/菜品/档口投稿、我的提交、一键点评 |
| W4 社区 | `feature/community-feed`、`feature/community-detail`、`feature/community-compose`、`feature/community-edit-pins`、`feature/collections` | 四页信息流、详情/评论/点赞收藏/浏览、发帖/草稿、修改重审/置顶、收藏分组 |
| W5 消息与历史 | `feature/history`、`feature/inbox-chat`、`feature/notifications`、`feature/login-notices` | 浏览历史、信箱/私信、七类通知/游标/权限、公告弹窗/免打扰 |
| W6 管理与治理 | `feature/admin-foundation`、`feature/admin-moderation`、`feature/admin-reports-appeals`、`feature/admin-catalog`、`feature/admin-notices`、`feature/admin-users` | 管理外壳/看板、审核队列/日志、举报/追问/申诉/动作、目录/纠错、公告、用户/反馈 |
| W7 平台与发布 | `feature/media-platform`、`feature/accessibility-ipad`、`feature/performance`、`feature/release-distribution` | 相册/HEIC/裁剪/缓存/分享/CSV、动态字体/VoiceOver/iPad、性能与滚动恢复、版本/TestFlight/隐私清单 |

## 7. 验证边界

- W0 CI：XcodeGen 生成、层边界检查、模拟器编译、单元测试通过；不证明业务。
- 后续：真实测试后端（写入）、Apple Simulator（启动/登录/返回栈/动态字体/深链）、真机（相册/HEIC/通知/BGTask）、iPad/横屏。
- 每个 PR 附对应 Android SHA、coverage ID、实现位置、验证结果、未执行项、平台差异与批准依据。
