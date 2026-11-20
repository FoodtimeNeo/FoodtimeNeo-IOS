# 私信、通知信箱与提醒设置（W5）

实现：`Sources/Features/Messages/`、`Sources/Features/Notifications/`、`Sources/Data/Messages/`、`Sources/Data/Notifications/`、`Sources/Platform/SystemNotificationAuthorizer.swift`。

对照 Android：`InboxScreen`、`ChatScreen`、`NotificationSettingsScreen`、`NotificationEventReminders`；后端：`MeMessageController`、`DirectMessageController`、`MeNoticeController`、`NotificationController`。

## 入口

- 个人页 →「消息信箱」：公告 / 系统消息 / 私信三类；入口显示未读总数。
- 个人页 →「提醒设置」：七类服务端开关与系统通知权限。
- 社区详情作者名旁「私信」；关注/粉丝/搜索结果行内「私信」。
- 会话列表 → 会话详情。

## 通知信箱

- `GET /users/me/notices?page&size`：公告分页；`publishedAt` 或旧投影 `createdTime` 归一显示。
- `POST /users/me/notices/{id}/read`：点开即标读，本地未读数减一；列表接口本身不带单条已读位。
- `GET /users/me/notices/unread-count`。
- `GET /users/me/messages?page&size`：系统消息分页，`isRead`、`actorCount`、`refType/refId`。
- `POST /users/me/messages/{id}/read`、`POST /users/me/messages/read-all`。
- `GET /users/me/messages/unread-count`。
- 社区互动消息（`refType=community-post` 且类别为点赞/评论/回复）跳转帖子详情；iOS 暂不支持按评论定位（Android 用草稿键 focusComment），已在边界记录。
- 非社区消息以详情 sheet 展示标题与正文；正文为空显示占位。
- 分类图标、颜色和标签按 Android `InboxScreen` 映射。
- 公告正文用 `AttributedString(markdown:)` 渲染，附件失败时退回纯文本；不执行 HTML。

## 私信

- `GET /users/me/conversations?page&size`：按最近消息排序，`unreadCount`、对方资料。
- `GET /users/me/conversations/unread-count`。
- `POST /users/me/conversations {userId}`：幂等开始会话。
- `GET /users/me/conversations/{id}`、`GET /users/me/conversations/{id}/messages?size&cursor`（默认最新一页转正序，cursor 取更早）。
- `POST /users/me/conversations/{id}/messages {content,clientRequestId}`：正文去首尾空白后 1–1000 字；同一内容重试复用同一 `clientRequestId`，成功后清空，避免“已写入但响应丢失”造成重复。
- `POST /users/me/conversations/{id}/read`：打开会话时若未读大于 0 才调用。
- `DELETE /users/me/conversations/{id}`：隐藏本人侧会话；对方再发消息自动恢复。
- 拉黑状态：`GET /users/{id}/block`；菜单/提示条可拉黑、解除拉黑。已拉黑时隐藏输入条。
- 消息长按复制；举报入口待举报申诉波次接入（Android 为长按举报，复用 `POST /reports`）。
- 加载更早消息保持滚动位置由 SwiftUI 列表管理，不在本波次承诺像素级锚点。

## 提醒设置

- `GET /users/me/notification-preferences`：七类 `category/enabled/revision`。
- `PUT /users/me/notification-preferences/{category} {enabled,expectedRevision}`：revision 冲突时服务端拒绝，客户端提示并重新拉取当前值。
- 开启某类前请求系统通知权限；系统拒绝则保存不执行并提示去系统设置。
- 站内消息和未读不受开关影响；开启前的历史事件不补发（服务端建立基线）。
- iOS 没有 Android 旧本地私信开关，客户端不调用 `legacy-message` 迁移接口；新装用户以服务端默认值为准。

## 平台差异与未完成

- 后台系统提醒：Android `JobScheduler` 15 分钟周期在 iOS 不存在。本波次只实现服务端开关 + 系统权限适配；`BGAppRefreshTask` 尽力调度与 APNs 需要推送证书、设备 token 与后端事件接口，仍待确认（见 `docs/IOS-DECISIONS.md`）。未接入前不承诺离线系统提醒。
- 通知事件游标/去重/已投递（`GET /notification-events`、`POST /notification-events/{eventId}/delivered`）属投递层，未在本波次使用；接入后台调度时补。
- 公告登录弹窗（`/notices/current`、`/current-set`、`/confirm`、`/feed`）仍属公告波次，本波次只做信箱列表与已读。
- 私信消息举报、举报回执、追问与申诉不在本波次。
- Android 在私信头部提供刷新；iOS 用下拉刷新与菜单“刷新”，未做逐帧局部刷新。

## 验证边界

- 单元测试覆盖：三个远端 Service 的路径/方法/CSRF/请求体/分页游标/字段映射；`ChatViewModel` 的空白与超长校验、去空白、失败重试复用请求号、打开即读、拉黑切换、隐藏会话；`InboxViewModel` 的分页加载、未读计数、点开标读、全部标读、会话未读本地清零；`NotificationSettingsViewModel` 的权限分支、revision 上送、冲突重载。
- 仓库检查与层边界检查需本地或 CI 执行；编译/单测由 macOS CI 给出。
- 未执行：真实后端读写联调、Apple Simulator 键盘/滚动/九类状态、系统通知权限弹窗、真机后台、切号与并发冲突实测。CI 编译与单测不等于业务验收。

## 已知取舍

- 公告 `read` 接口在列表响应中没有单条已读标记，客户端沿用 Android 行为：点开即标读并递减本地未读数，重新进入以来服务端未读计数为准。
- 会话列表页在聊天返回后靠回调清零本条未读并刷新个人页角标，不轮询。
