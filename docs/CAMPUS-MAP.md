# 校园食堂地图（W2）

实现：`Sources/Features/Map/CampusMapView.swift`、`CampusMapViewModel.swift`、`Sources/Domain/Models/CampusMap.swift`、`Sources/Platform/CampusMapAssets.swift`。

## 资源与范围

- 底图 `Resources/CampusMap/campus-map.webp`（5032×3579，来自 Android 资产）与 `regions.json`（六区域：明湖、学活／清真／西餐厅、留园、学四、东区学生、益民）。
- 底图来源为学校招生办手绘地图，仓库无明确再分发许可；**正式分发前需确认授权**。
- 仅复刻已确认的缩放/拖动/点选与目录入口；无 GPS、无路线导航、无楼层。

## 行为

- 首次进入加载 JSON 与底图；底图降采样到最长边 2600（Android 用 2 倍采样，全尺寸解码约 72 MB）。
- 双指缩放 1–6、拖动；放大/缩小/全图按钮；点选多边形按射线法命中。
- 区域名称按钮始终可用；底图加载失败时仍可读 JSON 并使用名称按钮。
- 选中区域显示名称与关联食堂入口；食堂列表读取失败可重试，地图仍可使用；无关联入口显示提示。
- 区域选择当前只在页面内保存，跨重启恢复与状态持久化留后续专项。

## 验证边界

- 单元测试覆盖多边形命中、缩放 clamp、map JSON 解码。
- 未执行：真实底图加载/降采样、Apple Simulator 双指/拖动/点选、iPad/横屏、底图失败降级、许可确认。
- `capability:map` 未标 verified；许可与真实设备验收仍待确认。
