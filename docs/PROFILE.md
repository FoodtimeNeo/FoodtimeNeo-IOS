# 个人资料（W1 基础）

实现：`Sources/Features/Profile/ProfileEditView.swift`、`ProfileEditViewModel.swift`、`Sources/Domain/Models/UserProfile.swift`、`Sources/Domain/Validation/ProfileValidation.swift`。

## 范围

- `GET /users/me/profile`：读取当前用户资料、关注/粉丝数、学校邮箱与认证状态；身份来自会话，不接受客户端指定用户 ID。
- `PUT /users/me/profile`：整体替换 `displayName` 与 `avatarUrl`；昵称去首尾空白后 1–50 字符。
- 当前只支持修改昵称。保存时把现有 `avatarUrl` 原样带回，避免“只改昵称却清空头像”；头像上传/裁剪/删除在媒体波次接入。
- 成功后更新 `AppSession` 的当前用户，个人页昵称立即刷新。

## 契约要点

- `PUT` 必须同时处理 `avatarUrl`：服务端把缺失/`null` 视为清除头像。iOS 自定义编码器总是写出 `avatarUrl` 键；有值传同站 `/api/v1/media/{id}`，无值传 `null`。
- `avatarUrl` 必须是本人上传的同站引用；站外地址或他人引用由服务端 400 拒绝。
- 昵称不允许空；服务端上限 50，客户端先做同样的形状校验。
- 读取失败显示重试；保存失败保留输入，不把失败当成功。
- `401` 由全局会话处理回登录；`403`/`503` 显示服务端消息。

## 验证边界

- 单元测试覆盖资料解码、`avatarUrl` 显式 null 编码、昵称校验、保存后会话用户刷新。
- 未执行：真实测试后端资料写入、头像上传/裁剪、Apple Simulator 表单与动态字体、管理端用户详情。
- 头像、学校邮箱绑定/解绑、账号注销仍属后续 W1 子项；本阶段不把 `capability:profile-social` 标为 verified。
