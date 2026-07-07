# Changelog / 更新说明

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
