# 后端接入与协议约束

参照：Backend main `e8f34998930781230711d8e8dd109c32d34b1ba8`（2026-11-20 核对）、Android main `32215aab`。本文描述 iOS 已接入的部分和不能偏离的契约；具体业务规则以最新 Backend 文档/Controller/DTO 与 Android 行为交叉核对为准。

## 1. 基址与传输

- 默认 `https://bjtufoodtime.top/api/v1/`；Debug 可用 `FOODTIME_API_BASE_URL` 覆盖，Release 必须 HTTPS。
- 请求与响应 UTF-8 JSON；统一响应 `{code,message,data,timestamp,requestId}`，成功 `code=OK`；响应头含 `X-Request-Id`。
- 每个请求发送 `X-Foodtime-Client: ios` 和 `X-Request-Id`（UUID）。CSRF 头名从 `/auth/csrf` 的 `headerName` 读取，缺失时回退 `X-CSRF-TOKEN`。
- 不跟随重定向；请求必须留在配置的 API origin；API 请求不使用本地缓存。连接约 5 秒、读取约 10 秒、上传可到 180 秒；响应体上限 20 MB。
- **204/205 空 body 是成功**，`sendVoid` 不解析 JSON。Android 旧实现会把空 body 当异常，iOS 不复制；该缺陷影响历史记录、收藏分组删除、通知 delivered 等端点。

## 2. 会话、Cookie 与 CSRF

- 会话 Cookie `FOODTIME_SESSION`：HttpOnly、SameSite=Lax、Path=/、生产 Secure、默认 7 天固定到期。
- 设备 Cookie `foodtime_device`：HttpOnly、生产 Secure、SameSite=Lax、默认 365 天，用于登录/验证码限流。退出只清会话 Cookie，**保留设备 Cookie**；iOS 按服务端有效期保存，不复制 Android 统一截断 7 天的做法。
- 登录顺序：`GET /auth/csrf` → `POST /auth/login`（Cookie + CSRF，可选 `challengeId`/`challengeAnswer`）→ 成功后重新 `GET /auth/csrf` → `GET /auth/me` → `GET /users/me/capabilities`。
- 登录会替换整个会话，旧 CSRF 失效；CSRF 只存内存，不落盘。`403 CSRF_INVALID` 会清缓存，但不自动重放写请求。
- 401 清会话与内存私有数据并回登录；403 区分 `CSRF_INVALID`/`ACCESS_DENIED`/`RESTRICTED_SESSION`；429 读取 `Retry-After`；503 显示服务端消息。
- 停用账号正确密码登录返回 `sessionMode=appeal_only`，45 分钟绝对到期，只允许本人决定/申诉、证据上传/读取、CSRF、登录、退出；iOS 用独立会话状态处理。
- 注册：先 `GET /auth/registration-policy`，按 `mode` 决定是否显示邀请码；`POST /auth/register/email-code` 与 `POST /auth/register` 都带 Cookie/CSRF。注册成功不自动登录；客户端不硬编码邮箱域名白名单，账号是否存在只由服务端裁决。

## 3. 客户端标识（待后端确认）

Backend `CLIENT_HEADER_ALLOWED` 默认只有 `web,android`，`CLIENT_HEADER_MODE` 默认 `observe`。iOS 发送 `ios`；在 `observe` 下只记日志，若线上切到 `enforce`，`/auth/register` 与 `/auth/register/email-code` 会返回 403 `CLIENT_UNKNOWN`。上线前需：

1. 把 `ios` 加入服务端 `CLIENT_HEADER_ALLOWED`；
2. 确认线上 `CLIENT_HEADER_MODE`；
3. 不以 `android`/`web` 冒充 iOS。

## 4. 错误映射

| HTTP | code | iOS 处理 |
|---|---|---|
| 400 | `VALIDATION_ERROR` | `AppError.validation`，展示 `data` 字段原因 |
| 400 | `CAPTCHA_REQUIRED` / `CAPTCHA_INVALID` | 业务错误 + 重新取题 |
| 401 | `UNAUTHENTICATED` | 清会话、能力、私有缓存，回登录 |
| 401 | `INVALID_CREDENTIALS`（登录） | 业务错误，不触发会话清理 |
| 403 | `CSRF_INVALID` / `ACCESS_DENIED` | 展示服务端消息；清 CSRF 缓存，不自动重放写请求 |
| 429 | `*_RATE_LIMITED` | 展示 `Retry-After` |
| 503 | `*_UNAVAILABLE` / `AUTH_UNAVAILABLE` | 展示可重试状态，保留旧内容 |
| 500 | `INTERNAL_ERROR` | 通用错误，不展示内部细节 |

## 5. 分页、时间与金额

- 普通分页 `items/total/page/size`、数字页码与 cursor `items/nextCursor/hasMore` 分开建模，不能互相猜字段。
- 时间使用 ISO 8601（带/不带小数秒）；用户展示按 Asia/Shanghai，业务日界不由设备本地时区推断。
- 金额用 `Decimal`；`price=null` 是“待补充”，不能当 0；`averageScore=null` 显示“暂无评分”，`reviewCount=0` 保留。

## 6. 当前已接入的只读接口

| 功能 | 接口 |
|---|---|
| CSRF / 登录 / 当前用户 / 退出 | `GET /auth/csrf`、`POST /auth/login`、`GET /auth/me`、`POST /auth/logout` |
| 验证码 | `GET /auth/captcha` |
| 注册策略 | `GET /auth/registration-policy` |
| 注册邮箱验证码 | `POST /auth/register/email-code`（202，返回 `expiresAt/resendAfterSeconds`） |
| 注册 | `POST /auth/register`（201，返回用户，不自动登录） |
| 找回密码 | `POST /auth/password-reset/email-code`、`/verify`、`/password-reset` |
| 修改密码 | `PUT /users/me/password`（成功后当前会话失效） |
| 个人资料 | `GET/PUT /users/me/profile`（PUT 整体替换昵称与头像引用） |
| 账号生命周期 | `GET /users/me/account-lifecycle`、`/deletion-code`、`/unbind-code`、`/delete`、`/unbind` |
| 学校邮箱 | `POST /auth/bind-email/email-code`、`POST /users/me/bind-email` |
| 社交 | `GET /users/search`、`/users/{id}/following|followers`、`PUT/DELETE /users/{id}/follow` |
| 黑名单 | `GET /users/me/blocks`、`PUT/DELETE /users/{id}/block` |
| 反馈 | `POST/GET /users/me/feedback`、详情、回复历史 |
| 能力 | `GET /users/me/capabilities` |
| 食堂/档口/菜品 | `GET /dining-halls`、`GET /dining-halls/{id}/stalls`、`GET /stalls/{id}/dishes` |

## 7. 验证要求

- 单元测试用 `StubHTTPTransport` 覆盖成功包络、204、400 校验、401、429、CSRF 取题/附加、格式异常。
- 真实后端联调必须使用专用测试环境；生产只做只读冒烟，不写入线上数据。
- 每个功能 PR 记录对应 Android SHA、coverage ID、实现位置、验证环境、未执行项和平台差异。
