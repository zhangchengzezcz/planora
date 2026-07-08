# Changelog / 更新说明

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
