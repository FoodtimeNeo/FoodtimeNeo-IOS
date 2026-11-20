# 建议与反馈（W1 用户端）

实现：`Sources/Features/Feedback/FeedbackView.swift`、`FeedbackViewModel.swift`、`Sources/Data/Feedback/RemoteFeedbackService.swift`、`Sources/Domain/Models/Feedback.swift`。

## 用户接口

| 功能 | 接口 |
|---|---|
| 提交 | `POST /users/me/feedback` `{type,content,clientRequestId}`；type 为 `function/content/usage/suggestion/other`，内容 1–5000 |
| 列表 | `GET /users/me/feedback?archived=false|true&page&size=20` |
| 详情 | `GET /users/me/feedback/{id}` |
| 回复历史 | `GET /users/me/feedback/{id}/replies?page&size=20` |

## 规则

- 每次内容或类型变化生成新的 `clientRequestId`；同编号重试不重复创建，异内容 409 `FEEDBACK_REQUEST_CONFLICT`。
- 额度：访客每天 2 条、普通用户每天 5 条、同设备每天 10 条；UTC+8 00:00 重置。成功后不释放当日额度。
- 状态 `pending/processing/completed`；只有管理员能回复/完成；用户侧只读。
- 列表分页 20；已完成归档单独查询；详情展示完整回复历史。
- 用户提交/查看自己的记录；全部反馈管理、CSV 导入导出属 W6 管理端，不在本 PR。

## 错误与 UI

- `FEEDBACK_DAILY_LIMIT` / `FEEDBACK_DEVICE_DAILY_LIMIT`：提示额度已用完，保留输入。
- `FEEDBACK_REQUEST_CONFLICT`：提示重新编辑后提交。
- 校验失败展示字段原因；列表失败保留已加载内容并提供重试。
- 空列表、加载、错误三态显式；正文可选复制。

## 验证边界

- 单元测试覆盖创建 body/类型标签、列表 archived/page 查询、回复分页解码、内容长度校验。
- 未执行：真实测试后端提交/额度、Apple Simulator 输入与长文本、管理员回复后的归档联动、CSV（W6）。
- `capability:feedback` 只完成用户端；管理端回复/导出/导入仍属 W6。
