# 菜品/档口目录投稿与我的投稿（W3）

实现：`Sources/Features/Submissions/DishSubmissionView.swift`、`StallSubmissionView.swift`、`MySubmissionsView.swift`、`Sources/Data/Submissions/RemoteSubmissionService.swift`。

## 接口

| 功能 | 接口 |
|---|---|
| 菜品投稿 | `POST /stalls/{stallId}/submissions` `{name≤120,description≤500,price?,imageUrl}`；202 `{id,status,createdAt}` |
| 档口投稿 | `POST /dining-halls/{hallId}/submissions` `{name≤100,description≤500,coverImageUrl}`；202 |
| 我的菜品投稿 | `GET /users/me/dish-submissions?page&size` |
| 我的档口投稿 | `GET /users/me/stall-submissions?page&size` |
| 我的图片投稿 | `GET /users/me/image-submissions?page&size` |

## 行为

- 先上传图片得到本人 `/api/v1/media/{id}` 引用，再提交投稿；上传/投稿/审核三步分离。
- 菜品名称最多 120、档口最多 100；简介最多 500；菜品参考价格可空且非负、最多两位小数。
- 投稿仅写 pending 记录，不直接创建正式目录；审核通过前不在公开目录出现。
- 我的投稿按菜品/档口/图片分栏，展示状态、审核说明和时间；停用父级历史保留。
- 提交限流与点评/图片投稿共用；429 显示服务端消息。

## 验证边界

- 单元测试覆盖菜品/档口投稿 body/路径、我的菜品/档口/图片分页。
- 未执行：真实图片上传/审核流转、Apple Simulator 表单/相册、停用父级、限流与失败重试。
- `capability:submissions` 未标 verified。
