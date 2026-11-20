# 无障碍、动态字体与 iPad（W7）

## 本分支已完成

- 全局按钮：`InkButtonStyle`/`LinkButtonStyle` 改用相对文本样式；链接按钮最小 44pt 命中区与 `contentShape`。
- 核心动态字体：聊天正文/时间、信箱标题、会话名、管理入口/指标/用户名、社区卡片标题改用 `.body`/`.headline`/`.title3` 等相对字号。
- 状态语义：
  - 未读消息/会话通过 `accessibilityValue` 播报“未读/已读/N 条未读”。
  - 点赞、收藏按钮补 `accessibilityLabel` 与计数/选中值；社区卡片合并元素增加“点赞/取消点赞”自定义动作。
  - 评分星补“评分 N 星”；评分选择器补 `.isSelected` 与当前值。
- 图标按钮：移除图片、清除搜索、置顶上移/下移补明确标签；加载中的提交按钮播报“正在登录/注册/发送”等。
- 图片入口：菜品 hero 与菜品/食记缩略图补按钮 trait、序号标签与 VoiceOver 动作。
- 布局：
  - 社区发现流在辅助功能字号下退化为单列，iPad 常规宽度用三列。
  - 社交用户行在辅助功能字号下改为纵向；固定宽度关注/解除拉黑按钮改为自适应。
  - 注册验证码按钮不再固定 128pt；聊天/回复发送按钮不再固定 82pt。
  - 管理看板标题与周期选择改为纵向，避免大字号碰撞。
- 表单：登录/注册关键字段补 `accessibilityLabel`（邮箱、密码、验证码、确认密码）。
- 状态页标题补 header trait；启动页大标题改用 `.largeTitle`。

## 仍待办（未在本分支完成）

- VoiceOver 实机全流程走查与朗读顺序；未执行 Apple Simulator/真机。
- 价格历史图表已补 `accessibilityValue` 摘要与 `@ScaledMetric` 坐标轴字号；更细的单点朗读仍未做。
- 搜索食堂与收藏分组 chip 已补选中语义；地图筛选等其余自定义 chip 仍可补齐。
- `SocialView` 辅助功能字号下三个操作仍在同一 HStack，极端字号可能截断。
- 部分管理端详情标题/看板数值仍用固定字号（装饰性标题优先）。
- iPad 导航结构（`NavigationSplitView`/侧栏）仍未决，属 D18；本轮只做列数与宽度自适应，不改导航。
- 动态字体超大字号下的截图基线未建立。

## 验证边界

- 本地 `check_ios_architecture.py` / `check_repository.py` 通过。
- macOS 编译与 XCTest 依赖 CI；VoiceOver、动态字体分级、iPad 分屏未执行。
- 对齐条目保持 `in-progress`，不标 verified。
