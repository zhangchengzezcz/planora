# Changelog / 更新说明

## 1.4.1 - 2026-07-11

### 中文

- 新增独立单元测试目标，覆盖月末、闰日、夏令时、跨时区、双周、多阶段与滚动提醒队列。
- 修复每月 31 日在短月份跳过实例的问题，并正确处理 2 月 29 日的年度间隔。
- 修复“本次及以后”未真正拆分重复系列的问题，同时保留已完成历史实例。
- 为删除的单次重复实例保存排除日期，避免滚动维护重新生成；撤销删除会同步移除排除记录。
- 修复“删除本次及以后”后无限系列重新生成的问题；删除会截断系列，撤销会恢复原重复规则。
- Deadline 与 Planned Date 新增稳定日历日期标识，切换时区后仍保持原日期。
- 通知重排统一使用最近 48 条滚动队列，并在新建系列、系列编辑、导入和撤销后立即刷新。
- App 激活时会刷新通知权限；普通队列重排会保留有效的推迟提醒，同时清理已完成任务的旧请求。
- 导入保存失败时回滚整个上下文，避免留下半成品。
- 备份格式使用版本 8；未上架阶段只接受当前格式，不再保留 v1、v2、v3 与 v7 兼容解码。
- 加入 2,000 项任务的 SwiftData、查询与备份性能基准。
- 修复重复任务在 UUID 或系列 ID 变化后再次导入的问题；去重会按重复实例的标题、科目、类型与发生日期识别，同时保留同系列不同日期的任务。
- 导入预览现在也会统计同一备份文件内部的重复实例，选择“跳过重复”时只导入一份。
- 合并“作业”与“课程作业”，IGCSE 创建入口不再重复显示课程作业；作业改用原课程作业图标。
- 修复空周仍显示“最忙”日期的问题；只有存在已安排任务时才计算最忙日。
- 今日与本周的“无安排”状态移除玻璃卡片，改为直接嵌入背景的轻量文字。
- 今日空状态只保留“今天没有安排”，移除计划日期操作说明。
- 设置页新增外观自定义，可选择跟随系统、浅色或深色模式，以及系统、圆体或衬线字体。
- 新增极光、天空、薄荷与玫瑰背景，并支持蓝色、绿色、琥珀与粉色强调色；选择会在设备本地保存并即时应用。
- 新增一键恢复默认外观，品牌 Logo 保持固定字形，避免全局字体影响品牌识别。

### English

- Added a dedicated unit-test target for month-end, leap-day, DST, time-zone, biweekly, long-timeline, and rolling-reminder boundaries.
- Fixed monthly recurrence skipping short months and corrected February 29 behavior for yearly month intervals.
- Fixed this-and-future edits so they split into an independent recurring series while preserving completed history.
- Added recurrence exclusions so deleted occurrences stay deleted; undo removes the exclusion consistently.
- Fixed future-series deletion so infinite recurrences stay truncated; undo restores the original recurrence rule.
- Added stable calendar-day identifiers for deadlines and planned dates across time-zone changes.
- Unified scheduling around the nearest 48-request rolling queue after series creation, editing, import, and undo.
- Refreshed notification authorization when the app becomes active and preserved valid snoozes during ordinary queue reconciliation.
- Added transactional rollback when an import save fails.
- Standardized backups on version 8 and removed v1, v2, v3, and v7 compatibility before public release.
- Added SwiftData, fetch, and backup performance coverage for 2,000 tasks.
- Fixed recurring tasks being imported again after their task or series UUID changed by matching each occurrence on title, subject, type, and occurrence date while preserving distinct dates.
- Import previews now count duplicate recurring occurrences inside the same backup, and Skip Duplicates imports only one copy.
- Merged Assignment and Coursework so IGCSE creation no longer shows duplicate categories, and Assignment now uses the former Coursework icon.
- Fixed empty weeks showing a misleading busiest day; busiest-day calculations now require scheduled tasks.
- Removed glass cards from Today and This Week empty states in favor of lightweight text directly on the background.
- Reduced the Today empty state to “Nothing Planned Today” and removed the Planned Date instruction.
- Added Appearance settings for system, light, or dark display modes and system, rounded, or serif typography.
- Added Aurora, Sky, Mint, and Rose backgrounds plus blue, green, amber, and pink accents, saved locally and applied immediately.
- Added one-tap appearance reset while keeping the Planora logo typography stable.

## 1.4 - 2026-07-11

### 中文

- 新增本地通知与多重提醒，支持截止前 7/3/1 天、当天、逾期和自定义时间。
- 支持通知权限状态、系统设置入口、完成或删除时取消提醒，以及 1 小时后/明天再提醒。
- 新增重复任务系列，支持每日、每周指定星期、每两周、每月、自定义间隔、结束日期和重复次数。
- 重复任务支持仅本次、本次及以后、整个系列三种编辑和删除范围。
- 新增快速新建，并记忆最近使用的科目、任务类型、日期与提醒偏好。
- 新增 Planned Date，并提供今日和本周执行视图，区分计划完成日期与最终 Deadline。
- 删除任务后支持撤销；破坏性操作前自动保存最近一次本地备份。
- 导入前显示任务数与重复数，并支持跳过重复、覆盖相同任务或全部作为新任务导入。
- JSON 备份格式升级到版本 7，包含提醒、重复系列与 Planned Date。
- 补齐上述功能的英文、简体中文与日文本地化。

### English

- Added local multi-reminders for seven, three, or one day before a deadline, the due date, overdue dates, and custom times.
- Added permission-aware notification settings, Settings recovery, automatic cancellation, and one-hour/tomorrow snooze actions.
- Added recurring task series with daily, selected weekday, biweekly, monthly, custom interval, end-date, and occurrence-count rules.
- Added occurrence-only, this-and-future, and entire-series edit/delete scopes.
- Added Quick Create with remembered subject, task type, date, and relative-reminder preferences.
- Added Planned Date plus Today and This Week execution views, distinct from final deadlines.
- Added deletion undo and automatic local backups before destructive operations.
- Added import previews and duplicate handling through skip, overwrite, or import-as-new strategies.
- Upgraded JSON backups to version 7 with reminders, recurrence, and Planned Date.
- Completed English, Simplified Chinese, and Japanese localization for the new workflows.

## Unreleased - 2026-07-10

### 中文

- 完成任务详情、编辑、完成、重新打开、删除和优先级闭环。
- 首页 Current Focus 结合完成状态、优先级和截止日期选择重点任务。
- 为阶段型任务加入可持久化的学术时间线，并支持在详情页按顺序推进阶段。
- 加入 IA、EE、TOK、CAS 以及 IGCSE Practical、Revision 工作流模板。
- 时间线进度接入首页科目进度计算。
- JSON 备份格式升级到版本 3。
- 补充新增任务类型、阶段和界面的英文、简体中文与日文文案。
- 新增科目 Dashboard，集中展示科目任务、进度、完成率和近期截止日期。
- 搜索支持按科目、任务类型、截止状态、完成状态和优先级筛选。
- 首页新增本周完成、最活跃科目、未来七天负载和逾期数量统计。
- App 内日历支持月份切换、按日查看截止任务和进入任务详情，不接入系统日历。

### English

- Completed the task detail, editing, completion, reopening, deletion, and priority workflow.
- Updated Current Focus to consider completion, priority, and deadline ordering.
- Added persistent academic timelines for stage-based tasks with sequential milestone controls.
- Added IA, EE, TOK, CAS, and IGCSE Practical and Revision workflow templates.
- Connected timeline completion to subject progress calculations on Home.
- Upgraded JSON backups to version 3.
- Added English, Simplified Chinese, and Japanese strings for the new task types and milestones.
- Added subject dashboards for task totals, progress, completion, and upcoming deadlines.
- Added subject, type, deadline, completion, and priority filters to Search.
- Added weekly completion, most active subject, seven-day workload, and overdue statistics.
- Enhanced the in-app calendar with month navigation and per-day task browsing without system calendar access.

## 1.2 - 2026-07-08

### 中文

Planora 1.2 将 App 从视觉原型推进为可用的学术任务规划基础版本。本版本保留现有 SwiftUI 和系统 TabView 设计，并加入 SwiftData 驱动的真实任务创建与首页展示。

#### 新增

- 新增 SwiftData `PlanoraTask` 持久化模型。
- 新增任务类型：Assignment、IA、EE、TOK、CAS、Exam、Event、Custom。
- 新增加号 tab 的 `Create New` 入口，支持选择任务类型。
- 新增任务创建表单，包含标题、科目、Deadline、进度、备注和保存。
- 创建表单会根据任务类型和用户当前科目预设标题、Deadline、进度类型和阶段。
- 新增 Deadline / No deadline 两种任务模式。
- 新增百分比进度和阶段式进度两种 Progress State。
- 首页改为从 SwiftData 读取真实任务，保存后自动显示到 Home。
- 新增无任务空状态，不再展示静态假任务。
- 无任务时隐藏 Learning Progress 和 Calendar Preview，避免显示假数据。

#### 改进

- Upcoming Tasks 区分 Deadline 与 Progress / Stage。
- Learning Progress 区分 Subject Progress 与 Task Completion，并只从真实任务聚合。
- Calendar Preview 改为根据真实任务 deadline 生成事件预览。

### English

Planora 1.2 turns the app from a visual prototype into a functional academic task-planning foundation. It preserves the existing SwiftUI and system TabView design while adding real SwiftData-backed task creation and dashboard rendering.

#### Added

- Added the SwiftData `PlanoraTask` persistence model.
- Added task types: Assignment, IA, EE, TOK, CAS, Exam, Event, Custom.
- Added the `Create New` flow from the prominent plus tab.
- Added a task creation form with title, subject, deadline, progress, notes, and save.
- Creation forms now use task-type and selected-subject defaults for title, deadline, progress type, and stages.
- Added deadline and no-deadline task modes.
- Added percentage and stage-based progress states.
- Updated Home to read real SwiftData tasks and refresh after saving.
- Added an empty task state instead of static fake tasks.
- Hid Learning Progress and Calendar Preview when there are no tasks, avoiding fake data.

#### Improved

- Upcoming Tasks now separates Deadline from Progress / Stage.
- Learning Progress now separates Subject Progress from Task Completion and is aggregated from real tasks only.
- Calendar Preview now derives events from real task deadlines.

## 1.1.1 - 2026-07-08

### 中文

Planora 1.1.1 是底栏实现修正版，改用系统 TabView / Liquid Glass Tab Bar，交由 iOS 27 SDK 处理底栏外观、位置和按压反馈。

#### 改进

- 删除自绘 FloatingGlassTabBar，不再手动绘制底部玻璃背景栏。
- 改用 SwiftUI 系统 TabView / Tab API，让系统提供 Liquid Glass Tab Bar 外观。
- 底栏位置改由系统 safe area 和 tab bar 行为管理，避免手动 padding / offset 造成不同机型偏差。
- 中间“新建”入口改用系统 prominent tab role，保留更突出的加号入口。
- 1.1.1 验证范围收敛到关键 iPhone 构建和视觉路径。

### English

Planora 1.1.1 replaces the custom tab bar with the system TabView / Liquid Glass Tab Bar so the iOS 27 SDK owns the tab appearance, placement, and press feedback.

#### Improved

- Removed the custom FloatingGlassTabBar and stopped drawing a manual glass background bar.
- Switched to SwiftUI's system TabView / Tab API so the system provides the Liquid Glass Tab Bar appearance.
- Let system safe area and tab bar behavior manage bottom placement instead of manual padding / offsets.
- Switched the centered Create entry to the system prominent tab role, preserving a stronger plus entry point.
- Focused 1.1.1 verification on the key iPhone build and visual path.

## 1.1 - 2026-07-07

### 中文

Planora 1.1 是第一个完整的 SwiftUI 视觉基础版本。本版本重点完成欢迎流程、主页样式、个人页样式和底部导航体验，为之后的真实任务管理功能打好结构。

#### 新增

- 新增欢迎动画首屏。
- 新增 Apple 风格的功能介绍页，内容直接融入背景，避免过度装饰。
- 新增用户名录入流程，主页显示 `Hello 用户名`。
- 新增 IB / IGCSE 课程体系选择。
- 新增科目与额外学习内容选择。
- 新增主页默认样式，包含重点任务、即将到来的任务、学习进度和日历预览。
- 新增“我的”页面，展示用户、课程、科目数量和默认设置区域。
- 新增两项式玻璃底栏，包含“首页”“我的”和中间新建按钮。
- 新增可拖动的底栏选中态，切换 tab 时使用平滑动画。

#### 改进

- 调整底栏选中玻璃的深度和文字颜色，在浅色背景下更清晰。
- 改进底栏选中胶囊和中间新建按钮的按压交互玻璃反馈。
- 修复底栏选中项向右拖动时被 tab 内部点击手势抢占的问题。
- 中间新建按钮改为清单加号视觉，更接近提醒事项类创建入口。
- 修复 macOS 下不可用的 iOS navigation bar API 调用。
- 更新 bundle identifier，避免开发者账号注册冲突。
- 将版本号更新为 1.1，build number 更新为 2。

#### 当前限制

- 任务创建、任务详情、真实日历同步等内部功能尚未实现。
- 主页数据仍为默认展示数据，用于确认 1.1 的视觉和流程。

### English

Planora 1.1 is the first complete SwiftUI visual foundation release. It focuses on the welcome flow, dashboard styling, profile styling, and floating navigation experience, while leaving deeper task-management functionality for later versions.

#### Added

- Added animated welcome screen.
- Added Apple-style feature introduction screen with content embedded directly into the background.
- Added username entry flow, with the dashboard greeting using the entered name.
- Added IB / IGCSE curriculum selection.
- Added subject and extra learning selection.
- Added dashboard visual shell with focus task, upcoming tasks, learning progress, and calendar preview.
- Added profile screen with user, curriculum, subject count, and placeholder settings sections.
- Added two-item floating glass tab bar with Home, Profile, and a centered create button.
- Added draggable selected tab indicator with smooth tab switching animation.

#### Improved

- Darkened the selected glass indicator and selected label color for better contrast on light backgrounds.
- Improved press interaction glass feedback for the selected tab capsule and centered create button.
- Fixed the selected tab drag gesture being intercepted by internal tab tap controls.
- Changed the center create button to a checklist-plus visual, closer to a Reminders-style creation affordance.
- Fixed unavailable iOS navigation bar API usage on macOS.
- Updated bundle identifier to avoid development team registration conflicts.
- Updated app version to 1.1 and build number to 2.

#### Current Limitations

- Task creation, task details, and real calendar sync are not implemented yet.
- Dashboard content still uses default display data to validate the 1.1 visual flow.
