# 食堂/档口点评（W3）

实现：`Sources/Features/Reviews/VenueReviewsView.swift`、`VenueReviewsViewModel.swift`、`Sources/Data/Reviews/RemoteVenueReviewService.swift`、`Sources/Domain/Models/VenueReview.swift`。

## 接口

| 功能 | 接口 |
|---|---|
| 评分汇总 | `GET /dining-halls/{id}/rating`、`GET /stalls/{id}/rating` |
| 点评列表 | `GET /{dining-halls|stalls}/{id}/reviews?size=20&cursor=&rating=all|5|4|1-3` |
| 我的评价 | `GET /{dining-halls|stalls}/{id}/reviews/me`，返回公开版与私有待审提交 |
| 提交 | `POST /{dining-halls|stalls}/{id}/reviews` `{rating,content,clientRequestId}`；202 pending |
| 点赞 | `PUT/DELETE /venue-reviews/{id}/like` |

## 行为

- 食堂/档口入口分别展示“食堂点评/档口点评”；评分筛选 all/5/4/1-3；游标加载更多。
- 提交后进入审核；同一用户/目标已有 pending 或已通过记录时服务端返回冲突，客户端提示查看“我的评价”。
- 私有待审/驳回显示状态与审核说明；通过后显示“已公开”。
- 点赞以响应更新；回复/楼中楼、管理员删除/审核在后续 W3/W6 分支接入。
- 真实 body 上限与评分规则以服务端为准；客户端 1–5 星、正文 1–500。

## 验证边界

- 单元测试覆盖目标/列表/提交/点赞、路径与请求号。
- 未执行：真实审核流转、Apple Simulator、筛选/游标边界、冲突/私有预览、回复与管理员删除。
- `capability:reviews` 的食堂/档口部分未标 verified。
