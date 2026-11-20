# iOS 待确认事项与验证边界

| 事项 | 当前状态 | 接手动作 |
|---|---|---|
| UI/工程技术路线 | 未确认 | 比较复用与原生方案，按全功能目标说明差异后确认；不能默认套壳即交付 |
| 最低 iOS/iPadOS、平板范围 | 未确认 | 结合目标设备与系统能力确认，不声称支持全部历史系统 |
| Bundle ID、开发团队与签名 | 未确认 | 不填他人的 Team ID，不提交证书或描述文件 |
| macOS/Xcode | 当前未提供本地 Mac | 取得合适的本地/远程/CI macOS 环境，执行真实工程编译和 Apple Simulator；Windows WebKit 不作替代 |
| 安装与长期分发 | 未确认 | 区分开发设备、Ad Hoc、TestFlight、App Store/非公开分发；不能承诺校内学生直接下载任意 IPA 即长期安装 |
| 后台通知 | 需平台适配 | 对齐七类消息、开关、隐私、游标、去重和跳转；系统调度不能保证固定时间到达，新增推送基础设施另行确认 |
| 版本与更新 | 需平台适配 | 保留α/β测试阶段的用户展示，但不能照搬APK/bsdiff安装路径；iOS构建版本按Apple规则单独配置 |

遇到平台限制，先继续不依赖该决策的调查与功能工作，及时向用户确认影响方案；不能把待确认当成自动删项许可。批准后的等效行为写入对齐记录，不把未经批准的差异标为完成。

`CFBundleShortVersionString` 要求三段数字和点；α/β作为项目展示与渠道信息单独处理，不能直接填入该键。iOS后台任务由系统决定实际执行时机，不能把Android周期任务照搬成固定准时承诺。

依据：[Apple版本字段](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring)、[后台任务](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app)、[Xcode与模拟器](https://developer.apple.com/documentation/safari-developer-tools/installing-xcode-and-simulators)、[TestFlight](https://developer.apple.com/testflight/)、[Ad Hoc设备限制](https://developer.apple.com/help/account/devices/devices-overview/)、[非公开分发](https://developer.apple.com/support/unlisted-app-distribution)。实施前按最新官方文档复核，不把历史估算当平台保证。

交付证据分别记录编译、单测、受控接口、真实测试后端、Apple模拟器和实机结果。没有执行的项目保持未执行；不以仓库检查、截图或Mock证明全部业务完成。
