# 管理端：社区审核（W6）

实现：`Sources/Features/Admin/CommunityModerationView.swift`、`CommunityModerationViewModel.swift`、`Sources/Data/Admin/RemoteAdminService.swift`。

## 范围

- `GET /admin/community/posts|comments?status&page&size`：食记与评论各自分页队列，响应复用 `ModerationItem`，带作者、AI 分诊、审核原因与 `contentRevision`。
- `POST /admin/community/posts|comments/{id}`：body `{action, reason?, contentRevision?}`；仅 pending 可审；帖子审核必须带当前修订号，过期返回 409 `POST_REVIEW_CONFLICT`。
- `GET /admin/community/posts|comments/{id}`：详情，返回帖子或评论、根评论/被回复评论与作者邮箱。
- `DELETE /admin/community/posts|comments/{id}`：管理员软删除，保留操作者与删除时间；无 body、无必填原因。
- UI：食记/评论与状态筛选、队列卡片、详情内通过/驳回（驳回必填原因）与二次确认删除。

## 边界

- 通过/驳回后返回队列刷新；删除后返回并刷新。
- `POST_REVIEW_CONFLICT` 提示作者已修改，要求刷新详情；不本地覆盖修订号。
- 已审条目只读，不显示通过/驳回按钮；删除仍可用。
- 图片只展示数量，不在管理队列加载图片内容。

## 验证边界

- 单元测试覆盖队列 kind 路径与状态参数、审核 POST body（含 `contentRevision`）、详情解码与 DELETE 方法与路径。
- 未执行：Apple Simulator、真实管理员账号、帖子并发修改 409、删除后列表与详情跳转、举报联动。
- 对齐条目保持 `in-progress`，不标 verified。
