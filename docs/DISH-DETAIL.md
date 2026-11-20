# 菜品详情与图册（W2）

实现：`Sources/Features/Catalog/DishDetailView.swift`、`DishDetailViewModel.swift`、`Sources/Domain/Models/DishDetail.swift`、`Sources/Domain/Formatting/MediaURL.swift`。

## 接口

| 功能 | 接口 |
|---|---|
| 基础详情 | `GET /dishes/{id}`：名称、价格（可空）、简介、档口/食堂、revision |
| 图册 | `GET /dishes/{id}/images?page&size`：仅 approved 图片，`items/total/page/size` |
| 实时评分 | `GET /dishes/{id}/rating`：`averageScore`（可空）+`reviewCount` |

## 行为

- 详情/评分/图册分别加载；图册或评分失败不阻塞基础详情。父级不可见 404 显示错误与重试。
- 价格 null 显示“价格待补充”；评分 null 显示“暂无评分”。
- 首图作为头图；横向缩略图可点开全屏图册。
- 全屏图册：`TabView` 分页、双击 1x/2.5x、捏合 1–5x、放大后拖动；关闭按钮与页码。
- 图片 URL 可为绝对或同源 `/api/v1/media/...`，按 API origin 解析；同源图片依赖 URLSession 共享 Cookie。
- 当前一次请求图册 size=100；超过 100 张的后续分页、图片磁盘缓存/私有 no-store 策略在 W7 媒体波次补齐。

## 验证边界

- 单元测试覆盖详情/图册/评分解码、媒体 URL 绝对/同源解析。
- 未执行：真实图片加载/Cookie、Apple Simulator 手势与翻页、HEIC/方向、极长图、图册超过 100 张、动态字体/横屏。
- `capability:dish-media` 未标 verified；多图连续缩放、缓存和上传仍待 W7/后续专项。
