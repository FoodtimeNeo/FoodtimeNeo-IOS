# 媒体与缓存（W7）

## 当前实现

- 图片请求走系统 `AsyncImage`/`URLSession.shared`，遵循服务端 `Cache-Control: private, max-age=300, must-revalidate` 与 ETag；未另建磁盘缓存或第三方图片库。
- 服务端 `no-store` 的待审/暂存图不进入缓存。
- 身份边界：`APIClient.invalidateSession()` 在登出、401、改密、注销时清除会话 Cookie、CSRF 与 `URLCache.shared`，避免上一账号的私有图片/响应残留。
- 图片上传前统一由 `ImageProcessor.jpegData` 归一化方向、降采样与 JPEG 压缩；HEIC 输入由 `UIImage` 解码。
- 头像裁剪（peer `feature/avatar-crop`）与食记分享（`feature/w7-share`）独立分层，不改变媒体缓存策略。

## 未做的决策

- 是否延长公开社区图片 TTL（例如 1 小时）以换取删除后仍可见窗口，仍待产品确认；当前不修改服务端头。
- 是否引入自建内存/磁盘图片缓存与容量淘汰；当前使用系统缓存，切后台不清空（与 Android 决策一致）。
- 证据图/私信图片是否排除共享 URLCache；当前依赖身份清理与 `no-store`，未按图片类别分池。
- 未接入后台下载、预取或离线阅读。

## 验证边界

- 本地静态检查通过；未执行 Instruments、真实弱网、切号后图片请求审计。
- 清理逻辑由每次会话失效路径统一触发；没有独立的缓存命中率测试。
- 对齐条目保持 `in-progress`，不标 verified。
