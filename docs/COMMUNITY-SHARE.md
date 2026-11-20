# 社区分享（W7 平台适配）

实现：`Sources/Domain/Formatting/CommunityShareLink.swift`、`CommunityDetailView` 工具栏 `ShareLink`。

## 行为

- 仅 `approved` 食记显示分享按钮；与 Android 一致，分享内容为公开网页链接：
  `https://bjtufoodtime.top/community/posts/{uuid}`。
- 使用系统 `ShareLink`（UIActivityViewController），不接入第三方分享 SDK。
- 链接只由帖子 UUID 构造，不携带会话 Cookie、邮箱或管理端字段。
- 分享动作本身不发网络请求，不产生浏览记录。

## 平台差异

- Android 通过 `ACTION_SEND` + chooser；iOS 使用系统分享面板，行为等效。
- Android 图片查看器也有分享按钮，iOS 在图册中未单独放分享；详情页工具栏覆盖同一帖子分享路径。若需要图册内分享，后续可加。

## 验证边界

- 单元测试覆盖链接格式与基础编码。
- 未执行：Apple Simulator、真实系统分享面板、打开分享链接的 Web 落地页。
- 对齐条目保持 `in-progress`。
