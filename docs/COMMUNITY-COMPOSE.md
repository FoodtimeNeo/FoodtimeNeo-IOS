# 社区发帖（W4）

实现：`Sources/Features/Community/CommunityComposeView.swift`、`CommunityComposeViewModel.swift`、`Sources/Platform/MultiPhotoPicker.swift`、`Sources/Data/Community/RemoteCommunityService.swift`。

## 流程

1. 社区 Tab → “写食记”。
2. 标题 1–50、正文 1–2000、最多 9 张本人图片。
3. 图片逐张压缩/上传为私有引用，再 `POST /community/posts`：
   `{title,content,imageUrls,clientRequestId}`；202 返回 `{id}`，pending 待审。
4. 通过后出现在社区信息流；审核状态可在“我的食记”查看（后续分支）。

## 边界

- 标题、正文、图片数量由服务端最终校验；空标题/正文、超过 9 张、他人图片引用会失败。
- `clientRequestId` 随标题/正文/图片变化重置；相同载荷重试应复用编号（当前实现随内容变化重置）。
- 上传成功不等于发帖成功；失败保留已选图片可重试。
- 本机草稿已接入：每账号一份 JSON + 图片文件，500ms 防抖自动保存，退出登录保留，账号注销清理；空白草稿不保存；发布成功清除；可显式删除草稿。
- 帖子修改/置顶、转发创建、关联菜品仍在后续 W4 分支。

## 验证边界

- 单元测试覆盖创建帖子 body/路径/请求号、草稿按账号保存/读取/图片/清理。
- 未执行：真实多图上传/审核流转、Apple Simulator 多选/键盘/九图布局、真实注销清理与草稿残留。
- `capability:community-feed` 的发帖部分未标 verified。
