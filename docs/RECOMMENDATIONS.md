# 每日推荐（W2）

实现：`Sources/Features/Catalog/DailyRecommendationSection.swift`、`DiningHallsViewModel.swift`、`Sources/Domain/Models/Recommendation.swift`、`Sources/Data/Catalog/RemoteCatalogService.swift`。

## 接口与行为

- `GET /recommendations/daily`：服务端按 Asia/Shanghai 当天生成；`date/algorithmVersion/total/items`。
- `items[]`：`dishId/dishName/diningHallId/diningHallName/stallId/stallName/averageRating/reviewCount/imageUrl/recommendationType/recommendationScore/reasonCode/reason`。
- `imageUrl` 可为 null；`averageRating` 可为 null；理由码映射中文说明。
- 推荐独立加载，失败/为空不阻塞食堂目录；提供重试。
- 首页横向最多展示 5 条；点击进入菜品详情。
- 图片 URL 按 API origin 解析；真实加载/缓存仍受 Cookie 与媒体策略约束。

## 验证边界

- 单元测试覆盖推荐响应解码与路径。
- 未执行：真实推荐批次/日期切换、Apple Simulator 横向滚动、图片/空推荐/503、Apple 平台缓存。
- `capability:catalog` 的每日推荐部分未标 verified；真实后端与设备验收待联调。
