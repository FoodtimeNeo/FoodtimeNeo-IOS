# 本地开发、构建与测试

## 1. 工具链

| 工具 | 版本/要求 | 用途 |
|---|---|---|
| macOS | 26（CI） | Apple 工具链；本地无 Mac 时由 CI 验证 |
| Xcode | 26.6 或兼容版本 | iOS 17 SDK 编译、模拟器 |
| XcodeGen | 2.48.0 | 从 `project.yml` 生成 `.xcodeproj` |
| Swift | Xcode 自带，工程语言模式 5 | 源码编译 |
| Python | 3.10+ | 仓库检查、层边界检查 |
| GitHub Actions | `macos-26` | 编译与单元测试 |

工程文件不提交；修改 target/设置时改 `project.yml`，不要手改生成物。

## 2. 常用命令

```sh
# 生成工程
xcodegen generate

# 层边界检查
python3 scripts/check_ios_architecture.py

# 仓库记录检查
python3 scripts/check_repository.py
python3 scripts/check_repository.py --upstream

# 编译（模拟器）
xcodebuild -project FoodtimeNeo.xcodeproj -scheme FoodtimeNeo \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# 单测（选择可用模拟器）
xcrun simctl list devices available
xcodebuild -project FoodtimeNeo.xcodeproj -scheme FoodtimeNeo \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

CI 使用 `xcodebuild` + `xcbeautify`；`ios-ci.yml` 会安装 XcodeGen、生成工程、检查层边界、编译并运行单测。

## 3. 服务地址与账号

- 默认 `https://bjtufoodtime.top/api/v1/`。
- Debug 可在 Scheme 环境变量设置 `FOODTIME_API_BASE_URL` 指向本地/测试 Backend；Release 仍必须 HTTPS。
- 生产只做只读冒烟；登录、投稿、审核、删除等写入必须连专用测试库，禁止写线上数据。
- 不提交账号密码、Cookie、证书、描述文件或真实用户数据。

## 4. 目录与分层

见 [ARCHITECTURE.md](ARCHITECTURE.md)。新增页面时：

1. 先在 Domain 定义需要的模型/接口（如无）；
2. 在 Data 映射真实 DTO 与错误；
3. 在 Features 写页面状态与视图；
4. 在 SharedUI 复用令牌/控件；
5. 补单元测试与错误/空/加载状态；
6. 更新 coverage 记录与 PR 证据。

## 5. 测试分层

| 层 | 位置 | 当前状态 |
|---|---|---|
| 单元测试 | `Tests/Unit` | 已接入网络包络/错误/204/401/429/CSRF/会话/格式化 |
| Domain/Data 契约 | 后续 `Tests/Unit` 或独立 target | 待 W1–W3 |
| 真实测试后端 | 专用环境 | 未执行 |
| Apple Simulator UI | 后续 UITests target | 未执行 |
| 真机/相册/通知/BGTask | 真机 | 未执行 |

新增测试应验证行为与边界，不照抄实现；网络测试用 `StubHTTPTransport`，不依赖线上服务。

## 6. 签名、版本与分发

- 当前 `DEVELOPMENT_TEAM` 留空，模拟器构建不需要签名。
- Bundle ID 占位 `cn.edu.bjtu.foodtime`；真机/TestFlight 前确认 Apple Developer Team、证书与描述文件。
- `MARKETING_VERSION` 暂为 `0.1.0`，`CURRENT_PROJECT_VERSION` 为 `1`；正式版本号、构建号和 α/β 展示规则待确认。
- iOS 不能应用内安装 IPA；更新走 TestFlight/App Store/MDM，应用内只展示版本或商店链接。

## 7. 证据与提交

- 功能 PR 记录：对应 Android SHA、coverage ID、实现文件、测试命令与结果、未执行项、平台差异与批准依据。
- 构建产物、`*.xcresult`、`DerivedData` 不入库；临时脚本/日志/截图放工作区根 `test/`，不放仓库。
- 不把“仓库检查通过”或“CI 编译通过”写成 iOS 功能验收通过。
