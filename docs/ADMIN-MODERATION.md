# 管理端：审核队列与日志（W6）

实现：`Sources/Features/Admin/ModerationQueueView.swift`、`ModerationQueueViewModel.swift`、`Sources/Data/Admin/RemoteAdminService.swift`、`Sources/Domain/Models/Admin.swift`。

## 范围

- `GET /admin/moderation?status&type&page&size`：status 默认 `pending`，可取 `approved`/`rejected`；type 省略时返回全部投稿，可选 `review`、`dish`、`stall`、`photo`、`dish-review-reply`、`hall-review`、`stall-review`、`hall-review-reply`、`stall-review-reply`。
- `POST /admin/moderation/{type}/{submissionId}`：body `{action:"approve"|"reject", reason?, price?, contentRevision?}`；仅 `pending` 可处理，重复审核服务端返回 409，状态、正式数据与日志在同一事务完成。
- `GET /admin/moderation/logs?page&size`：按时间倒序，`actor` 区分 `ai` 与人工。
- 队列卡片展示类型、名称、提交人/邮箱、内容、评分、价格、AI 风险级别与置信度；`reason` 供已审条目回溯。
- 通过菜品必须补价格（0 起、最多两位小数，与服务端 `@Digits(integer=8,fraction=2)` 一致）；驳回必须填写原因。
- 社区帖子审核使用 `contentRevision` 做并发保护；队列条目携带该值时原样回传。

## 边界

- 列表不缓存跨账号数据；进入页面与切筛选重新拉取。
- 409（`ALREADY_REVIEWED`）提示刷新队列，不本地伪造结果。
- 无审核能力的账号不显示管理 Tab（既有 `canUseAdminArea` 判断），动作仍由服务端能力逐次校验。
- 图片字段当前只保留在模型中，队列暂未渲染缩略图；图片加载与缓存统一在 W7 平台层处理。
- 极简错误/空态与分页；审核日志同样分页，没有做批量审核（后端未提供批量接口）。

## 验证边界

- 单元测试覆盖队列分页解码与筛选参数、审核 POST 路径/body/结果解码、日志分页解码。
- 未执行：Apple Simulator、真实管理员账号三类审核动作、AI triage 结果展示、409 重试、社区 `contentRevision` 冲突、图片字段真实渲染。
- `capability:moderation-queue` 等对齐条目保持 `in-progress`，不标 verified。
