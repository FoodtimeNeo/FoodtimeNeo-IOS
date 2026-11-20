# 浏览历史（W5）

实现：`Sources/Features/History/HistoryView.swift`、`HistoryViewModel.swift`、`Sources/Data/History/RemoteHistoryService.swift`、`Sources/Domain/Models/BrowsingHistory.swift`。

## 接口

| 功能 | 接口 |
|---|---|
| 设置 | `GET/PUT /users/me/browsing-history/settings`；PUT 带 `expectedRevision` |
| 列表 | `GET /users/me/browsing-history?kind=dish|post&page&size<=50` |
| 记录访问 | `PUT /users/me/browsing-history/{kind}/{targetId}` `{epoch,visitEventId}`；204 |
| 删除单项 | `DELETE .../{kind}/{targetId}`；递增该类 epoch |
| 清空类型 | `DELETE /users/me/browsing-history?kind=...`；必须显式 kind |

## 行为

- 菜品/帖子两栏各最近 50 条，服务器时间倒序，同对象只留最近一次，不按时间过期。
- 关闭只停止新增并保留记录；关闭时两类 epoch 递增；重新开启不重置 epoch。
- 只有详情成功且目标可见后记录；列表/预加载/失败/待审预览不记录；历史不增加帖子浏览量。
- `HISTORY_EPOCH_STALE` 不自动换新 epoch 重放；下一次真实详情访问才产生新事件。
- 失效目标只保留 `targetId/visitedAt`，不展示旧标题/图片，可删除。
- 删除/清空后刷新设置 epoch，旧任务不能补回。

## 验证边界

- 单元测试覆盖设置/列表/记录 body 与 epoch、删除/清空路径、AppSession 使用设置 epoch。
- 未执行：真实并发/epoch 冲突、Apple Simulator、切号隔离、失效目标与删除后回写。
- `capability:history` 未标 verified。
