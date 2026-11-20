# Android 全功能对照基线

已发布参照：Android `32215aab169bfe9ca40d7189a09c59c325744f21`（v2.0.0β）；集成线参照：`ff1ed41c21b6361a3ec7ae0280878a2806c14a7a`。
Backend `e8f34998930781230711d8e8dd109c32d34b1ba8`；Web `b6e2d8f7c49016c0d53aea94b0472f3f12595a7c`。这些是源码参照，线上部署需另核。

main登记71个页面路由，dev登记72个；并集72个。另建30项跨页面能力记录，当前共102项，全部尚未开始。

## 已发现的集成线变化

Android dev新增一键点评（quick-review）：食堂首页入口、逐级选菜或直接搜索，并复用点评表单；尚未进入本基线main。源码见 [ReviewScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/ff1ed41c21b6361a3ec7ae0280878a2806c14a7a/app/src/main/java/cn/edu/bjtu/foodtime/presentation/ReviewScreen.java)。该项已进入目标清单，后续需核验实际状态与行为。原有点评入口也改为共享表单，不应只新增quick-review路由而忽略旧入口的改动。

## 能力索引

| ID | 必须对照的内容 | Android入口 |
|---|---|---|
| `capability:auth` | 登录、注册模式/邀请码、邮箱验证码、密码找回与改密 | [AuthScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/AuthScreen.java) |
| `capability:session` | Cookie/CSRF、身份恢复、受限申诉会话、切号隔离与迟到响应 | [MainActivity.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/MainActivity.java) |
| `capability:account` | 学校邮箱绑定/解绑、注销、验证码及冷却提示 | [SchoolEmailScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/SchoolEmailScreen.java) |
| `capability:catalog` | 食堂/档口/菜品目录、启停可见性与每日推荐 | [DiningScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/DiningScreen.java) |
| `capability:search` | 搜菜筛选排序、未知数据、数字省略分页、返回页码和位置 | [DishSearchScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/DishSearchScreen.java) |
| `capability:dish-media` | 详情/图册、完整比例、多图手势、图片读写失败与重试 | [DishScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/DishScreen.java) |
| `capability:reviews` | 菜品及食堂/档口点评、评分、点赞、楼中楼回复与本人记录 | [ReviewScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/ReviewScreen.java) |
| `capability:submissions` | 图片/菜品/档口投稿、本人提交记录、审核状态与失败重试 | [UploadScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/UploadScreen.java) |
| `capability:community-feed` | 发现/关注/搜索/作者/本人食记、游标和列表缓存位置 | [CommunityScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/CommunityScreen.java) |
| `capability:community-detail` | 详情、评论回复、点赞、转发分享、收藏和浏览量幂等 | [CommunityScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/CommunityScreen.java) |
| `capability:drafts` | 每账号本机单份带图草稿、自动保存、恢复与清理 | [CommunityScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/CommunityScreen.java) |
| `capability:post-edit-pins` | 原创/转发修改重审保留互动、置顶名额/隐藏/排序/恢复 | [PostEditScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/PostEditScreen.java) |
| `capability:media-platform` | 相册优先选择、裁剪/方向/格式、资源持久化、平面Emoji、缓存及连续缩放 | [AvatarCropScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/AvatarCropScreen.java) |
| `capability:collections` | 菜品/帖子收藏分离、默认分组、多分组、新建/更名/排序/删除和取消收藏 | [FavoriteDishesScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/FavoriteDishesScreen.java) |
| `capability:history` | 帖子/菜品各50条、跨设备历史、开关、失效项及清理 | [HistoryScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/HistoryScreen.java) |
| `capability:profile-social` | 资料/头像、关注粉丝、用户搜索、黑名单、账号与隐私入口 | [ProfileScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/ProfileScreen.java) |
| `capability:chat` | 私聊会话、未读、消息复制/举报、顶部拉黑及删除会话 | [ChatScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/ChatScreen.java) |
| `capability:notifications` | 信箱、七类通知、分类开关/迁移/游标/去重/隐私与目标跳转 | [InboxScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/InboxScreen.java) |
| `capability:feedback` | 反馈分类/限额/记录/回复历史、超管导出CSV及批量回复状态 | [FeedbackScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/FeedbackScreen.java) |
| `capability:corrections` | 目录纠错、证据/限额、超管审核应用及revision冲突 | [CorrectionScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/CorrectionScreen.java) |
| `capability:reports-appeals` | 举报回执、追问、双方申诉、受限登录、公开/私密材料隔离 | [ReportReceiptScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/ReportReceiptScreen.java) |
| `capability:admin-moderation` | 审核队列、举报决定/动作/追问/申诉、日志及能力授权 | [CommunityAdminScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/CommunityAdminScreen.java) |
| `capability:admin-catalog` | 目录编辑/启停/删除、超管详情快捷入口、图册与封面及图片关联 | [AdminScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/AdminScreen.java) |
| `capability:admin-notices` | 公告草稿、独立启停、发布/开始/截止、更新类和普通类弹窗 | [AdminNoticesScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/AdminNoticesScreen.java) |
| `capability:admin-users-data` | 用户管理、角色/状态及数据看板、搜索/分页与权限边界 | [AdminScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/AdminScreen.java) |
| `capability:prices` | 计价单位、阶梯走势/范围、超管历史更正/删除/审计和当前价同步 | [PriceHistoryScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/PriceHistoryScreen.java) |
| `capability:map` | 六处已确认区域、离线底图、拖拽/缩放/点选/楼层入口与失败重试 | [CampusMapScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/CampusMapScreen.java) |
| `capability:navigation-errors` | 手账风格、底栏/首页/搜索、返回栈、加载空错状态、输入保留及重试 | [MainActivity.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/MainActivity.java) |
| `capability:settings-update` | 缓存清理、版本阶段展示、检查更新与iOS分发等效方案 | [ProfileScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/32215aab169bfe9ca40d7189a09c59c325744f21/app/src/main/java/cn/edu/bjtu/foodtime/presentation/ProfileScreen.java) |
| `capability:quick-review` | Android dev新增的一键点评入口、选菜/搜索与共享点评表单 | [ReviewScreen.java](https://github.com/FoodtimeNeo/FoodtimeNeo-Android/blob/ff1ed41c21b6361a3ec7ae0280878a2806c14a7a/app/src/main/java/cn/edu/bjtu/foodtime/presentation/ReviewScreen.java) |

## 调查与验收要求

这份路由清单由当前源码抽取，覆盖MainActivity注册入口；能力表补充跨页面流程。它们是防遗漏索引，不是完整业务审计结论。AuthScreen、AppealOnlyScreen、图片查看器、分组弹窗、缓存、后台调度和各Repository/JSON adapters都需独立审查。

不要只看Android文档导航：其中仍有旧版本文字。当前源码、接口、测试、最新发布记录及用户最新确认的规则优先；发生冲突要调查并向用户确认，不能悄悄回退行为。

保留手账风格和社区页操作层级，检查角色权限、正常/空/错/重试/冲突/过期/切号场景。已知Android问题不应机械复制。端内实现可以不同，业务含义和可达操作要对齐。

## 容易遗漏的规则

- 普通账号参与权限由服务器当前策略与能力决定，不硬编码学校邮箱域；受限申诉会话不能当正常会话。
- 草稿是每服务/账号本机一份，带图持久化；退出保留，注销清理，不擅自做云同步。
- 菜品与帖子收藏分别管理，默认分组、新建入口、多分组、分组删除及取消收藏行为都要覆盖。
- 浏览历史两类各50条；历史与浏览量独立，刷新/评论不重复计数。
- 帖子修改隐藏重审并保留互动；置顶名额、待审隐藏与通过恢复的状态都要对照。
- 反馈导出含处理状态/处理建议，后者是公开回复；旧回复列兼容、批量有效行处理、已完成归档及回复历史不能丢。
- 价格单位、连续同价合并、阶梯图、历史更正/删除和当前值同步按后端执行，不在客户端另造规则。
- 图片要覆盖初次布局偏移、缓存中滑动空白、连续缩放、多图切换、方向/格式、关联失败重试和切号隔离。
- 公告时间、两类最新有效弹窗、期限及免打扰沿用真实后端；通知保持站内内容和系统投递分离。
- 地图仅复刻已确认的缩放/拖动/点选与目录入口，不把规划中的GPS或道路导航算作Android已完成能力。

完整路由、源码位置和状态见 [coverage.json](parity/coverage.json)。
