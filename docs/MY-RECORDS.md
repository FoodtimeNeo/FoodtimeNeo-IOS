# 我的食记与我的食堂点评

实现：`Sources/Features/Community/MyCommunityPostsView.swift`、`MyCommunityPostsViewModel.swift`、`Sources/Features/Reviews/MyVenueReviewsView.swift`、`MyVenueReviewsViewModel.swift`。

对照 Android：社区 `community-mine`、`venue-mine`；后端：`MyCommunityPostController`、`VenueReviewController#personal`。

## 我的食记

- `GET /users/me/community-posts?page&size`：本人全部状态（待审核/已通过/已驳回），附审核说明。
- 列表展示标题、正文摘要、状态、时间与驳回原因；分页加载、刷新。
- 不把待审核内容显示为已公开；不复制管理端能力。

## 我的食堂/档口点评

- `GET /users/me/venue-reviews?page&size&type=hall|stall`：本人公开评价与审核状态；`type` 可选。
- 筛选：全部/食堂/档口；展示名称、评分、正文、状态、审核说明与时间；分页、刷新。
- 仅展示本人记录；不展示内部备注。

## 边界

- 未实现编辑/删除（Android 端另有入口的部分留后续），只做只读记录与状态。
- 图片列表未在卡片内展开；详细内容需进入对应详情（本波次未做详情跳转）。
- 状态以服务端为准；`invalidated` 等未知状态按“状态更新中”处理，不自行推断。

## 验证边界

- 单元测试：两个远端接口的路径/分页/类型筛选/字段映射；列表分页与筛选切换。
- 本地架构检查与仓库检查通过；编译/单测由 macOS CI 执行。
- 未执行：真实账号的待审核/驳回记录联调、Apple Simulator 列表与分页、切号隔离实测。
