# 图片上传与菜品图片投稿（W3）

实现：`Sources/Features/Submissions/ImageSubmissionView.swift`、`Sources/Platform/PhotoPicker.swift`、`ImageProcessor.swift`、`Sources/Data/Submissions/RemoteSubmissionService.swift`。

## 流程

1. 菜品详情 → “上传图片” → 系统相册选择（PHPicker，无需整库权限）。
2. 客户端归一化方向、最长边压到 1600、JPEG 90%；HEIC 转 JPEG。
3. `POST /uploads/images` multipart 字段 `file`，Cookie + CSRF；201 返回 `{id,imageUrl,width,height}`。
4. `POST /dishes/{id}/image-submissions` `{imageUrl}`；201 pending。
5. 审核通过后进入公开图册；待审/驳回只有作者/管理员可读。

## 边界

- 服务端只接受 JPEG/PNG、≤10MB/2000 万像素；上传为私有暂存，不直接公开。
- `imageUrl` 必须为本人上传的 `/api/v1/media/{id}` 引用；站外/他人引用由服务端拒绝。
- 上传/投稿限流：上传默认每人每小时 10 次，投稿与点评共用配额；429 带 `Retry-After`。
- 图片上传成功不等于投稿/审核成功；失败保留已选图片可重试。
- 相册多选、裁剪、头像/档口封面、菜品/档口投稿与“我的提交”在后续分支接入。

## 验证边界

- 单元测试覆盖 multipart 构造、上传响应、图片投稿 body、我的图片投稿分页。
- 未执行：真实相册/HEIC/方向、真实上传与审核、Apple Simulator 权限/键盘、10MB/2000 万像素边界、失败重试。
- `capability:submissions` 未标 verified。
