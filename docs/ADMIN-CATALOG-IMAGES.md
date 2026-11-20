# 管理端：目录图片（W6）

实现：`Sources/Features/Admin/AdminCatalogImagesView.swift`、`AdminCatalogImagesViewModel.swift`。

## 范围

- `GET /admin/catalog/{type}/{id}/images?page&size`：食堂封面、档口图集或菜品图片；分页。
- `POST /admin/catalog/{type}/{id}/images`：`{imageUrl}`；图片需先走既有 `POST /uploads/images` 上传，再用返回引用添加。
- `DELETE /admin/catalog/{type}/{id}/images/{imageId}`：只移除当前目录引用，不删除其他位置使用的文件。
- 食堂类型由服务端替换封面；档口/菜品追加图集。
- UI：图片预览、分页、从系统相册选择并上传、移除二次确认。

## 权限与入口

- 仅 `superadmin` 显示“图片”入口；普通 admin 不显示，服务端仍会逐次校验。
- 入口位于目录管理每个条目的“编辑/图片/删除”操作行。
- 上传使用 `SubmissionService.uploadImage`（与投稿共用压缩与上传路径），不新建第二套网络逻辑。

## 边界

- 图片加载通过 `MediaURL.resolve` 以目录媒体源解析相对地址；不进入共享 URLCache 的证据图策略属 W7。
- 移除不做乐观更新；成功后重载当前页，末页删空时回退一页。
- 失败保留当前列表并展示服务端消息。

## 验证边界

- 单元测试覆盖列表路径、添加 POST body（imageUrl）、移除 DELETE 路径。
- 未执行：Apple Simulator、真实超管/普通 admin 权限矩阵、相册选择与上传链路、食堂封面替换、移除后媒体文件保留。
- 对齐条目保持 `in-progress`，不标 verified。
