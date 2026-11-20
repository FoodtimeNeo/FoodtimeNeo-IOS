# 提醒事件与投递（数据层）

实现：`Sources/Domain/Models/NotificationEvent.swift`、`NotificationService` 扩展、`RemoteNotificationService`。

对照 Android：`NotificationBatchPoller`、`NotificationEventReminders`；后端：`GET /users/me/notification-events`、`POST /users/me/notification-events/{eventId}/delivered`。

## 已接入

- 事件模型：稳定 `eventId`、`seq` 游标、分类、标题/正文、引用目标、`createdAt`、`deliveryStatus`。
- `GET /users/me/notification-events?afterSeq&limit`：只取游标之后的本人事件；`nextSeq` 为空/不前进时保留原游标。
- `POST /users/me/notification-events/{eventId}/delivered`：幂等标记系统投递完成；不改变站内已读或入箱时间。
- 七类开关仍由 `NotificationService.preferences/update` 管理；关闭类别的事件不创建投递，客户端不应自行补发。

## 尚未接入（平台阻塞）

- iOS 后台调度：`BGAppRefreshTask` 只能尽力而为，强制关闭/低电量会停；需要 `BGTaskSchedulerPermittedIdentifiers` 与后台模式配置，待分发方案确认。
- APNs：需要后端设备 token、推送证书与事件接口，尚未确认。
- 前台事件轮询、去重持久化（cursor + shown eventId）、本地通知展示与点击深链尚未接线。
- 在接入前，本数据层不会被任何 UI 调用；不要把它当作提醒已可用。

## 边界

- 客户端不得以“未读总数增加”推断新事件；只能用事件编号/序号。
- 已 delivered 的历史不回退；关闭/重开类别由服务端重建基线，客户端不补发。
- 站内消息始终可读，与系统投递独立。

## 验证边界

- 单元测试：事件游标/limit 参数、字段与 deliveryStatus 解码、delivered 路径与方法。
- 本地架构检查与仓库检查通过；编译/单测由 macOS CI 执行。
- 未执行：真实事件轮询/去重、系统通知展示、后台任务、APNs、真机。
