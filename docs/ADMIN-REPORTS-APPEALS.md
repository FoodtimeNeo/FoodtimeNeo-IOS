# 管理端：举报处理与申诉复核（W6）

实现：`Sources/Features/Admin/AdminReportsView.swift`、`AdminGovernanceViewModel.swift`、`AdminAppealsView.swift`、`Sources/Domain/Models/AdminGovernance.swift`。

## 举报

- `GET /admin/reports?page&size`：待处理举报，含 target type/id、target user、post、理由、摘要、时间。
- `POST /admin/reports/{id}/decision`：`{outcome:"upheld"|"not_upheld", publicReason, internalNote?}`；公开理由必填 ≤500，内部备注 ≤2000。
- `GET /admin/reports/decisions?page&size`：已决定历史（不含内部备注）。
- `GET|POST /admin/reports/{id}/follow-ups`：追问线程；员工回复 `{content, internalNote?, evidenceUrls[], clientRequestId}`，内容 ≤500、附件 ≤3。
- `GET|POST /admin/reports/{id}/actions`：处理动作历史与执行；动作 `remove_post|remove_comment|disable_user|restore_user`，删除/停用类需要 targetId，备注 ≤500。
- `PUT /admin/reports/{id}/review`：标记已读。
- UI：待处理/已决定切换；详情内提交决定、发送追问、执行动作、标记已读。

## 申诉

- `GET /admin/appeals?status&page&size`：status 可省略或 `submitted|under_review|resolved`。
- `GET /admin/appeals/{id}`：详情含内部备注与证据。
- `POST /admin/appeals/{id}/start?expectedRevision=…`：submitted → under_review。
- `POST /admin/appeals/{id}/resolve`：`{outcome:"upheld"|"rejected", publicReason, internalNote?, expectedRevision}`。
- 冲突码 `APPEAL_REVISION_CONFLICT` 提示重新载入；结束后记录只读。

## 能力边界

- `/admin/reports`、`/admin/users`、`/admin/notices`、`/admin/feedback` 在 URL 层仅 superadmin；普通 admin 打开会收到 403。iOS 不按角色名绕开，错误原样展示。
- `/admin/appeals` 由服务端 `appeal.review` 能力校验，默认仅超管。
- 举报队列不返回举报人昵称/邮箱；界面只显示后端提供的 ID 与摘要。

## 验证边界

- 单元测试覆盖举报队列/决定/历史、追问与动作 POST body、标记已读 PUT、申诉列表 status、start 查询参数、resolve body。
- 未执行：Apple Simulator、真实 superadmin/admin 403 矩阵、决定后通知与申诉期、动作副作用（删除/停用）、`APPEAL_REVISION_CONFLICT` 并发。
- 对齐条目保持 `in-progress`，不标 verified。
