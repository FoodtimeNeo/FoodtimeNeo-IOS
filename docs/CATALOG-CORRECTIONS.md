# 目录纠错（用户侧）

实现：`Sources/Features/Corrections/`、`Sources/Data/Corrections/`、`Sources/Domain/Models/CatalogCorrection.swift`。

对照 Android：`CorrectionScreen`（用户提交与我的纠错）；后端：`CatalogCorrectionController`、`CatalogCorrectionDtos`、`docs/api/user/catalog-corrections.md`。

## 入口

- 菜品详情 →「纠错」：仅菜品与 Android 当前入口一致；食堂/档口能力后端支持，但 Android 未开放入口，本波次不擅自新增。
- 个人页 →「目录纠错」：本人提案列表。

## 提交

`POST /users/me/catalog-corrections`

```json
{
  "targetType": "dish",
  "targetId": "dish-1",
  "baseRevision": 3,
  "changedFields": ["name", "price", "priceUnit"],
  "name": "红烧肉盖饭",
  "description": null,
  "price": 15.5,
  "priceUnit": "serving",
  "reason": "菜单已更新",
  "evidenceUrls": ["/api/v1/media/..."],
  "idempotencyKey": "uuid"
}
```

- `baseRevision` 取详情响应的 `revision`；为 0 或缺失时禁止提交，提示返回详情刷新。
- 仅提交勾选的字段；`description` 留空表示清空，`price` 留空表示价格未知（`0` 是有效价格）。
- 理由 1–500 字；每单最多 4 个字段、3 张证据；每人 UTC+8 自然日最多 5 单，由服务端最终校验。
- 证据先经 `POST /uploads/images` 上传为本人私有暂存引用；不进入公开图集，只有本人与 `correction.review` 持有者可读。
- 幂等：同一内容重试复用 `idempotencyKey`；内容变化后换新键，避免服务端 `IDEMPOTENCY_KEY_REUSED`。
- 错误：目录版本冲突、目标删除/停用、额度用尽、证据不属于本人等均显示服务端消息。

## 我的纠错

`GET /users/me/catalog-corrections?page&size`

- 最新在前；列表展示目标摘要、状态（待核对/已通过/未通过）、时间、逐字段“原值 → 提案值”、理由和审核说明。
- `GET /users/me/catalog-corrections/{id}` 已在 Service 提供，本波次列表未做单独详情页。
- 状态只由服务端整单裁决决定；客户端不把待核对当已应用。

## 数据与边界

- `DishDetail.priceUnit` 新增可选字段以支持计价单位纠错；旧响应缺失时为 nil，显示“未注明”。该字段同时来自详情接口。
- 证据上传失败保留已选图片与已成功引用；本地不把“上传成功”当作“提案成功”。
- 提交后不在本地伪造提案；以返回的 `CatalogCorrection` 为准。
- 未实现：管理员审核页、食堂/档口纠错入口、证据预览大图、真实后端联调与实机相册验收。

## 验证边界

- 单元测试：远端 Service 的提交体/路径/CSRF/分页/详情路径与字段映射；表单的字段勾选、空值语义、负价格、理由、证据上传失败、幂等键复用与内容变化换键、revision 缺失；我的纠错的首页/加载更多/失败保留。
- 本地架构检查与仓库检查通过；编译/单测由 macOS CI 执行。
- 未执行：真实后端写入与额度、证据读取权限、Apple Simulator 相册与表单交互、并发 revision 冲突实测。
