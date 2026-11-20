# 收藏分组（W4）

实现：`Sources/Features/Collections/CollectionsView.swift`、`FavoriteGroupsView.swift`、`FavoriteMembershipView.swift`、`Sources/Data/Favorites/RemoteFavoriteService.swift`。

## 接口

| 功能 | 接口 |
|---|---|
| 分组列表/创建 | `GET/POST /users/me/favorite-groups?kind=dish|post` |
| 改名/排序/删除 | `PUT/DELETE /users/me/favorite-groups/{id}`（PUT 带 `expectedRevision`） |
| 对象所属分组 | `GET /users/me/favorite-groups/memberships?kind=&targetId=` |
| 加入/移出 | `PUT/DELETE /users/me/favorite-groups/{id}/members/{targetId}` |
| 收藏列表 | `GET /users/me/dish-favorites?groupId|unfiled&page&size`、`/users/me/community-favorites` |
| 菜品收藏状态/切换 | `GET/PUT/DELETE /users/me/dish-favorites/{dish}` |

## 行为

- 菜品与帖子分组独立；每类最多 20 组；名称去空白/NFC 后 1–20，同类型不重名。
- 全部/未分组/自定义分组筛选；`groupId` 与 `unfiled=true` 互斥。
- 同一收藏可加入同类型多个分组；加入分组不自动创建收藏；取消收藏级联清理分组关系。
- 删除分组不删除收藏；重名/上限/revision 冲突显示服务端消息。
- 菜品详情可直接收藏；帖子详情已有收藏；收藏列表可进入详情并在上下文菜单管理分组。

## 验证边界

- 单元测试覆盖分组列表/创建/改名/删除、成员关系、菜品/帖子收藏筛选、菜品收藏状态与切换。
- 未执行：真实收藏/分组并发、Apple Simulator 上下文菜单、20 组上限、revision 冲突与切号隔离。
- `capability:collections` 未标 verified。
