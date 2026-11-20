# 找回与修改密码（W1）

实现：`Sources/Features/Auth/PasswordRecoveryView.swift`、`PasswordRecoveryViewModel.swift`、`ChangePasswordView.swift`、`ChangePasswordViewModel.swift`、`Sources/Domain/Validation/PasswordValidation.swift`、`Sources/Data/Auth/RemoteAuthService.swift`。

## 1. 找回密码（匿名）

1. 登录页“忘记密码？”打开找回 sheet。
2. `POST /auth/password-reset/email-code`，body `{email}`，Cookie + CSRF；202 返回 `{expiresAt,resendAfterSeconds}`。请求已受理的响应与账号是否存在无关。
3. `POST /auth/password-reset/verify`，body `{email, verificationCode}`；成功返回 `{resetToken, expiresAt}`（resetToken 43 位 `[A-Za-z0-9_-]`）。resetToken 只在内存保存，不写日志/磁盘/状态恢复。
4. `POST /auth/password-reset`，body `{resetToken, newPassword}`；成功后所有设备需重新登录。
5. UI 三步：验证邮箱 → 设置新密码 → 成功返回登录；可“更换邮箱 / 重新验证”丢弃 token。

规则/错误：

- 验证码 6 位数字、10 分钟有效（以服务端 `expiresAt` 为准）；`PASSWORD_RESET_CODE_INVALID`、`PASSWORD_RESET_TOKEN_INVALID`、`PASSWORD_RESET_UNAVAILABLE`。
- 发码限流 `EMAIL_SEND_RATE_LIMITED`，按 `Retry-After` 恢复倒计时。
- 新密码 8–128 位 ASCII、至少一个字母和一个数字；两次输入一致。服务端仍是最终裁决者。
- token 过期/失效时回到验证邮箱步骤，不继续提交。

## 2. 修改密码（登录后）

- 我的 → “修改密码”。
- `PUT /users/me/password`，body `{oldPassword, newPassword}`，Cookie + CSRF。
- 旧密码只做 8–128 位 ASCII 传输校验，不重新执行注册复杂度；新密码与注册规则一致且不能与旧密码相同。
- 成功：服务端注销当前会话；iOS 立即清 Cookie/能力/私有状态并回登录页。
- 错误：`OLD_PASSWORD_INCORRECT`、`PASSWORD_UNCHANGED`、`PASSWORD_CHANGE_CONFLICT`（重新登录后再试）、`PASSWORD_CHANGE_RATE_LIMITED`（`Retry-After`）、`PASSWORD_CHANGE_UNAVAILABLE`。
- 网络中断/503 时不能仅凭响应断定是否已改密；提示用户用新密码尝试登录，不自动重复提交敏感操作。

## 3. 验证边界

- 单元测试覆盖重置 token/验证响应、修改密码 PUT/CSRF/body、密码与 token 校验、改密后清本地会话。
- 未执行：真实 SMTP 投递、真实测试后端找回/改密、Apple Simulator 键盘与错误提示、限流/并发 409 实测。
- 找回/改密都属于 `capability:auth`；本阶段不把 coverage 标为 verified。
