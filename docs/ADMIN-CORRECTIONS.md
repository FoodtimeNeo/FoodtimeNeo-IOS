# 管理端：目录纠错审核（W6）

实现：`Sources/Features/Admin/AdminCorrectionsView.swift`、`AdminCorrectionViewModel.swift`、`Sources/Domain/Models/AdminCorrection.swift`。

## 范围

- `GET /admin/catalog-corrections?status&targetType&page&size`：status 可省略或 `pending|approved|rejected`；targetType 可省略或 `dining_hall|stall|dish`。
- `GET /admin/catalog-corrections/{id}`：提案原文/建议值、修改字段、证据、提交人姓名与邮箱、审核说明。
- `POST /admin/catalog-corrections/{id}/decision`：`{decision:"approved"|"rejected", reviewNote?, expectedRevision}`；整单通过或拒绝。
- 通过时服务端同时校验提案修订号、目录可见性与目录基线修订号；冲突返回 409，不覆盖新资料。
- UI：状态与类型筛选、提案对比、通过并应用/拒绝、审核说明、分页。

## 边界

- `expectedRevision` 取详情最新 `correction.revision`；处理后刷新列表。
- 错误码映射：`CORRECTION_ALREADY_DECIDED`、`CORRECTION_REVISION_CONFLICT`、`CATALOG_REVISION_CONFLICT`、`CATALOG_TARGET_GONE`、`CATALOG_TARGET_UNAVAILABLE`。
- 提案只读字段不本地合并；通过后的正式目录由服务端写入。
- `correction.review` 能力默认仅超管；普通 admin 打开会收到 403，界面原样展示。

## 验证边界

- 单元测试覆盖状态/类型查询、详情解码、决定 POST body（decision/reviewNote/expectedRevision）与路径。
- 未执行：Apple Simulator、真实超管权限、目录基线冲突、目标停用/删除、通过后用户通知与我的纠错状态。
- 对齐条目保持 `in-progress`，不标 verified。
