# iOS 决策与验证边界

更新：2026-11-20。用户已确认原生 SwiftUI 与最低 iOS 17；下列其余项仍待确认或按占位值实现，不能把占位当成最终配置。

| 事项 | 当前状态 | 处理 |
|---|---|---|
| UI/工程技术路线 | **已确认原生 SwiftUI** | 不使用 Capacitor 容器或 Flutter；完整复刻 Android，不以网页套壳交付 |
| 最低 iOS/iPadOS | **已确认 iOS 17** | 不使用 iOS 18 独占 API；iPad/横屏布局仍按 W7 专项验收 |
| 目标设备 | 暂按 iPhone + iPad 通用 | 方向为竖屏 + 左右横屏；如需收窄，发布前调整 |
| Bundle ID | 暂用 `cn.edu.bjtu.foodtime` | 与 Android 包名一致；App Store 注册冲突时再改，改后需重新签名 |
| 开发团队/签名 | 未确认 | 工程不填他人 Team ID；不提交证书/描述文件；模拟器 CI 不签名 |
| macOS/Xcode | CI 已用 `macos-26` + Xcode 26.6；本地仍无 Mac | 编译/单测由 CI 执行；Apple Simulator、真机、相册、通知、键盘未执行 |
| 分发方式 | 未确认 | 区分 TestFlight、App Store、非公开分发/MDM；iOS 不能从网页下载 IPA 长期安装 |
| 后台通知 | 需平台适配 | 先做站内信 + 前台/后台刷新本地通知；APNs 需要后端设备 token、推送证书与事件接口，另行确认 |
| 版本与更新 | 需平台适配 | `CFBundleShortVersionString` 只填 x.y.z；α/β 放展示/TestFlight 渠道；iOS 不照搬 APK/bsdiff 更新 |
| 后端客户端标识 | 待后端确认 | iOS 发送 `X-Foodtime-Client: ios`；需把 `ios` 加入 `CLIENT_HEADER_ALLOWED` 并确认线上 `CLIENT_HEADER_MODE` |
| 工程生成 | 技术选择 | XcodeGen 2.48.0，`project.yml` 为源，`.xcodeproj` 不提交；CI 每次生成 |
| 测试环境 | 待提供 | 生产只做只读冒烟；写入联调用专用本地/测试 Backend，不能写线上数据 |

## 平台差异与缺口

- Android `JobScheduler` 15 分钟周期在 iOS 不存在；`BGAppRefreshTask` 只能尽力而为，不能承诺准时。强制关闭/低电量会停；可靠到达需 APNs。
- Android 的非头像图片 EXIF 方向、搜索返回状态、食堂/档口点评编辑正文回填等已知缺陷，iOS 不复制；修正需作为平台差异记录并验收。
- 访客写入口、帖子分组改名/删除/排序、私信隐藏、转发创建、管理端 iPad 布局等 Android 未完成或有歧义的能力，先确认再实现，不默默补成“已完成”。
- 字体/地图/插画/平面 Emoji 的许可与包体积需在接入前确认；地图底图来源为学校招生办手绘地图，仓库无许可声明。

## 验证边界

- CI 只证明：工程能生成、层边界检查通过、Xcode 能编译、单元测试通过。
- 未执行：Apple Simulator 交互、真机、真实测试后端、相册/HEIC、系统通知/BGTask、键盘/返回手势、动态字体、iPad 分屏、无障碍读屏。
- 交付证据分别记录编译、单测、受控接口、真实测试后端、Apple Simulator 和实机结果；没有执行的项目保持未执行。
- 依据：Apple 版本字段、后台任务、Xcode/模拟器、TestFlight、Ad Hoc 设备限制、非公开分发等官方文档；实施前按最新文档复核。
