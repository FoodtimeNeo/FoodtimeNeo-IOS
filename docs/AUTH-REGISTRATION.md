# 注册流程（W1）

实现：`Sources/Features/Auth/RegistrationView.swift`、`RegistrationViewModel.swift`、`Sources/Domain/Validation/RegistrationValidation.swift`、`Sources/Data/Auth/RemoteAuthService.swift`。

## 1. 流程

1. 登录页点“注册账号”，打开注册 sheet。
2. `GET /auth/registration-policy` 读取 `mode/canSendEmailCode/invitationRequired/revision`。读取失败不默认开放，显示错误与“重新读取策略”。
3. 用户填写邮箱，点“获取验证码”：`POST /auth/register/email-code`，带 Cookie + CSRF；202 返回 `{expiresAt,resendAfterSeconds}`。客户端按 `resendAfterSeconds` 倒计时（通常 60 秒）。
4. 用户提交邮箱、6 位验证码、密码、确认密码和邀请码（按策略必填/可选）：`POST /auth/register`，201 返回创建的用户。
5. 注册**不会自动登录**；成功卡片提示返回登录页，并把邮箱回填到登录框。

## 2. 字段与校验

- 邮箱：去除首尾空白、转小写；最多 254 位，客户端只做基本格式校验。邮箱域名白名单、是否已注册由服务器裁决。已注册与未注册邮箱的发码响应相同，客户端不能据此判断账号存在。
- 验证码：6 位 ASCII 数字；15 分钟有效、错误上限 5 次；重发成功后替换旧码。
- 密码：8–128 位 ASCII 可见字符（`!` 到 `~`），必须至少一个字母和一个数字，不允许空格/中文/emoji；登录不重新执行注册复杂度规则。
- 邀请码：12 位 `[A-HJ-NP-Z2-9]`（不含 I/O/0/1），大小写均可；`invitation` 模式必填，`open` 可选，`closed` 不显示表单。
- 策略 `canSendEmailCode=false` 时禁用发码；`closed` 时停止提交与发码。

## 3. 错误处理

| code | UI |
|---|---|
| `VALIDATION_ERROR` | 展示 `data` 字段原因 |
| `EMAIL_CODE_INVALID` | 提示验证码错误/过期/次数过多，需重新获取 |
| `EMAIL_ALREADY_REGISTERED` | 提示直接登录或找回密码 |
| `INVITATION_REQUIRED` / `INVITATION_CODE_INVALID` | 提示邀请码必填/无效 |
| `REGISTRATION_CLOSED` | 提示暂未开放并重新读取策略 |
| `REGISTRATION_IN_PROGRESS` | 提示该邮箱注册处理中，稍后重试 |
| `EMAIL_SEND_RATE_LIMITED` / `REGISTRATION_RATE_LIMITED` | 展示 `Retry-After` 并恢复倒计时 |
| `EMAIL_VERIFICATION_UNAVAILABLE` / `REGISTRATION_UNAVAILABLE` / `INVITATION_UNAVAILABLE` | 展示服务端消息，保留输入 |
| `CLIENT_UNKNOWN` | 提示后端需把 `ios` 加入 `X-Foodtime-Client` 白名单 |

CSRF 由 `APIClient` 自动获取；发码和注册都带 Cookie 与 CSRF。发送失败保留邮箱与已填内容；注册成功才清空密码/验证码。

## 4. 未决与验证边界

- Backend `CLIENT_HEADER_ALLOWED` 默认只有 `web,android`；线上若 `enforce`，注册/发码会 403 `CLIENT_UNKNOWN`。需后端加 `ios` 并确认模式。
- 邮箱域名白名单以服务端为准；当前文档 `email-verification.md` 的“仅 bjtu”文字与 R13 开放 QQ/163/Gmail 等不一致，客户端不硬编码域名。
- 未执行：真实 SMTP 投递、真实测试后端注册、Apple Simulator 键盘/验证码交互、失败并发与 409 占用场景。单元测试只覆盖请求/响应映射与本地校验。
