# 学校邮箱与账号注销（W1）

实现：`Sources/Features/Account/AccountSecurityView.swift`、`AccountSecurityViewModel.swift`、`Sources/Domain/Models/AccountLifecycle.swift`、`Sources/Domain/Validation/SchoolEmailValidation.swift`。

## 1. 入口与前置

- 我的 → “账号安全与注销”；管理员/超级管理员不显示入口，服务端也返回 `ACCOUNT_ACTION_FORBIDDEN`。
- `GET /users/me/account-lifecycle`：`verificationEmail`、`schoolEmail`、`canDelete`、`canUnbind`、`deletionCodeAvailableAt`。
- 未绑定学校邮箱时显示绑定卡片；已绑定显示解绑卡片；`canDelete=false` 时只显示受限说明。

## 2. 学校邮箱

- 绑定：`POST /auth/bind-email/email-code`（202，`{expiresAt,resendAfterSeconds}`）→ `POST /users/me/bind-email` `{email,verificationCode}`；只接受数字 `@bjtu.edu.cn`，返回更新后的 ProfileResponse。
- 解绑：`POST /users/me/account-lifecycle/unbind-code`（202，`{expiresAt,nextSendAt,verificationEmail}`）→ `POST /users/me/account-lifecycle/unbind` `{verificationCode}`；返回 `{profile,schoolEmailReusableAt}`。
- 解绑 60 秒后可重发；学校邮箱冷却 1 小时后可重新绑定。成功后刷新会话用户（visitor 角色变化会反映到界面）。
- 错误：`SCHOOL_EMAIL_ALREADY_BOUND`、`SCHOOL_EMAIL_TAKEN`、`SCHOOL_EMAIL_NOT_BOUND`、`ACCOUNT_ACTION_CODE_INVALID`、`ACCOUNT_ACTION_FORBIDDEN`、`EMAIL_SEND_RATE_LIMITED`。

## 3. 注销账号

- `POST /users/me/account-lifecycle/deletion-code`（202，`{expiresAt,nextSendAt,verificationEmail}`）→ `POST /users/me/account-lifecycle/delete` `{verificationCode}`。
- 注销验证码每天只能成功发送一次（UTC+8 00:00 重置），15 分钟有效；`deletionCodeAvailableAt` 在未来时禁用再次发送。
- 注销立即生效、不可撤销；内容显示“已注销用户”，旧会话失效；登录邮箱与学校邮箱冷却 1 小时后可重新注册/绑定，新账号不继承旧数据。
- 成功后清本地 Cookie/能力并回登录页；登录页显示注销回执（含邮箱可重新使用时间）。
- 错误：`DELETION_CODE_DAILY_LIMIT`、`ACCOUNT_ACTION_CODE_INVALID`、`ACCOUNT_ACTION_IN_PROGRESS`、`ACCOUNT_ACTION_FORBIDDEN`。

## 4. 验证边界

- 单元测试覆盖资料/注销/解绑接口路径与 body、学校邮箱格式、注销后清会话与回执、解绑后刷新会话用户。
- 未执行：真实邮件投递、真实测试后端注销/解绑、Apple Simulator 表单与确认弹窗、1 小时冷却与每日一次计数的实测。
- 账号注销是 App Store 审核要求的重要路径；真实环境验收必须使用专用测试账号，不能操作线上真实用户。
