# 一键点评（W3）

实现：`Sources/Features/Reviews/QuickReviewView.swift`，复用 `DishSearchViewModel` 与 `ReviewComposerView`。

## 行为

- 食堂首页入口“一键点评”；搜索/浏览菜品后选择一道，打开共享点评表单。
- 表单与普通菜品点评相同：1–5 星、正文 1–500、提交 202 pending、审核通过后公开并计入评分。
- 提交成功显示成功卡片；审核状态可在“我的点评”查看。
- 搜索复用 `/dishes/search`（空关键词浏览全部），不新增仅 iOS 接口。
- 访客/无权写入由服务端拒绝；客户端显示服务端错误。

## 验证边界

- 未新增网络协议；复用已测的搜菜与点评服务。
- 未执行：真实后端一键点评审核流转、Apple Simulator 搜索/键盘/表单、访客权限、图片点评（图片点评依赖媒体波次）。
- `capability:quick-review` 未标 verified。
