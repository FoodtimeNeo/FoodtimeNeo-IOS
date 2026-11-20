# Platform

Keychain、相册/文件、系统分享、剪贴板、通知及生命周期适配；不决定审核、处罚、账号资格等业务结论。

当前：`KeychainStore`（`AfterFirstUnlockThisDeviceOnly`）、`KeychainCookieArchive`（按 origin 归档）、`InstallationMarker`（首启清 Keychain，避免卸载重装恢复旧会话）。相册/通知/BGTask 待接入。
