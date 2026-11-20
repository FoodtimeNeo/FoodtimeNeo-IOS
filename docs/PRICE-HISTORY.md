# 菜品价格历史（W2）

实现：`Sources/Features/Catalog/PriceHistoryView.swift`、`PriceHistoryViewModel.swift`、`Sources/Domain/Models/PriceHistory.swift`、`Sources/Data/Catalog/RemoteCatalogService.swift`。

## 接口

`GET /dishes/{id}/price-history?days=0|30|90`，返回：

- `dishId/dishName/currentPrice/priceUnit/revision/windowStart/windowEnd/canManage/totalRecords/records`。
- `records[]`：`id/price/priceUnit/recordedAt/origin/revision/carriedForward`；price 可为 null。
- 价格单位：`unspecified/serving/piece/bowl/jin/100g/kg`。

## 渲染规则

- 单位变化或 price=null 会切断当前阶梯；null 不按 0 绘制。
- 相邻同价合并，但价格回落保留；首个点从记录时间/窗口起点开始，延伸到窗口结束。
- `carriedForward` 表示区间前沿用；`origin=admin` 表示管理更正。
- 客户端展示当前价/单位、记录数、阶梯图、单位图例和记录列表；`canManage` 只提示，管理更正/删除在 W6 接入。
- 图表用 Canvas 绘制网格、阶梯线、点和日期轴；价格/时间未知时不伪造数据。

## 验证边界

- 单元测试覆盖单位切换/null 断线/同价合并/窗口起点终点，以及接口 days 查询与解码。
- 未执行：真实测试后端 30/90 天数据、Apple Simulator 图表可读性/动态字体、管理更正/删除/冲突、极端长窗口与空记录。
- `capability:prices` 未标 verified；管理编辑/删除、审计和真实历史数据仍待 W6/联调。
