# 关注、粉丝、用户搜索与黑名单（W1）

实现：`Sources/Features/Social/SocialView.swift`、`SocialViewModel.swift`、`Sources/Data/Social/RemoteSocialService.swift`、`Sources/Domain/Models/Social.swift`。

## 接口

| 功能 | 接口 |
|---|---|
| 用户搜索 | `GET /users/search?q&page&size=20`，按昵称不区分大小写包含匹配，空关键词不列用户 |
| 关注/粉丝 | `GET /users/{id}/following|followers?page&size=20` |
| 关注/取消 | `PUT/DELETE /users/{id}/follow`，返回 `{followed,followerCount}`，幂等 |
| 黑名单 | `GET /users/me/blocks?page&size=20`，返回 `{id,displayName,avatarUrl,blockedAt}` |
| 拉黑/解除 | `PUT/DELETE /users/{id}/block`，返回 `{blocked}` |

## 行为

- 只有登录会话可读；访客可读的关注/粉丝按服务端策略；写操作（关注、拉黑）以服务端 403/429 为准。
- 关注/取消关注重复请求幂等；客户端用响应更新按钮，不自行加减粉丝数。
- 拉黑主要影响私信；不删除对方公开内容。黑名单页可解除。
- 用户搜索 300ms 防抖；切换分段重新读取第一页；列表滚动到底部加载下一页（page/size 20）。
- 空列表、加载失败、限流显示明确状态；失败保留已加载内容。

## 验证边界

- 单元测试覆盖搜索 query、关注 PUT/DELETE、黑名单 GET/解除 DELETE、分页解码。
- 未执行：真实测试后端关注/粉丝/黑名单写入、Apple Simulator 滚动与输入、访客/管理员权限矩阵、限流实测。
- `capability:profile-social` 只完成关注/粉丝/搜索/黑名单部分；资料头像与管理用户搜索仍属后续波次。
