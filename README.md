# FoodtimeNeo iOS · 北交干饭吧

FoodtimeNeo 的 iOS 客户端开发仓库。

目前仅完成仓库初始化，尚未创建 Xcode 工程或发布 iOS 安装包。界面框架、最低系统版本、Bundle ID 和签名团队将在开发准备时确定。

## 相关项目

- [Backend](https://github.com/FoodtimeNeo/FoodtimeNeo-Backend)：共用的业务接口与权限校验。
- [Android](https://github.com/FoodtimeNeo/FoodtimeNeo-Android)：现有原生客户端，供功能与交互对照。
- [Web](https://github.com/FoodtimeNeo/FoodtimeNeo-Web)：现有网页客户端，供视觉与业务流程对照。

## 开发约定

- `main` 为发布分支，`dev` 为开发集成分支；单项功能使用 `feature/<kebab-case>` 分支。
- 提交采用 Conventional Commits、中文摘要，标题不超过 72 字符。
- 功能通过 PR 集成到 `dev`，检查通过后 squash 合并；发布从 `dev` 向 `main` 提 PR，以 merge commit 合并并保留 `dev`。
- 共用后端接口，保持界面、业务、网络和平台能力之间低耦合，服务端负责最终权限校验。
- 不提交密码、密钥、签名证书或设备描述文件。

正式的 iOS 构建与官方模拟器测试需要可用的 macOS/Xcode 环境；Windows 上的网页兼容检查不能替代 iOS 应用验证。
