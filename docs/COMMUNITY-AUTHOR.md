# 社区作者主页（作者食记）

实现：`Sources/Features/Community/AuthorPostsView.swift`、`AuthorPostsViewModel.swift`、`Sources/Domain/Models/CommunityAuthor.swift`。

对照 Android：`route:community-author`；后端：`GET /community/authors/{id}`、`GET /community/authors/{id}/posts`。

## 行为

- 食记详情点击作者昵称进入作者页。
- 顶部展示作者昵称与公开食记总数；列表只包含已通过内容，按游标分页（`size`、`cursor`），支持加载更多与下拉刷新。
- 点击卡片进入原食记详情；复用 `CommunityDetailView`。
- 作者不存在或内容不可见时显示服务端错误；不缓存他人未公开内容。

## 平台差异与边界

- 不展示关注/粉丝数（Android 作者页若有需后续补，当前接口只有 id/昵称/头像）。
- 不做作者内容筛选/搜索；空状态与加载/错误状态齐全。
- 转发/置顶/审核状态仍由原帖子详情展示，作者页不重复实现。

## 验证边界

- 单元测试：作者资料与作者帖子路径、游标参数、分页合并与 `hasMore`。
- 本地架构检查与仓库检查通过；编译/单测由 macOS CI 执行。
- 未执行：真实作者页联调、Apple Simulator 导航/分页、空作者与已注销作者。
