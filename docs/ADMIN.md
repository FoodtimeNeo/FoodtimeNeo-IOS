# 管理端基础：看板与用户管理（W6）

实现：`Sources/Features/Admin/AdminHomeView.swift`、`AdminHomeViewModel.swift`、`Sources/Data/Admin/RemoteAdminService.swift`、`Sources/Domain/Models/Admin.swift`。

## 范围

- `GET /admin/dashboard?days=1..31`：累计用户/启用用户/在线、点评/回复/帖子、食堂/档口/菜品与按日趋势。仅 superadmin 可读（URL 层限制）。
- `GET /admin/users?q&page&size`：邮箱/昵称搜索，返回角色、状态、注册时间、正式点评数。
- `PUT /admin/users/{id}` `{role,status}`：user/admin/superadmin 与 active/disabled；不能改自己、不能改已注销账号；服务端逐次校验。
- 管理 Tab 仅当服务器能力包含 `moderation.review` 或 `catalog.edit` 时显示；具体动作仍由服务端能力判断。

## 边界

- 角色/状态写入成功刷新列表；失败保留输入并显示服务端消息。
- 不展示密码、会话或认证材料；旧响应按账号隔离。
- 本阶段只完成看板与用户管理；审核队列/日志、社区审核、举报/申诉、目录管理/纠错审核、公告、反馈 CSV 仍属 W6 后续。
- 普通 admin 对 `/admin/users|notices|feedback|reports` 会被 URL 层 403；iOS 不按角色名自行放行。

## 验证边界

- 单元测试覆盖看板/用户分页解码、用户角色/状态 PUT body 与路径。
- 未执行：真实 superadmin 权限矩阵、Apple Simulator、看板口径、并发改角色/停用与能力撤回。
- `capability:admin-users-data` 未标 verified。
