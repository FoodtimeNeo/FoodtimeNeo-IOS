# 点评回复与楼中楼（W3）

实现：`Sources/Features/Reviews/ReviewThreadView.swift`、`ReviewThreadViewModel.swift`、`Sources/Data/Reviews/RemoteReviewService.swift`、`Sources/Domain/Models/ReviewReply.swift`。

## 接口

| 功能 | 接口 |
|---|---|
| 回复列表 | `GET /reviews/{id}/replies?size=20&cursor=`；`items/total/hasMore/nextCursor` |
| 提交回复 | `POST /reviews/{id}/replies` `{content≤500,replyToId?,clientRequestId}`；202 pending |
| 我的回复 | `GET /users/me/review-replies?page&size`；删除 `DELETE /review-replies/{id}` |
| 回复点赞 | `PUT/DELETE /review-replies/{id}/like`，返回 `likedByMe/likeCount/counterVersion` |

## 行为

- 公开列表只含已通过回复；提交后进入审核，pending 不公开。
- 回复可指向楼内任意回复（`replyToId`），显示“回复 @昵称”；被回复对象删除显示占位。
- `clientRequestId` 同内容重试幂等；改载荷 409 `REPLY_REQUEST_CONFLICT`。
- 点赞以响应更新，不用本地加减；删除本人回复保留审核历史与后续回复。
- “我的回复”展示审核状态、驳回原因与删除入口。

## 验证边界

- 单元测试覆盖回复分页/提交 body/请求号、回复点赞、我的回复分页。
- 未执行：真实审核流转、Apple Simulator 键盘/楼中楼滚动、点赞并发、回复删除后的占位回归。
- `capability:reviews` 的回复部分未标 verified。
