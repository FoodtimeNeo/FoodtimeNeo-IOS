# 管理端：目录管理与正式点评（W6）

实现：`Sources/Features/Admin/AdminCatalogView.swift`、`AdminReviewsView.swift`、`AdminCatalogViewModel.swift`、`Sources/Domain/Models/AdminCatalog.swift`。

## 目录

- `GET /admin/catalog/{dining-halls|stalls|dishes}?parentId&page&size`：含停用记录。
- `GET /admin/catalog/{type}/{id}`：单项详情。
- `POST /admin/catalog/{type}`：`{parentId?, name, description?, price?, coverImageUrl?, status, sortOrder?, priceUnit?}`；服务端生成 UUID，菜品必须有价格。
- `PUT /admin/catalog/{type}/{id}`：编辑名称/简介/价格/启停/排序/计价单位；所属关系保持不变，不接受 `expectedRevision`（后写覆盖，属已知服务端行为）。
- `DELETE /admin/catalog/{type}/{id}`：仅无关联记录可删；仍被引用时 409，应改为停用。
- UI：三类切换、分页、新增/编辑表单、父级选择（食堂→档口→菜品）、删除二次确认。

## 正式点评

- `GET /admin/reviews?q&page&size`：搜索内容/用户/菜名，含停用菜品历史与作者邮箱。
- `DELETE /admin/reviews/{reviewId}`：body `{reason}`，reason 必填；软删除并保留审核历史，评分由服务端在同一事务重算。
- UI：搜索防抖、点评卡片、移除原因弹窗。

## 边界

- 编辑所属不可改：表单在编辑态禁用父级选择，仍以服务端为准。
- 价格 0 起、最多两位小数；名称 ≤120、简介 ≤500。
- `/admin/catalog/**` 允许 admin/superadmin；目录图片管理见 `docs/ADMIN-CATALOG-IMAGES.md`，仅超管显示入口。
- 删除 409 不自动改为停用，避免误操作；提示用户手动编辑状态。

## 验证边界

- 单元测试覆盖目录列表 parentId、创建 POST body、更新 PUT 路径、DELETE 方法；点评搜索 q 与移除 DELETE body。
- 未执行：Apple Simulator、真实目录外键 409、图片管理、后写覆盖并发、点评评分重算验证。
- 对齐条目保持 `in-progress`，不标 verified。
