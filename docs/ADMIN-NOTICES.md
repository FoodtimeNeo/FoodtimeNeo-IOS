# 管理端：公告管理（W6）

实现：`Sources/Features/Admin/AdminNoticesView.swift`、`AdminNoticeViewModel.swift`、`Sources/Domain/Models/AdminNotice.swift`。

## 范围

- `GET /admin/notices?page&size`：全部公告，按发布时间倒序。
- `GET /admin/notices/search?q&page&size`：标题/正文搜索；q 为空时走同一列表。
- `GET /admin/notices/{id}`：管理端详情。
- `POST /admin/notices/markdown`、`PUT /admin/notices/{id}/markdown`：`{content, schedule?}`；Markdown 首个非空标题作为公告标题，正文 ≤20000。
- `PUT /admin/notices/{id}/schedule`：`{publishedAt, displayStartsAt?, displayEndsAt?, expiresOn?, isUpdate, published, enabled}`。
- `DELETE /admin/notices/{id}`：硬删除，已读记录级联。
- `GET|PUT /admin/notices/settings`：`{noticeId}`，登录弹窗当前公告；null 表示不弹。
- UI：搜索、新建/编辑 Markdown、排期、删除确认、登录弹窗设置。

## 关键实现

- 排期时间以 ISO8601 字符串编码。`APIRequest.json` 使用默认 `JSONEncoder`（Date 为数值），不能直接编码 `Date` 到后端 `Instant`。
- `expiresOn` 是服务端 `LocalDate`，用 `yyyy-MM-dd`（Asia/Shanghai）字符串。
- 编辑时 `schedule` 传 nil 表示保留原排期；新建时服务端会生成默认排期。
- 状态与徽标：published/paused/expired 等以服务端 `status` 为准；`enabled/published/isUpdate` 原样展示。

## 边界

- 不使用旧版 `POST /admin/notices` / `PUT /{id}`（title/body）接口；Markdown 是实际管理路径。
- Markdown 只保存源码，iOS 未内嵌渲染器；用户端全文读取由 W5 的受限渲染负责。
- `/admin/notices` 在 URL 层仅 superadmin；普通 admin 会收到 403。
- 删除不提供恢复。

## 验证边界

- 单元测试覆盖列表/搜索路径、Markdown 新建 POST 与编辑 PUT、排期 PUT、设置 GET/PUT、删除 DELETE，以及排期 ISO/LocalDate 编码。
- 未执行：Apple Simulator、真实超管权限、排期生效与过期、登录弹窗真实投影、Markdown 渲染效果。
- 对齐条目保持 `in-progress`，不标 verified。
