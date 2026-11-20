# 管理端：反馈与 CSV（W6）

实现：`Sources/Features/Admin/AdminFeedbackView.swift`、`AdminFeedbackViewModel.swift`、`Sources/Domain/Models/AdminFeedback.swift`。

## 范围

- `GET /admin/feedback?archived&page&size`：未归档/已归档列表。
- `GET /admin/feedback/{id}`、`GET /{id}/replies`：详情与回复记录。
- `PUT /admin/feedback/{id}`：`{reply?, status?, clientRequestId}`；status `pending|processing|completed`，处理建议即公开回复。
- `POST /admin/feedback/export`：返回 `{filename, csv, count}`；服务端将 pending 转为 processing 后再导出。
- `POST /admin/feedback/import`：`{csv}`，最大 2,000,000 字符；返回 `{updated, skipped, issues[]}`，逐行事务。
- UI：归档切换、导出/导入按钮、处理详情、状态与建议编辑、导入问题列表。

## CSV 细节

- 服务端已生成 UTF-8 BOM、CRLF、五列（反馈编号/类型/内容/状态/处理建议）；iOS 原样写入文件，不重新拼接或转码。
- 导出使用 `.fileExporter` + `FileDocument`；导入使用 `.fileImporter`，读取后先做 UTF-8 解码，再原样提交。
- **导出副作用**：导出动作先把 pending 转 processing；用户取消保存不会回滚。界面在按钮下方明确提示。
- 导入逐行事务，`issues` 显示行号与消息；`updated/skipped` 原样展示。

## 边界

- `/admin/feedback` 在 URL 层仅 superadmin；普通 admin 会收到 403。
- 不解析或重写 CSV 内容，避免破坏服务端的引号/公式前缀转义。
- 文件选择失败、非 UTF-8、网络错误分别提示；不把本地文件留在沙盒外。

## 验证边界

- 单元测试覆盖 archived 查询、详情/回复、更新 PUT body（reply/status/clientRequestId）、导出解码（BOM 保留）与导入 POST body。
- 未执行：Apple Simulator、真实文件选择器、超管权限、超长 CSV、逐行事务失败、导出取消后的状态回滚验证。
- 对齐条目保持 `in-progress`，不标 verified。
