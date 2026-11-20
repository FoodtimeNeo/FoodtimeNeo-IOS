# 菜品点评、点赞与我的点评（W3）

实现：`Sources/Features/Reviews/DishReviewsSection.swift`、`DishReviewsViewModel.swift`、`MyReviewsView.swift`、`MyReviewsViewModel.swift`、`Sources/Data/Reviews/RemoteReviewService.swift`。

## 接口

| 功能 | 接口 |
|---|---|
| 已发布点评 | `GET /dishes/{id}/reviews?page&size`；分页 `items/total/page/size` |
| 提交点评 | `POST /dishes/{id}/reviews` `{rating:1..5,content≤500}`；202 pending |
| 评分 | `GET /dishes/{id}/rating` |
| 我的正式点评 | `GET /users/me/reviews?page&size`；删除 `DELETE /users/me/reviews/{id}` |
| 我的审核记录 | `GET /users/me/review-submissions?page&size`（pending/approved/rejected + reviewReason） |
| 点赞/取消 | `PUT/DELETE /reviews/{id}/like`，返回 `likedByMe/likeCount/counterVersion` |

## 行为

- 点评正文 1–500；评分 1–5；提交后进入审核，通过后才公开并计入评分。
- 同用户/菜品最多一条 pending；重复提交 409 `REVIEW_PENDING`，客户端提示等待审核。
- 点赞用响应更新按钮与计数，不自行加减；`counterVersion` 由服务端维护。
- 详情页展示已发布点评与“写点评”；“我的点评”分已发布/审核记录两栏，驳回显示审核说明。
- 删除本人已发布点评会同步评分；审核历史保留。
- 点评回复/楼中楼/回复点赞在后续 W3 分支接入。

## 验证边界

- 单元测试覆盖点评分页解码、提交 body、点赞 PUT/DELETE、审核记录状态与理由、评分/正文校验。
- 未执行：真实测试后端点评审核流转、Apple Simulator 输入/星级点击、点赞并发、我的点评分页与删除真实数据。
- `capability:reviews` 未标 verified；回复/楼中楼与真实审核联调仍待后续。
