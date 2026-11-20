# FoodtimeNeo iOS · 北交干饭吧

目标是完整复刻 Android 客户端的功能、业务规则和手账风格，并持续跟进 Android 后续更新。普通用户、访客、管理员和超级管理员的能力都属于范围，不能只实现首页或普通用户流程。

当前完成的是**仓库级初始化**：目录边界、功能对照记录、协作和同步流程、基础检查及交接提示词。尚无 Xcode 工程、可运行 iOS App、业务实现或安装包。界面框架、最低系统版本、Bundle ID、签名团队与分发方式留待接手负责人和用户确认。

## 接手入口

1. [开发交接和目标提示词](docs/HANDOFF-PROMPT.md)：可以直接交给下一位开发者或编码代理。
2. [Android 功能对照](docs/ANDROID-PARITY.md)：已发布能力和 dev 新增项，以及源码入口。
3. [对齐记录](docs/parity/coverage.json)：每个路由和跨页面能力的状态、实现位置及验证证据。
4. [持续同步流程](docs/SYNC-PROCESS.md)：如何发现 Android 更新、维护差异并判定完成。
5. [架构边界](docs/ARCHITECTURE.md)及[iOS 选型与验证](docs/IOS-DECISIONS.md)。

## 目录

```text
Sources/
  App/          组装、会话生命周期与导航
  Domain/       模型、用例与业务接口
  Data/         HTTP、DTO 与存储适配
  Platform/     相册、文件、通知与系统能力
  Features/     各业务页面及其状态
  SharedUI/     手账设计资源与共用控件
Tests/          后续单元、接口与界面验证
scripts/        仓库与对齐记录检查
```

这些目录只定义职责，不代表已经建立 Swift 模块或选定框架。

## 检查

```sh
python3 scripts/check_repository.py
python3 scripts/check_repository.py --upstream
```

第二条命令只读检查 Android main/dev 是否变化，不会修改参照提交、同步业务代码或创建提醒。CI 在 PR、main/dev 推送及手动运行时执行；Android main 变化会要求重新审查，dev 变化会提示待跟进。

**当前 CI 只检查仓库和对齐记录，不执行 iOS 编译、单元或模拟器测试。** 接手人建立真实工程后必须补充 macOS/Xcode 构建及测试门禁。

## 协作

`feature/<kebab-case>` → `dev`：准确提交检查通过且 PR 可合并后 squash。`dev` → `main`：检查通过后 merge commit，保留 `dev`。初始化同步不代表应用发布；版本、签名、分发另行确认。提交采用 Conventional Commits、中文摘要、标题不超过72字符。详细规则见 [AGENTS.md](AGENTS.md)。

共用 [Backend](https://github.com/FoodtimeNeo/FoodtimeNeo-Backend)，以 [Android](https://github.com/FoodtimeNeo/FoodtimeNeo-Android) 为功能主参照，[Web](https://github.com/FoodtimeNeo/FoodtimeNeo-Web)作补充。当前线上部署版本需联调前核实，不因仓库已发版就假定服务器已升级。
