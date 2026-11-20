# 设置与更新（iOS 可确认部分）

实现：`Sources/Features/Profile/SettingsView.swift`、`SettingsViewModel.swift`、`Sources/Platform/URLCacheMediaCache.swift`、`AppVersionInfo.swift`。

对照 Android：`ProfileScreen` 的图片缓存、版本阶段展示与检查更新；iOS 分发方式尚未确认（`docs/IOS-DECISIONS.md`）。

## 已实现

- **版本展示**：读取 `CFBundleShortVersionString` / `CFBundleVersion`；可选 `FoodtimeReleaseStage` 保留 α/β 后缀，例如 `v2.0.0β（24）`。没有授权发版时纯展示，不触发安装或下载。
- **图片缓存**：通过 `MediaCacheManaging` 适配 `URLCache.shared`，显示磁盘 + 内存占用；“清理图片缓存”二次确认后清空并重新统计。只影响图片/网络缓存，不删除草稿、投稿、账号或会话。
- **更新方式说明**：明确 iOS 不能从网页下载并长期安装 IPA；TestFlight/App Store/MDM 未确认前不提供站内检查更新或下载入口，避免把 Android APK 流程照搬成假入口。

## 边界

- 不修改 `URLCache.shared` 的容量与 HTTP 缓存策略；长期 HTTP 缓存仍按 PERFORMANCE-ROADMAP 的待决策项处理。
- 未接入 App Store/TestFlight 版本查询，因为分发渠道、Team、Bundle ID 冲突处理尚未确认。
- 清理缓存不会取消正在进行的请求；并发加载可能重新写入缓存，属正常行为。
- 未记录清理审计；本地操作不需要服务端配合。

## 验证边界

- 单元测试：缓存占用展示、清理后归零、清理未完全成功提示、版本阶段后缀保留。
- 本地架构检查与仓库检查通过；编译/单测由 macOS CI 执行。
- 未执行：Apple Simulator 清理后图片重新加载、真实 URLCache 容量统计、TestFlight/App Store 更新链路。

## 平台差异

- Android 的检查更新/APK 补丁不适用于 iOS；等分发方式确认后，以对应渠道的版本检查替代，并保留“正式/测试”阶段展示。
- Android 切后台不清缓存的本机行为在 iOS 由系统 URLCache 与内存压力决定；本波次只提供手动清理与占用展示。
