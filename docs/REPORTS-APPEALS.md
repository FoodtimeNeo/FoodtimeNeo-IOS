# 举报回执、追问、申诉与受限会话（用户侧）

实现：`Sources/Features/Reports/`、`Sources/Data/Reports/`、`Sources/Platform/FileAppealDraftStore.swift`、`Sources/Domain/Models/Report.swift`。

对照 Android：`ContentSafety`、`ReportReceiptScreen`、`ReportFollowUpScreen`、`AppealComposeScreen`、`AppealForm`、`AppealOnlyScreen`；后端：`SafetyController`、`ReportReceiptController`、`ReportInteractionController`、`docs/api/user/reports.md`。

## 举报入口

- `POST /reports {targetType,targetId,reason}`；`targetType` 为 `post`、`comment`、`message`，理由 1–500 字。
- 入口：食记详情（帖子/评论）、私信消息长按「举报」。
- 成功只提示“举报已提交”；不伪造回执编号。
- 评论/消息举报针对的内容由服务端按权限校验；公开内容仍走既有审核。

## 举报回执

- `GET /users/me/reports?page&size`、`/{id}`：本人举报，公开结果；`legacy` 只显示“历史记录”。
- `GET /users/me/moderation-decisions?page&size`、`/{id}`：本人作为举报人/被举报人收到的决定；被举报人投影不含举报人、理由原文、`reportId` 或内部备注。
- `GET /users/me/moderation-decisions/{id}/actions`：实际管理动作，展示动作类型、目标与说明。
- 申诉截止使用服务端持久化的 `appealDeadline = 入箱时间 + 7×24h`；打开详情或推送失败不重算。

## 追问

- `GET /users/me/reports/{id}/follow-ups?page&size`；管理员公开回复与本人追问同线程，内部备注不展示。
- `POST /users/me/reports/{id}/follow-ups {content,evidenceUrls,clientRequestId}`：1–500 字、最多 3 张本人证据；每账号 UTC+8 每日 5 次。
- 同一内容重试复用请求号；内容变化后换新号。

## 申诉

- `POST /users/me/moderation-decisions/{id}/appeals {content,evidenceUrls,clientRequestId}`：1–2000 字、最多 3 张证据；举报人与被举报人各一次；截止后服务端返回 409。
- `GET /users/me/appeals?page&size`、`/{id}`：本人申诉记录。
- 客户端只按决定投影显示“提交申诉”；已有申诉或截止已过时不显示表单，提交时再次校验。
- 草稿按 `(服务来源, 账号 UUID, 决定 ID)` 隔离保存在本机；内容与最多 3 张证据图持久化，提交成功或已有申诉时清除。受限会话重新认证后恢复。
- 复核结论与恢复动作分离；申诉成立不自动恢复处罚。

## 受限申诉会话

- 停用账号登录返回 `session_mode=appeal_only`；根视图只渲染 `RestrictedAppealsView`，不出现食堂/社区/私信/管理导航。
- 仅调用白名单接口：本人决定/申诉、证据上传与本人读取、CSRF/登录/退出。
- 会话 45 分钟绝对到期；账号恢复、改密、注销、退出、再次处罚都会失效。申诉草稿保留，重新认证后新 45 分钟窗口。
- 退出登录仍二次确认。

## 平台差异与未完成

- iOS 不复制 Android 的本地图片路径草稿实现，改为保存压缩后的 JPEG 数据文件；效果相同，存储位置受系统备份策略影响。
- 通知点击深链到申诉页、管理端举报/申诉页面不在本波次（管理端归 W6）。
- 追问/申诉证据的大图预览未单独实现，当前为缩略图与移除；提交前不显示服务端证据读取权限的实机结果。
- 公开/私密材料隔离依赖服务端；客户端不缓存他人证据。

## 验证边界

- 单元测试：远端 Service 的请求路径/方法/CSRF/请求体与分页；回执/决定/动作解码；追问与申诉请求号复用；申诉截止、已有申诉、草稿恢复/清除、证据上传失败；草稿目录按账号与来源隔离。
- 本地架构检查与仓库检查通过；编译/单测由 macOS CI 执行。
- 未执行：真实停用账号双端联调、真实证据权限、Apple Simulator 相册/键盘/日期边界、并发重复申诉与 7 天截止实测。
