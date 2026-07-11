# Planora

**中文** | **English**

Planora 是一款面向 IB 与 IGCSE 学生的学习规划 App。当前 1.4.1 版本已经形成从创建、计划、提醒、重复执行到备份恢复的日常学习闭环，并重点强化了重复规则、通知和数据迁移稳定性。

Planora is a study planning app for IB and IGCSE students. Version 1.4.1 completes the daily loop from creation and planning through reminders, recurrence, completion, and recovery, with focused stability work around recurrence, notifications, and data migration.

## 当前版本 / Current Version

- Version: **1.4.1**
- Build: **5**
- Platform: iOS, iPadOS, macOS, visionOS target support through the Xcode project
- UI: SwiftUI, SwiftData, Observation, Liquid Glass-style custom surfaces
- Status: Stable v1.4.1 daily academic planning workflow

## 功能范围 / Scope

### 中文

- 欢迎动画与 Planora 品牌首屏
- 清楚的 App 介绍页，采用接近 Apple 系统 App 的简洁信息布局
- 用户名录入流程，主页问候语会显示用户输入的名字
- IB / IGCSE 课程体系选择
- 科目与额外学习内容选择
- SwiftData 真实任务创建与保存
- 任务类型选择：Assignment、IA、EE、TOK、CAS、Exam、Event、Custom
- 任务表单：标题、科目、是否有 Deadline、日期、进度类型、备注
- 创建表单会根据任务类型预设标题、Deadline、进度类型和阶段，并使用用户已选择的科目
- 进度支持百分比与阶段两种类型
- 主页从 SwiftData 读取真实任务，空状态不再显示假任务
- Learning Progress 只基于真实任务显示，空任务时不展示静态学习进度
- 主页包括 Current Focus、Upcoming Tasks、Learning Progress 和 Calendar Preview
- “我的”页面，包括个人信息、课程、科目数量和默认设置区域
- 系统 TabView 底栏：首页、prominent 新建、我的
- iOS 27 SDK 系统 Liquid Glass Tab Bar 外观，底部位置和按压反馈由系统管理
- 本地 UserDefaults 保存学习空间基础信息

### English

- Animated Planora welcome screen
- Clear feature introduction screen inspired by Apple system onboarding patterns
- Username entry flow, with the dashboard greeting using the entered name
- IB / IGCSE curriculum selection
- Subject and extra learning selection
- Real SwiftData task creation and persistence
- Task type selection: Assignment, IA, EE, TOK, CAS, Exam, Event, Custom
- Task form with title, subject, optional deadline, date, progress type, and notes
- Creation forms use task-type defaults for title, deadline, progress type, and stages, based on the user's selected subjects
- Progress supports both percentage and stage-based tracking
- Dashboard reads real SwiftData tasks and shows an empty state instead of fake tasks
- Learning Progress is shown only from real tasks, with no static progress when there are no tasks
- Dashboard with Current Focus, Upcoming Tasks, Learning Progress, and Calendar Preview
- Profile screen with user profile, curriculum, subject count, and placeholder settings
- System TabView bar with Home, prominent Create, and Profile
- iOS 27 SDK system Liquid Glass Tab Bar appearance, with placement and press feedback managed by the system
- Local UserDefaults persistence for the basic learning profile

## 项目结构 / Project Structure

```text
planora/
  Components/     Shared SwiftUI components and glass surfaces
  Create/         Task type selection and task creation form
  Dashboard/      Home dashboard and main app tab shell
  Models/         App phases, curriculum models, SwiftData task model, subject library
  Onboarding/     Welcome, feature intro, username, curriculum, and subject selection
  Profile/        Profile screen
  State/          Observable app store and persistence
  Theme/          Colors, layout constants, navigation helpers
```

## 开发环境 / Development

### 中文

1. 使用 Xcode 打开 `planora.xcodeproj`。
2. 选择 `planora` scheme。
3. 选择 iPhone / iPad / Mac 目标设备运行。
4. 如需无签名构建，可在终端运行：

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project planora.xcodeproj \
  -scheme planora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

### English

1. Open `planora.xcodeproj` in Xcode.
2. Select the `planora` scheme.
3. Run on an iPhone, iPad, or Mac destination.
4. For an unsigned command-line build:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project planora.xcodeproj \
  -scheme planora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

## 设计方向 / Design Direction

### 中文

Planora 1.2 继续追求 Apple 风格的简洁和清晰：内容直接嵌入背景，卡片和按钮保持轻量，底栏使用系统 TabView，让 iOS 27 SDK 接管 Liquid Glass 导航外观。当前版本把主页从静态展示推进到真实 SwiftData 任务数据。

### English

Planora 1.2 keeps the Apple-like sense of clarity: content sits naturally on the background, panels stay light, controls remain direct, and the tab bar is system-managed through TabView so the iOS 27 SDK provides the Liquid Glass navigation appearance. This version moves the dashboard from static presentation to real SwiftData-backed task data.

## 后续计划 / Next Steps

- 增加任务详情与编辑 / Add task details and editing
- 增加任务详情页和课程进度模型 / Add task detail screens and curriculum progress models
- 接入日历与提醒能力 / Integrate calendar and reminder capabilities
- 增加更多平台尺寸适配 / Improve responsive behavior across more device sizes

## License

Private project. All rights reserved unless a license is added later.
