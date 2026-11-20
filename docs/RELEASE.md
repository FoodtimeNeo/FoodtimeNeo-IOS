# 发布与 TestFlight 准备（W7）

## 已完成（仓库内可验证）

- `Resources/PrivacyInfo.xcprivacy`：声明不跟踪、无跟踪域；收集邮箱/昵称/用户 ID/照片/用户内容/浏览历史，均关联到账号且仅用于 App 功能；`UserDefaults` 以 `CA92.1` 理由访问。
- `project.yml` 使用 `GENERATE_INFOPLIST_FILE`，最低 iOS 17，iPhone/iPad 双设备族，版本 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 可在 XcodeGen 生成时覆盖。
- 设置页已展示版本/构建号与测试阶段后缀（`feature/settings-update`）。

## TestFlight 前置（需用户提供，本仓库不保存）

- Apple Developer Program 团队与 App Store Connect 访问权。
- 正式 Bundle ID（当前占位 `cn.edu.bjtu.foodtime`）与签名证书/描述文件，或启用 Xcode 自动签名并登录团队。
- App Store Connect App 记录、SKU、主要语言、年龄分级、出口合规（加密使用仅 HTTPS）。
- 截图与商店文案（iPhone 6.9"/6.5"、iPad 13" 如启用 iPad 布局）。
- 隐私政策与用户协议 URL；支持邮箱。
- 推送能力（APNs key）与通知分发方式仍未决策，不包含在本阶段。

## 构建步骤（在有 macOS/Xcode 的机器上）

1. `brew install xcodegen`（或复用 CI 版本）。
2. `xcodegen generate`
3. `xcodebuild -project FoodtimeNeo.xcodeproj -scheme FoodtimeNeo -configuration Release -destination 'generic/platform=iOS' archive`
4. Xcode Organizer 校验隐私清单、签名与 App Store 连接后分发到 TestFlight。
5. 真机/模拟器验收：登录、注册、食堂、点评、社区、消息、管理端六组核心路径；iOS 17 与最新 iOS 各一台。

## 发布边界

- 未创建证书、描述文件、App Store Connect 记录或 TestFlight 构建；这些动作需要用户明确授权与账号。
- 未配置推送服务、后台任务或第三方分析 SDK。
- Bundle ID、签名方式、iPad 导航布局（D18）仍待用户确认。
- CI 只做模拟器 Debug 构建与单测；Release archive、隐私清单校验与 TestFlight 上传未执行。

## 版本策略建议

- `MARKETING_VERSION` 以 `0.x` 迭代，TestFlight 阶段后缀由构建配置注入；`CURRENT_PROJECT_VERSION` 每次上传递增。
- `dev` 合并到 `main` 用 merge commit；发布标签由用户创建，不由代理推送。
