# 搜菜筛选与排序（W2）

实现：`Sources/Features/Catalog/DishSearchView.swift`、`DishSearchViewModel.swift`、`Sources/Data/Catalog/RemoteCatalogService.swift`、`Sources/Domain/Models/DishSearch.swift`。

## 接口

`GET /dishes/search?q&diningHallIds&minPrice&maxPrice&minRating&sort&page&size`

- `q` 去首尾空白，最多 50 字；空关键词浏览全部启用菜品。
- `diningHallIds` 可重复；iOS 以重复 query 参数发送。
- `minPrice/maxPrice` 十进制，0 有效；`minPrice <= maxPrice`。
- `minRating` 0–5；UI 档位不限/3.0/3.5/4.0/4.5。
- `sort` 仅 `relevance/price_asc/price_desc/rating_desc`。
- `page>=1`、`1<=size<=100`；客户端固定 20/页。

## 行为

- 只返回启用食堂/档口/菜品；价格或评分未知的菜品保留并排在完整数据之后；`price=null` 显示“价格待补充”，评分 null 显示“暂无评分”。
- 客户端校验关键词长度、价格格式/非负、最低价不高于最高价；排序白名单、评分/分页最终由服务端裁决。
- 关键词 300ms 防抖；筛选变化重置到第 1 页；结果为空/加载/错误三态显式。
- 筛选 sheet 支持食堂多选、价格区间、最低评分、排序；重置只清筛选，不清关键词。
- 结果行展示菜名、食堂·档口、价格、评分；详情跳转在 W2 的详情/图册分支接入。

## 验证边界

- 单元测试覆盖搜索 query（关键词、重复食堂 ID、价格、评分、排序、分页）与响应解码、食堂列表读取。
- 未执行：真实测试后端筛选/排序、未知价格/评分分页边界、Apple Simulator 键盘/筛选 sheet、返回状态恢复与数字页码（R08/R10 仍待补齐）。
- `capability:search` 未标 verified；返回页码/滚动恢复与数字省略分页仍待后续专项。
