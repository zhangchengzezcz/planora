# Planora

**中文** | **English**

Planora 是一款面向 IB 与 IGCSE 学生的学习规划 App。当前 1.1 版本完成了首屏欢迎、介绍页、用户名录入、课程与科目选择、主页和个人页的基础视觉体验，重点是先把 App 的整体样式、信息架构和 SwiftUI 视图结构搭好。

Planora is a study planning app for IB and IGCSE students. Version 1.1 focuses on the first complete visual foundation: welcome flow, feature introduction, username entry, curriculum and subject selection, dashboard, profile screen, and a polished SwiftUI app structure.

## 当前版本 / Current Version

- Version: **1.1.1**
- Build: **3**
- Platform: iOS, iPadOS, macOS, visionOS target support through the Xcode project
- UI: SwiftUI, Observation, Liquid Glass-style custom surfaces
- Status: Visual 1.1 foundation; deeper internal task features are intentionally not implemented yet

## 功能范围 / Scope

### 中文

- 欢迎动画与 Planora 品牌首屏
- 清楚的 App 介绍页，采用接近 Apple 系统 App 的简洁信息布局
- 用户名录入流程，主页问候语会显示用户输入的名字
- IB / IGCSE 课程体系选择
- 科目与额外学习内容选择
- 主页默认样式，包括重点任务、即将到来的任务、学习进度和日历预览
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
- Dashboard visual shell with focus task, upcoming tasks, progress, and calendar preview
- Profile screen with user profile, curriculum, subject count, and placeholder settings
- System TabView bar with Home, prominent Create, and Profile
- iOS 27 SDK system Liquid Glass Tab Bar appearance, with placement and press feedback managed by the system
- Local UserDefaults persistence for the basic learning profile

## 项目结构 / Project Structure

```text
planora/
  Components/     Shared SwiftUI components and glass surfaces
  Dashboard/      Home dashboard and main app tab shell
  Models/         App phases, curriculum models, dashboard models, subject library
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

Planora 1.1.1 追求 Apple 风格的简洁和清晰：内容直接嵌入背景，卡片和按钮保持轻量，底栏改用系统 TabView，让 iOS 27 SDK 接管 Liquid Glass 导航外观。当前版本优先保证首页和欢迎流程的视觉完成度，为之后的任务管理、日历、AI 学习建议等功能留下结构。

### English

Planora 1.1.1 aims for an Apple-like sense of clarity: content sits naturally on the background, panels stay light, controls remain direct, and the tab bar is now system-managed through TabView so the iOS 27 SDK provides the Liquid Glass navigation appearance. This version prioritizes the welcome flow and dashboard foundation before deeper task management, calendar, and learning-assistant features are added.

## 后续计划 / Next Steps

- 实现真实任务创建与编辑 / Implement real task creation and editing
- 增加任务详情页和课程进度模型 / Add task detail screens and curriculum progress models
- 接入日历与提醒能力 / Integrate calendar and reminder capabilities
- 增加更多平台尺寸适配 / Improve responsive behavior across more device sizes

## License

Private project. All rights reserved unless a license is added later.
