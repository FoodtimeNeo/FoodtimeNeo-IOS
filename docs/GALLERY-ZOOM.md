# 图片查看的连续缩放与双击

实现：`Sources/Features/Catalog/DishDetailView.swift` 的 `ZoomableRemoteImage`、`Sources/Domain/Validation/GalleryZoomGeometry.swift`。

对照 Android：`CommunityPhotoDialog.PhotoCanvas` 的双击连续放大/还原（G1-ZOOM）；Web 端像素级动画以 iOS 手势等效实现。

## 行为

- 双击：未放大时以点击位置为锚点，平滑放大到 2.5×；已放大时平滑还原到 1×。
- 双指缩放：1×–5×，松手后保持；缩到接近 1× 自动回正。
- 拖动：仅放大后可平移，偏移限制在缩放后的内容边界内，避免图片被拖出视口。
- 图册仍支持左右翻页；缩放状态按页独立，切换页面不串用。
- 加载失败/加载中保留原有状态提示。

## 边界与取舍

- 海报比例图片在 `scaledToFit` 下两侧有留白；平移边界按容器而非真实图片像素计算，极端比例下允许少量留白区域拖动。未引入图片尺寸回调以避免额外加载。
- 动画使用 0.28s 缓入缓出；不承诺 Android 逐帧插值的像素一致性。
- 双击锚点使用视图坐标，旋转/横屏后重新按当前容器计算。

## 验证边界

- 单元测试：居中/边缘锚点、缩放边界夹取、未放大时零偏移。
- 本地架构检查与仓库检查通过；编译/单测由 macOS CI 执行。
- 未执行：Apple Simulator 双击/捏合/翻页组合、大图内存、动态字体与无障碍缩放手势、真机。
