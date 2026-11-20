# FoodtimeNeo iOS · 北交干饭吧

目标是完整复刻 Android 客户端的功能、业务规则和手账风格，并持续跟进 Android 后续更新。普通用户、访客、管理员和超级管理员的能力都属于范围，不能只实现首页或普通用户流程。

## 当前状态（2026-11-20，`feature/ios-foundation`）

本分支建立**工程底座与首个只读纵切片**，不是全量对齐：

- 已建立 XcodeGen 工程（`project.yml`）、SwiftUI 外壳、Tab/导航、手账色板与基础控件。
- 已接入网络层：`/api/v1`、统一响应包络、错误映射、`X-Request-Id`、`X-Foodtime-Client: ios`、Cookie 会话、CSRF、204/205 空 body、超时与禁止重定向。
- 已接入会话：Keychain Cookie 归档、首启清理、登录/验证码、冷启动恢复、`appeal_only` 受限会话、能力快照与 401 清理。
- 已实现食堂 → 档口 → 菜品三级只读浏览，以及个人页的账号信息、能力展示和退出登录。
- W1 注册：注册策略、邀请码、邮箱验证码、密码校验、注册成功返回登录；详见 [注册流程](docs/AUTH-REGISTRATION.md)。
- W1 密码：找回密码三步（发码/验证得 token/重置）与登录后修改密码；详见 [找回与修改密码](docs/AUTH-PASSWORD.md)。
- W1 资料：读取资料/关注粉丝/学校邮箱状态，修改昵称并保留现有头像引用；详见 [个人资料](docs/PROFILE.md)。
- W1 账号安全：学校邮箱绑定/解绑与账号注销（每日一次注销验证码、1 小时邮箱冷却）；详见 [账号安全](docs/ACCOUNT-SECURITY.md)。
- W1 社交：关注/粉丝、用户搜索、黑名单与拉黑/解除；详见 [关注与黑名单](docs/SOCIAL.md)。
- W1 反馈：提交建议/反馈、未完成/已完成列表、详情与回复历史；详见 [建议与反馈](docs/FEEDBACK.md)。
- W2 搜菜：关键词、食堂多选、价格区间、最低评分、排序与分页；详见 [搜菜筛选](docs/DISH-SEARCH.md)。
- W2 详情/图册：菜品详情、评分、缩略图与全屏缩放图册；详见 [菜品详情与图册](docs/DISH-DETAIL.md)。
- W2 价格历史：全部/30/90 天、单位与 null 分段、阶梯图与记录列表；详见 [价格历史](docs/PRICE-HISTORY.md)。
- W2 校园地图：六区域底图、缩放/拖动/点选、食堂入口；详见 [校园地图](docs/CAMPUS-MAP.md)（底图再分发许可待确认）。
- W2 每日推荐：独立加载的今日推荐横向卡片；详见 [每日推荐](docs/RECOMMENDATIONS.md)。
- W3 菜品点评：已发布点评、提交审核、点赞、我的点评/审核记录；详见 [菜品点评](docs/DISH-REVIEWS.md)。
- W3 点评回复：楼中楼、回复点赞、我的回复/审核状态；详见 [点评回复](docs/REVIEW-REPLIES.md)。
- W3 一键点评：食堂首页入口、搜菜选菜、复用点评表单；详见 [一键点评](docs/QUICK-REVIEW.md)。
- W3 食堂/档口点评：评分汇总、筛选、提交、点赞、我的评价状态；详见 [食堂/档口点评](docs/VENUE-REVIEWS.md)。
- W3 图片投稿：相册选择、方向归一/压缩、multipart 上传、菜品图片投稿；详见 [图片上传与投稿](docs/IMAGE-SUBMISSIONS.md)。
- W3 目录投稿：菜品/档口投稿与我的菜品/档口/图片投稿；详见 [目录投稿](docs/CATALOG-SUBMISSIONS.md)。
- W4 社区：信息流（发现/关注/搜索）、详情、评论、楼中楼回复、点赞/收藏/浏览量；详见 [社区](docs/COMMUNITY.md)。
- W4 社区发帖：多图选择/上传、标题/正文、每账号本机草稿、pending 审核；详见 [社区发帖](docs/COMMUNITY-COMPOSE.md)。
- 已接入 macOS CI：`xcodegen generate` → 层边界检查 → `xcodebuild build` → 单元测试。
- **尚未实现**：帖子修改/置顶、收藏分组、历史、私信/通知（并行会话在做）、举报申诉、管理端、完整媒体/分享等。`docs/parity/coverage.json` 的 102 项目标仍全部 `not-started`。
- **未执行**：Apple Simulator 交互验收、真机、真实后端写入联调、相册/通知/后台任务、动态字体与 iPad 验收。CI 通过只证明编译与单元测试，不证明业务完成。
- Bundle ID 暂用 `cn.edu.bjtu.foodtime`，开发团队、签名与分发方式仍待确认；最低系统已确认为 iOS 17。

## 接手入口

1. [开发交接和目标提示词](docs/HANDOFF-PROMPT.md)：可以直接交给下一位开发者或编码代理。
2. [Android 功能对照](docs/ANDROID-PARITY.md)：已发布能力和 dev 新增项，以及源码入口。
3. [对齐记录](docs/parity/coverage.json)：每个路由和跨页面能力的状态、实现位置及验证证据。
4. [持续同步流程](docs/SYNC-PROCESS.md)：如何发现 Android 更新、维护差异并判定完成。
5. [架构边界](docs/ARCHITECTURE.md)、[iOS 选型与验证](docs/IOS-DECISIONS.md)、[后端接入](docs/BACKEND-INTEGRATION.md)、[本地开发](docs/DEVELOPMENT.md)。

## 目录

```text
Sources/
  App/          依赖组装、会话生命周期、导航
  Domain/       模型、错误、格式化、业务接口
  Data/         HTTP、Cookie/CSRF、DTO 与远端服务
  Platform/     Keychain、Cookie 归档、系统能力适配
  Features/     登录、食堂、个人页等页面及其状态
  SharedUI/     手账设计令牌与共用控件
Resources/      Asset Catalog、图标（字体/地图后续接入）
Tests/Unit/     单元测试与网络桩
scripts/       仓库与层边界检查
project.yml    XcodeGen 工程定义（源文件）
```

当前是单模块工程，层边界由 `scripts/check_ios_architecture.py` 做静态检查；后续需要时再拆 SPM 包或独立 framework，拆分层级以 `docs/ARCHITECTURE.md` 为准。

## 本地构建

需要 macOS、Xcode 26.6 或兼容版本、XcodeGen 2.48.0：

```sh
brew install xcodegen
xcodegen generate
python3 scripts/check_ios_architecture.py
xcodebuild -project FoodtimeNeo.xcodeproj -scheme FoodtimeNeo \
  -destination 'platform=iOS Simulator,name=iPhone 17' build test
```

默认请求 `https://bjtufoodtime.top/api/v1/`。Debug 可用 `FOODTIME_API_BASE_URL` 覆盖为本地服务；Release 仍必须使用 HTTPS。签名/Team 未配置，模拟器构建不需要签名，真机与 TestFlight 前再补。

## 检查

```sh
python3 scripts/check_repository.py
python3 scripts/check_repository.py --upstream
python3 scripts/check_ios_architecture.py
```

- `repository-checks.yml`（Ubuntu）：校验仓库、文档、链接、coverage 记录、PR 规范和 Android 上游 SHA。
- `ios-ci.yml`（macOS 26）：生成工程、检查层边界、编译并通过单元测试。
- 两者都不能替代 Apple Simulator、真机、真实后端和业务验收；无环境的结果写未执行，不写通过。

## 协作

`feature/<kebab-case>` → `dev`：准确提交检查通过且 PR 可合并后 squash。`dev` → `main`：检查通过后 merge commit，保留 `dev`。初始化同步不代表应用发布；版本、签名、分发另行确认。提交采用 Conventional Commits、中文摘要、标题不超过72字符。详细规则见 [AGENTS.md](AGENTS.md)。

共用 [Backend](https://github.com/FoodtimeNeo/FoodtimeNeo-Backend)，以 [Android](https://github.com/FoodtimeNeo/FoodtimeNeo-Android) 为功能主参照，[Web](https://github.com/FoodtimeNeo/FoodtimeNeo-Web) 作补充。当前线上部署版本需联调前核实，不因仓库已发版就假定服务器已升级。
