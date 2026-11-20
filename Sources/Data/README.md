# Data

HTTP、Cookie/CSRF、DTO 映射与远端服务；不向页面泄露数据库实体。

当前：`APIClient`（包络/错误/204/CSRF/epoch）、`URLSessionTransport`（禁重定向、超时）、`SystemCookieJar`、`RemoteAuthService`、`RemoteCatalogService`。Cookie 的 Keychain 归档在 `Platform`，由 `App` 组装。
