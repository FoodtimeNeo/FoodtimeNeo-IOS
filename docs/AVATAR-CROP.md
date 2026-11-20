# 头像裁剪与上传

实现：`Sources/Features/Profile/AvatarCropView.swift`、`Sources/Platform/AvatarCropRenderer.swift`、`Sources/Domain/Validation/AvatarCropGeometry.swift`、`Sources/Data/Profile/RemoteAvatarService.swift`。

对照 Android：`AvatarCropScreen`、`AvatarCropView`、`AvatarCropGeometry`、`PhotoImport.saveAvatar`；后端：`ImageStorageController`（`POST /uploads/avatars`）与 `docs/avatar-crop.md`。

## 流程

1. 编辑资料 →「更换头像」→ 系统相册选择一张原图。
2. 固定 1:1 方形选框：拖动平移、双指或滑杆缩放（1×–4×）、旋转 90°、重置。
3. 导出 512×512 JPEG（质量 0.9，≤10MB），`POST /uploads/avatars`（multipart `file`，Cookie + CSRF）返回本人私有暂存引用。
4. 返回编辑资料页，展示新头像预览；点「保存」才 `PUT /users/me/profile` 携带 `avatarUrl` 更新。
5. 取消不改变原头像；上传成功但未保存也不会更新资料。只改昵称时保留历史头像。

## 几何与导出

- `AvatarCropGeometry` 与 Android 同公式：方形边长 = `min(视口宽,高) - 32`，缩放按旋转后的宽高取 cover，zoom 夹在 1–4，pan 以边长比例表示并夹在图片边缘。
- 预览与导出共用同一布局；导出把同一变换绘制到 512×512 画布，保证所见即所得。
- 原图只在本机解码并重新编码；不保留元数据（导出走 JPEG 重编码）。
- 旋转 90°/270° 时按交换后的宽高计算 cover。

## 错误与边界

- 视口未完成布局时不允许导出。
- 图片处理失败、超过 10MB、服务端返回非 `/api/v1/media/{uuid}` 引用、限流/存储故障都显示服务端或本地错误。
- 上传成功后再次选择头像会重新上传，旧暂存文件由服务端清理任务处理。
- 账号切换/注销后未保存的头像引用不写入资料；`PUT` 仍由服务端校验本人归属与 512×512。

## 验证边界

- 单元测试：几何的缩放/平移夹取与旋转换轴；导出 512×512 JPEG、旋转/缩放/平移组合与非法视口；头像上传端点、multipart、CSRF 与非法引用拒绝。
- 本地架构检查与仓库检查通过；编译/单测由 macOS CI 执行。
- 未执行：Apple Simulator 相册/触摸拖动/双指缩放、真实后端头像保存与读取、HEIC 输入、iPad/横屏、动态字体与真机。

## 平台差异

- iOS 使用 PHPicker + SwiftUI 手势，不请求相册全库权限；与 Android 的系统相册流程等效。
- 头像更新不参与 APK/测试版更新逻辑；更新与分发仍待确认（见 `docs/IOS-DECISIONS.md`）。
