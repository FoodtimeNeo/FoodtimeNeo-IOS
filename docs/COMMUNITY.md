# 社区信息流、详情、评论与互动（W4）

实现：`Sources/Features/Community/CommunityFeedView.swift`、`CommunityFeedViewModel.swift`、`CommunityDetailView.swift`、`CommunityDetailViewModel.swift`、`Sources/Data/Community/RemoteCommunityService.swift`。

## 接口

| 功能 | 接口 |
|---|---|
| 信息流 | `GET /community/feed/cursor?size&cursor&following&q&pinRevision`，`items/total/hasMore/nextCursor` |
| 详情 | `GET /community/posts/{id}`；pending 仅本人可见 |
| 评论根楼层 | `GET /community/posts/{id}/comments/cursor?size&cursor` |
| 楼内回复 | `GET /community/posts/{id}/comments/{rootId}/replies?size&cursor` |
| 发评论 | `POST /community/posts/{id}/comments` `{content≤500,clientRequestId,rootCommentId?,replyToCommentId?}`；202 |
| 点赞/收藏 | `PUT/DELETE /community/posts/{id}/like|favorite`、`/comments/{id}/like` |
| 浏览量 | `POST /community/posts/{id}/views` `{clientRequestId}` |

## 行为

- 社区 Tab；发现/关注切换、关键词搜索（300ms 防抖）、游标加载更多。
- 卡片展示标题/正文/首图/点赞/评论数；详情展示全文、图片（全屏缩放复用图册）、转发摘要、点赞/收藏/浏览量。
- 评论先审后发；提交 202 pending 后本地插入并标记待审，公开列表只含已通过评论。
- 浏览量只在 approved 详情成功后记录一次，重试/刷新不重复计数。
- 关注流为空、错误、加载中均有显式状态；服务端 401 由全局会话处理。
- 楼中楼回复已接入：根评论线程、回复目标、回复点赞、pending 提交；发帖/草稿已接入；帖子修改/置顶、收藏分组在后续 W4 分支接入。

## 验证边界

- 单元测试覆盖 feed 查询、评论提交/点赞、帖子点赞/收藏/浏览、路径与请求号。
- 未执行：真实后端 feed/详情/评论审核、Apple Simulator 瀑布流/键盘、转发/视频、游标边界、切号隔离。
- `capability:community-feed`/`community-detail` 未标 verified。
