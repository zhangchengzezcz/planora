# Planora

**中文** | **English**

Planora 是一款面向 IB 与 IGCSE 学生的学习规划 App。当前 1.6.0 版本在完整日常学习闭环的基础上，加入使用最新 SwiftUI 桌面结构构建的原生 macOS 工作区，并继续提供英文、简体中文和日文完整本地化。

Planora is a study planning app for IB and IGCSE students. Version 1.6.0 adds a native macOS workspace built with the latest SwiftUI desktop structure while preserving the complete daily planning loop and full English, Simplified Chinese, and Japanese localization.

## 交互式演示 / Interactive Demo

[打开 Planora 交互式网页演示 / Open the interactive web demo](https://zhangchengzezcz.github.io/planora/)

网页演示依据当前 SwiftUI App 的启动动画、系统式底栏、首页、任务、新建、搜索、今日/本周规划、任务详情和设置界面制作，并支持简体中文、英文、日文及 IB/IGCSE 即时切换。演示数据仅保存在当前浏览器，不会写入真实 App。

The browser demo mirrors the current SwiftUI app's welcome animation, system-style tab bar, Home, Tasks, Create, Search, Today/Week planning, task details, and settings, with live Simplified Chinese, English, Japanese, and IB/IGCSE switching. Demo data stays in the current browser and does not modify the iOS app.

[![Planora interactive demo](https://zhangchengzezcz.github.io/planora/og.png)](https://zhangchengzezcz.github.io/planora/)

## 当前版本 / Current Version

- Version: **1.6.0**
- Build: **10**
- Platform: **iOS and native macOS 27**
- UI: SwiftUI, SwiftData, Observation, system navigation and platform-native surfaces
- Status: Native desktop and mobile academic planning workflow

## 功能范围 / Scope

### 中文

- 欢迎动画与 Planora 品牌首屏
- 清楚的 App 介绍页，采用接近 Apple 系统 App 的简洁信息布局
- 用户名录入流程，主页问候语会显示用户输入的名字
- IB / IGCSE 课程体系选择
- 科目与额外学习内容选择
- SwiftData 真实任务创建与保存
- 任务类型选择：Assignment、IA、EE、TOK、CAS、Exam、Event、Custom
- 任务表单：标题、科目、Deadline、计划完成日期、提醒、重复规则、优先级、进度类型、时间线和备注
- 创建表单会根据任务类型预设标题、Deadline、进度类型和阶段，并使用用户已选择的科目
- 进度支持百分比与阶段两种类型
- 任务详情、编辑、完成、重新打开、删除撤销和优先级管理
- IA、EE、TOK、CAS、Practical 与 Revision 学术工作流模板
- 本地多重提醒、推迟提醒与最近 48 条系统通知滚动队列
- 每日、每周、双周、每月与自定义重复任务，并支持本次、本次及以后、整个系列
- 快速新建、今日计划、本周计划与计划完成日期
- 任务搜索、筛选、排序、科目 Dashboard 和应用内月历
- JSON v8 备份、导入预览、重复识别、覆盖策略、事务回滚与自动本地备份
- 主页从 SwiftData 读取真实任务，空状态不再显示假任务
- Learning Progress 只基于真实任务显示，空任务时不展示静态学习进度
- 主页包括 Current Focus、Upcoming Tasks、Learning Progress 和 Calendar Preview
- “我的”页面，包括个人信息、课程、科目、外观、任务显示与备份设置
- 系统 TabView 底栏：首页、任务、我的、搜索和 prominent 新建
- iOS 27 SDK 系统 Liquid Glass Tab Bar 外观，底部位置和按压反馈由系统管理
- 英文、简体中文与日文 String Catalog 完整本地化
- 原生 macOS 27 侧栏工作区，直接访问首页、今日、本周、任务和课程
- Mac 使用系统工具栏搜索、系统任务表格、详情检查器与独立设置窗口
- Mac 支持 `⌘N` 新建任务与 `⌘F` 搜索，隐藏工具栏后可通过系统命令重新显示
- ManageBac 课程工作区显示教师、Unit 与关联任务，并识别 PDP/PDP1/PDP2、GP/GPTPD 与 Global Perspectives
- 本地 UserDefaults 保存学习空间与显示偏好，SwiftData 保存任务

### English

- Animated Planora welcome screen
- Clear feature introduction screen inspired by Apple system onboarding patterns
- Username entry flow, with the dashboard greeting using the entered name
- IB / IGCSE curriculum selection
- Subject and extra learning selection
- Real SwiftData task creation and persistence
- Task type selection: Assignment, IA, EE, TOK, CAS, Exam, Event, Custom
- Task forms with title, subject, deadline, planned date, reminders, recurrence, priority, progress, timeline, and notes
- Creation forms use task-type defaults for title, deadline, progress type, and stages, based on the user's selected subjects
- Progress supports both percentage and stage-based tracking
- Task details, editing, completion, reopening, undoable deletion, and priority management
- Academic workflow templates for IA, EE, TOK, CAS, Practical, and Revision
- Multiple local reminders, snoozing, and a rolling queue of the nearest 48 system notifications
- Daily, weekly, biweekly, monthly, and custom recurring tasks with occurrence, future, and series scopes
- Quick Create, Today planning, This Week planning, and planned completion dates
- Task search, filters, sorting, subject dashboards, and an in-app monthly calendar
- JSON v8 backup with import previews, duplicate detection, overwrite strategies, transactional rollback, and automatic local backups
- Dashboard reads real SwiftData tasks and shows an empty state instead of fake tasks
- Learning Progress is shown only from real tasks, with no static progress when there are no tasks
- Dashboard with Current Focus, Upcoming Tasks, Learning Progress, and Calendar Preview
- Profile screen with personal, curriculum, subject, appearance, task-display, and backup settings
- System TabView bar with Home, Tasks, Profile, Search, and prominent Create
- iOS 27 SDK system Liquid Glass Tab Bar appearance, with placement and press feedback managed by the system
- Complete String Catalog localization in English, Simplified Chinese, and Japanese
- A native macOS 27 sidebar workspace with direct access to Home, Today, This Week, Tasks, and Courses
- System toolbar search, a native task table, a task inspector, and a dedicated Settings window on Mac
- Mac keyboard shortcuts for New Task (`⌘N`) and Search (`⌘F`), with the system command available to restore a hidden toolbar
- A ManageBac course workspace for teachers, units, and related tasks, including PDP/PDP1/PDP2, GP/GPTPD, and Global Perspectives recognition
- Local UserDefaults persistence for profile and display preferences, plus SwiftData task storage

## 项目结构 / Project Structure

```text
planora/
  Components/     Shared SwiftUI components and glass surfaces
  Create/         Task type selection and task creation form
  Dashboard/      Home dashboard and main app tab shell
  Mac/            Native macOS sidebar, planning, task, course, and settings workspaces
  ManageBac/      Read-only account connection, courses, units, and task import
  Models/         App phases, curriculum models, SwiftData task model, subject library
  Onboarding/     Welcome, feature intro, username, curriculum, and subject selection
  Profile/        Profile, subjects, appearance, task display, and backup settings
  Recurrence/     Recurrence rules and series editing
  Reminders/      Local notification scheduling and reminder editing
  Search/         Indexed task search and filtering
  Tasks/          Task details, lists, persistence, backup, and operations
  State/          Observable app store and persistence
  Theme/          Colors, layout constants, navigation helpers
```

## 开发环境 / Development

### 中文

1. 使用 Xcode 打开 `planora.xcodeproj`。
2. 选择 `planora` scheme。
3. 选择 iPhone 模拟器、真机，或 `My Mac` 运行。
4. 如需无签名构建，可在终端运行：

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project planora.xcodeproj \
  -scheme planora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

原生 macOS 构建：

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project planora.xcodeproj \
  -scheme planora \
  -destination 'platform=macOS,arch=arm64' \
  build CODE_SIGNING_ALLOWED=NO
```

### English

1. Open `planora.xcodeproj` in Xcode.
2. Select the `planora` scheme.
3. Run on an iPhone simulator, device, or `My Mac`.
4. For an unsigned command-line build:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project planora.xcodeproj \
  -scheme planora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

Native macOS build:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project planora.xcodeproj \
  -scheme planora \
  -destination 'platform=macOS,arch=arm64' \
  build CODE_SIGNING_ALLOWED=NO
```

## 设计方向 / Design Direction

### 中文

Planora 1.6.0 继续追求 Apple 风格的简洁和清晰：iPhone 保留系统 TabView，Mac 使用原生 `NavigationSplitView` 侧栏、工具栏、表格、检查器与设置场景。界面减少装饰性背景和自定义按钮，让信息层级、窗口行为与键盘操作交给系统组件管理。

### English

Planora 1.6.0 keeps an Apple-like sense of clarity: iPhone retains its system TabView while Mac uses a native `NavigationSplitView`, toolbar, table, inspector, and Settings scene. Decorative backgrounds and custom controls are reduced so hierarchy, window behavior, and keyboard interaction remain system-managed.

## 后续计划 / Next Steps

- 子任务与预计用时 / Subtasks and estimated duration
- 归档、历史与批量操作 / Archive, history, and bulk operations
- 任务资料链接 / Task resource links
- 考试复习计划、Topic 与成绩记录 / Exam planning, topics, and assessment tracking

## License

Private project. All rights reserved unless a license is added later.
