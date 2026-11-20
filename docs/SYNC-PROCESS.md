# 持续同步 Android 的流程

用户要求包括后续更新，不能只复刻一次 v2.0.0β 就停止维护。

## 每次开始与合并前

1. 更新 Android main/dev、Backend main 和本仓 dev 的只读参照，记录准确提交与实际部署版本。执行 `python3 scripts/check_repository.py --upstream` 查看漂移。
2. 对比上次参照以来的全部提交，包括路由之外的菜单、弹窗、图片、缓存、通知、权限和失败路径。路由数量不变不代表没有功能变化。
3. 把新增/变化项加入 coverage.json，关联 Android 提交、源码、iOS 实现位置、验收结果和影响范围；dev 中未发布项也跟踪，注明来源，不冒充已发布。
4. 编写对应 iOS 功能与回归，跨账号/角色/状态验证。涉及后端契约时交叉检查 Backend；不擅自修改其他端。
5. PR说明本次对照的Android SHA、覆盖ID、行为差异、验证环境及待确认项。代码、同步记录和证据一起审查。

## 参照与完成是两个状态

coverage.json 的 reference 表示当前调查目标；更新它不代表实现了这些功能。lastReviewedAndroidCommit 表示完成差异审查的main提交，lastFullyAlignedAndroidCommit只在全部目标有合格证据、平台差异已获批准时填写。初始化时两者均为空。

新 main 或 dev 出现变化后，接手人审查所有差异再更新目标，评估原已验证项是否需要回归。不得只改SHA让CI变绿；不能保留过时目标后宣称“全部同步”。

## 基础检查能做什么

默认检查目录/文档、参照格式、条目唯一性、实现/证据字段与完整对齐标记的一致性。`--upstream`只读比较远端main/dev：main漂移返回失败，dev漂移提示待跟进；加`--strict-dev`可使dev漂移也失败。命令不自动改文件、不移植业务、不发消息、不创建任务或定时调度。

CI在PR和main/dev推送时运行默认检查及上游检查；手动运行可选择严格dev检查。它只验证记录与仓库约定，不能判断业务正确，更不能代替iOS构建或验收。接手人建立Xcode工程后，必须接入真实的macOS构建、单测和模拟器门禁。

## 完成与差异

条目状态为 not-started / in-progress / implemented / verified / blocked / approved-equivalent。verified必须有实现位置和可检查证据；blocked写明阻碍，平台等效必须有关联的用户批准记录。implemented不等于验证完成。

全量完成要求：所有目标条目verified或有批准的等效实现；最新Android差异已审查；接口、角色、图片/存储/通知和真实业务主链通过；可运行安装与分发路径明确。测试版标签、初始化CI或一张截图都不满足这个条件。
