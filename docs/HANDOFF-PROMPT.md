# FoodtimeNeo iOS 开发交接与目标提示词

你是 FoodtimeNeo-IOS 的接手开发负责人。请直接在 https://github.com/FoodtimeNeo/FoodtimeNeo-IOS 完成后续开发。

## 目标

**完整复刻 Android 端所有当前内容，后续 Android 更新也持续同步到 iOS。** 这不是只做首页、普通用户MVP、静态演示或一次性移植。范围包括访客/普通用户/管理员/超级管理员、所有页面与菜单弹窗、权限和状态、媒体与缓存、通知、账号生命周期及管理能力。保留手账风格与主要操作体验；iOS系统适配需要等效实现，不能擅自删减。

## 当前交接状态

仓库已完成工程底座：XcodeGen 工程、SwiftUI 外壳、网络/会话/CSRF、Keychain Cookie 归档、登录/验证码、食堂→档口→菜品只读纵切片、macOS 编译与单测 CI。W1 注册（策略/邀请码/邮箱验证码）、找回/修改密码、资料昵称编辑、学校邮箱绑定/解绑与账号注销、关注/粉丝/搜索/黑名单、用户反馈已接入；W2 搜菜筛选/排序、菜品详情/图册、价格历史、校园地图已接入。完整对齐尚未开始，`coverage.json` 的 102 项目标仍全部 `not-started`。原生 SwiftUI 与最低 iOS 17 已确认；Bundle ID 暂用 `cn.edu.bjtu.foodtime`，开发团队、签名、分发、后台通知/APNs 仍待确认。请先核对 `docs/BACKEND-INTEGRATION.md`、`docs/IOS-DECISIONS.md` 和最新源码，继续推进未确认项之外的实现；不要默认需要用户先购买Mac，也不要把Windows WebKit当Apple模拟器验证。

已发布参照 Android main：`32215aab169bfe9ca40d7189a09c59c325744f21`（v2.0.0β）；Android dev：`ff1ed41c21b6361a3ec7ae0280878a2806c14a7a`，另有一键点评新流程，需要纳入跟进。Backend main：`e8f34998930781230711d8e8dd109c32d34b1ba8`；Web main：`b6e2d8f7c49016c0d53aea94b0472f3f12595a7c`。开始前重新核对最新提交，不能永远停在这份快照。线上部署版本需单独核实。

## 先读再动手

阅读本仓 README、AGENTS.md、docs/ANDROID-PARITY.md、docs/parity/coverage.json、docs/ARCHITECTURE.md、docs/SYNC-PROCESS.md、docs/IOS-DECISIONS.md、docs/BACKEND-INTEGRATION.md、docs/DEVELOPMENT.md。

随后读取Android的MainActivity注册表、全部Screen/菜单/弹窗、domain/repository、RemoteRepository与JSON adapters、图片/草稿/通知/更新实现及测试；交叉核对Backend真实Controller/DTO与能力策略。Android文档有旧版本文字，不能只按文档标题或旧计划开发。当前路由并集72项和跨页面能力30项只是防遗漏起点，不代表已经穷尽业务或完成验收。

## 实施要求

1. 先审计完整范围，补齐遗漏，按领域拆成可验证的小功能分支；可以分阶段交付，不能把阶段成果宣告为全量完成。随后实际建立工程并实现全部目标，不要停留在规划或骨架。
2. 复用同一套后端/API、Cookie/CSRF、能力授权、分页、时间/金额、revision与幂等契约。不要复制后端、绕过审核，或为iOS方便擅改Android/Backend/Web及生产配置。
3. 坚持低耦合：页面通过用例与业务接口调用，网络/存储/相册/通知/分享/导航做可替换适配。不要堆万能Repository或让业务直接依赖平台和SDK。
4. 防止跨账号缓存、草稿、上传与迟到响应串用。认真复刻失败保留、重试去重、状态冲突、权限撤回、文件持久化及后台调度边界。
5. 重点覆盖注册邀请码与验证码、受限申诉、注销/解绑、三层目录与搜索、所有点评与投稿、社区/私信、帖子修改/置顶、收藏分组/历史、反馈CSV、举报/申诉/纠错、公告排期、价格历史、地图及全部管理能力。dev新增的一键点评也不能遗漏。
6. 对Android APK更新/补丁、后台提醒等iOS不能原样照搬的事项，列明原因、等效方案和影响并向用户确认；记录批准，不能默默删除，也不能承诺普通iPhone任意网页下载IPA即可长期安装。
7. 每次开始及合并前对比最新Android main/dev和Backend变化，更新对齐表、代码及回归。只改SHA让检查通过不算同步，Android新增内容必须进入待办并实际完成。

## 验证与交付

当前CI包含仓库/对齐记录检查与macOS编译/单测，但仍不证明业务验收。继续补齐真实测试后端、Apple模拟器、真机及媒体、权限、后台、键盘/返回、动态字体和不同角色专项；实机不可用时准确记录未执行，禁止用Mock、截图或Windows浏览器代替。

按README的feature→dev squash、dev→main merge commit流程工作，准确HEAD检查通过再合并。每个PR记录对应Android提交、覆盖ID、iOS实现/证据、平台差异和遗留项。不提交凭据或真实用户数据，不自行发布、部署或购买服务。

只有全部已确认目标有实现和验证证据、最新Android变化已审查、平台等效获批准、关键业务和角色回归通过，才能宣布完整对齐。请先报告审计发现、需要确认的关键选型及实施分组，然后继续执行已明确的工作。
