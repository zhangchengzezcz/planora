# Planora

## Planora 1.7.16

### 中文

Planora 不是 ManageBac 的替代品。

Planora 帮助 IB 与 IGCSE 学生整理 ManageBac 中分散的课程、任务、截止日期、成绩与出勤信息，并在本机安排自己的学习。完整课程内容与原始记录仍以 ManageBac 为准。

1.7.13 修复保存失败处理与重复任务续排，明确同步状态、时间表清理和出勤统计的范围，并将自动备份迁移到独立文件。Mac 显示切换采用系统玻璃按钮；帮助中心新增日语，保留中英文内容。

**出勤说明：** 更新后需重新同步 ManageBac。出勤详情统计所选周，仅使用日期范围匹配的学校汇总；首页显示已导入的历史课次。未记录不计入分母，迟到计入出勤。真实学校数据仍需核对。iPhone 首页没有成绩模式切换，软件更新仅适用于 Mac。

### English

Planora is not a replacement for ManageBac.

Planora helps IB and IGCSE students organize courses, tasks, deadlines, grades, and attendance from ManageBac, then plan their own work locally. ManageBac remains the source for full course content and original records.

Version 1.7.13 fixes failed-save handling and rolling recurrence, clarifies sync authority and timetable/attendance ranges, and moves automatic backups to a separate file. Mac display controls use system glass buttons. The Help Center now supports Japanese alongside Chinese and English.

**Attendance note:** sync ManageBac again after updating. Details follows the selected week and only uses a school overview with a matching range. Home shows imported lesson history. Unrecorded lessons are excluded; late arrivals count toward attendance. Live school data still needs verification. There is no Home grade-mode switch on iPhone. In-app updates are Mac-only.

1.7.14 增加 Mac 横向玻璃控件拖动切换，保留移动端原生控件。

1.7.14 adds horizontal drag selection to Mac glass controls while preserving native mobile controls.

1.7.15 修复 Mac 临时签名包的 Sparkle 启动加载失败。此包未经过 Apple 公证。

1.7.15 fixes Sparkle loading in ad-hoc signed Mac builds. This distribution is not Apple-notarized.

1.7.16 修复同步连接误判，增加导入重试及退出入口，并将个人资料持久化以避免清除偏好后重新进入引导。

1.7.16 fixes false stale-sync rejection, adds import recovery, and persists profiles outside preferences.

**下载 / Download:** [Planora 1.7.16 for Mac](https://github.com/zhangchengzezcz/planora/releases/tag/1.7.16) · [更新说明 / Release notes](updates/1.7.16.md)

## 当前版本 / Current Version

- Version: **1.7.16** (build **31**)
- Platforms: **iOS / iPadOS 26+**, **macOS 26+**
- Built with SwiftUI, SwiftData, and platform-native navigation
- Mac update channel: Sparkle; iPhone and iPad do not use Sparkle

## 交互式演示 / Interactive Demo

[打开 Planora 交互式网页演示 / Open the interactive web demo](https://zhangchengzezcz.github.io/planora/)

网页演示展示 Planora 的部分交互；它与原生 App 的最新界面和功能可能不同。演示数据仅保存在当前浏览器，不会写入真实 App。

The browser demo presents selected Planora interactions and may differ from the latest native app. Demo data stays in the current browser and does not modify the app.

[![Planora interactive demo](https://zhangchengzezcz.github.io/planora/og.png)](https://zhangchengzezcz.github.io/planora/)

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
- iPhone 与 Mac 共用任务置顶、置顶优先排序和 JSON 备份恢复
- IA、EE、TOK、CAS、Practical 与 Revision 学术工作流模板
- 本地多重提醒、推迟提醒与最近 48 条系统通知滚动队列
- 每日、每周、双周、每月与自定义重复任务，并支持本次、本次及以后、整个系列
- 快速新建、今日计划、本周计划与计划完成日期
- 任务搜索、筛选、排序、科目 Dashboard 和应用内月历
- JSON v9 备份、导入预览、重复识别、覆盖策略、事务回滚与自动本地备份
- 主页从 SwiftData 读取真实任务，空状态不再显示假任务
- Learning Progress 只基于真实任务显示，空任务时不展示静态学习进度
- 主页包括 Current Focus、最多两项 Upcoming Tasks、可翻周的 Calendar Preview、成绩、Learning Progress 和出勤
- “我的”页面，包括个人信息、课程、科目、外观、任务显示与备份设置
- iPhone 与 Mac 均支持仅保存在本机的个人头像和姓名缩写头像
- 系统 TabView 底栏：首页、任务、我的、搜索和 prominent 新建
- iPhone 与 iPad 保留系统导航控件；成绩显示模式使用原生 Segmented Control
- 英文、简体中文与日文 String Catalog 完整本地化
- macOS 26+ 原生侧栏工作区，可访问首页、今日、本周、任务、课程、出勤和消息
- Mac 使用系统工具栏搜索、系统任务表格、详情检查器与独立设置窗口
- Mac 个人页支持仅保存在本机的自定义头像，并可随时恢复为姓名缩写
- Mac 支持 `⌘N` 新建任务与 `⌘F` 搜索，隐藏工具栏后可通过系统命令重新显示
- Xcode 文件系统同步目录自动管理源码归属，不再依赖手工维护的 Sources 文件列表
- 共享模型、状态、存储与业务能力；iPhone 与 Mac 仅保留各自轻量、原生的界面壳层
- ManageBac 课程工作区显示教师、Unit 与关联任务，并识别 PDP/PDP1/PDP2、GP/GPTPD 与 Global Perspectives
- 科目与 ManageBac 课程工作区支持 Topic 掌握度、成绩和趋势平均值；成绩可切换数字、柱状图及折线图
- Mac 与 iPad 首页成绩可按时间横向浏览，并可按科目筛选；不同科目使用不同颜色
- ManageBac 同步单独显示出勤项目；课程与时间表入口均可打开出勤明细
- Mac 应用内通过 Sparkle 检查和安装更新；iPhone 与 iPad 不包含该更新器
- Exam 与 Revision 任务支持关联 Topic、考试范围、目标成绩及 Past Paper 目标与完成量
- JSON v9 备份完整保留 Topic、Assessment 与考试复习规划，并支持安全去重、覆盖和新副本导入
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
- Shared task pinning, pinned-first ordering, and JSON backup restoration on iPhone and Mac
- Academic workflow templates for IA, EE, TOK, CAS, Practical, and Revision
- Multiple local reminders, snoozing, and a rolling queue of the nearest 48 system notifications
- Daily, weekly, biweekly, monthly, and custom recurring tasks with occurrence, future, and series scopes
- Quick Create, Today planning, This Week planning, and planned completion dates
- Task search, filters, sorting, subject dashboards, and an in-app monthly calendar
- JSON v9 backup with import previews, duplicate detection, overwrite strategies, transactional rollback, and automatic local backups
- Dashboard reads real SwiftData tasks and shows an empty state instead of fake tasks
- Learning Progress is shown only from real tasks, with no static progress when there are no tasks
- Home with Current Focus, up to two Upcoming Tasks, a navigable Calendar Preview, grades, Learning Progress, and attendance
- Profile screen with personal, curriculum, subject, appearance, task-display, and backup settings
- Device-local profile avatars and generated initials on both iPhone and Mac
- System TabView bar with Home, Tasks, Profile, Search, and prominent Create
- System navigation controls on iPhone and iPad, with a native Segmented Control for grade display modes
- Complete String Catalog localization in English, Simplified Chinese, and Japanese
- A native macOS 26+ sidebar workspace for Home, Today, This Week, Tasks, Courses, Attendance, and Messages
- System toolbar search, a native task table, a task inspector, and a dedicated Settings window on Mac
- Mac keyboard shortcuts for New Task (`⌘N`) and Search (`⌘F`), with the system command available to restore a hidden toolbar
- Xcode file-system-synchronized folders manage source membership automatically instead of a manually maintained Sources list
- Shared models, state, storage, and feature logic with lightweight platform-native presentation shells for iPhone and Mac
- A ManageBac course workspace for teachers, units, and related tasks, including PDP/PDP1/PDP2, GP/GPTPD, and Global Perspectives recognition
- Topic mastery, grades, and current averages in subject and ManageBac course workspaces; switch grades between numbers, bars, and lines
- Chronological, horizontally scrolling Home grade bars on Mac and iPad, with subject filtering and distinct subject colors
- A separate attendance item during ManageBac sync, with attendance details reachable from both Courses and Timetable
- Sparkle-based in-app updates on Mac only; iPhone and iPad do not include this updater
- Topic links, exam scope, target score, and Past Paper goals for Exam and Revision tasks
- JSON v9 backup support for topics, assessments, and exam planning with safe skip, overwrite, and import-as-new strategies
- Local UserDefaults persistence for profile and display preferences, plus SwiftData task storage

## 项目结构 / Project Structure

```text
planora/
  Components/     Shared SwiftUI components, glass surfaces, and grade charts
  Create/         Task type selection and task creation form
  Dashboard/      Home dashboard and main app tab shell
  Mac/            Native macOS presentation shell and software updater
  ManageBac/      Read-only connection, courses, attendance, and task import
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
4. 命令行构建使用当前 `xcode-select` 选中的 Xcode；如需指定其他 Xcode，再设置 `DEVELOPER_DIR`。

iOS Simulator 无签名构建：

```bash
xcodebuild -project planora.xcodeproj \
  -scheme planora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

原生 macOS 构建：

```bash
xcodebuild -project planora.xcodeproj \
  -scheme planora \
  -destination 'platform=macOS,arch=arm64' \
  build CODE_SIGNING_ALLOWED=NO
```

### English

1. Open `planora.xcodeproj` in Xcode.
2. Select the `planora` scheme.
3. Run on an iPhone simulator, device, or `My Mac`.
4. Command-line builds use the Xcode selected by `xcode-select`; set `DEVELOPER_DIR` only when selecting another installation.

Unsigned iOS Simulator build:

```bash
xcodebuild -project planora.xcodeproj \
  -scheme planora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

Native macOS build:

```bash
xcodebuild -project planora.xcodeproj \
  -scheme planora \
  -destination 'platform=macOS,arch=arm64' \
  build CODE_SIGNING_ALLOWED=NO
```

## 设计方向 / Design Direction

### 中文

Planora 在 iPhone、iPad 和 Mac 上使用各平台原生导航；任务、课程、成绩与出勤共享模型和同步逻辑，界面按屏幕空间调整。成绩模式使用系统 Segmented Control，Mac 软件更新与窗口布局留在 Mac 专属代码中。玻璃材质用于界面层次，不取代内容的可读性。

### English

Planora uses platform-native navigation on iPhone, iPad, and Mac. Tasks, courses, grades, and attendance share models and sync logic, while layouts adapt to available space. Grade modes use a system Segmented Control; software updates and window layout remain Mac-specific. Glass materials support visual hierarchy without compromising legibility.

## 后续计划 / Next Steps

- 小组件与快捷指令 / Widgets and App Intents
- 无障碍与多窗口体验完善 / Accessibility and multi-window refinement
- 可选的本地学习计时与实际用时分析 / Optional local study timing and actual-duration analysis

## License

Private project. All rights reserved unless a license is added later.

<!-- PLANORA_UNINSTALL_BEGIN -->

## 完整卸载 / Complete Uninstall

### 用户数据与缓存 / User Data vs Cache

Mac 正式版只有一个正在使用的任务数据库：
`~/Library/Application Support/Planora/Planora.store`。
同目录的 `-wal`、`-shm` 是数据库组成部分，不是可清理缓存。
`AutomaticBackup.json`、`LearningProfile.json` 和 `ProfileAvatar.png` 也是用户数据。
不要让 CleanMyMac 或其他清理工具删除整个 Application Support/Planora。

Only `~/Library/Caches/com.zhangchengze.planora.mac` is disposable app cache.
Database WAL/SHM files, backups and avatars are user data, not cache.
Use `bash scripts/clean-planora-cache.sh` to preview the supported cache path;
after quitting Planora, add `--execute` to clear it without touching user data.
Third-party cleaners control their own classifications; review their deletion list.

连接记录位于同一用户数据目录的 `ManageBacConnection.json`（不含密码或 Cookie）。
偏好设置位于 `~/Library/Preferences/com.zhangchengze.planora.mac.plist`。
WebKit/HTTPStorages 下的应用专属目录包含学校登录网站数据，删除会要求重新登录，
但不应删除任务。它们不包含在上述清缓存脚本中。

Preferences and website login data are not included in cache cleaning.
Removing website data can require signing in again; it does not remove the task store.

旧版 `~/Library/Application Support/default.store` 仅作为迁移来源，迁移成功后不再写入。
为防误删其他应用同名数据库，升级不会自动删除这组旧文件。
确认它属于 Planora 且新库数据完整后，可备份再移走旧库及其 `-wal/-shm`。
桌面上的手动备份与 Vlog 的 `Planora-Vlog` 目录不会由正式版卸载流程删除。

The legacy default.store is a migration source only, not a second active database.
Keep it until ownership and migration are verified; never blindly delete generic default.store files.
Manual backups and the separate Vlog project/data are intentionally preserved.

正常更新通过 Sparkle 替换应用包，不移动或重置上述用户数据，无需 PKG。
无法启动的旧版（例如受签名问题影响的 1.7.14）需手动下载新版并替换应用。
不要先运行下面的完整卸载命令。应用签名修复不等于 Apple 公证。

Sparkle updates replace the app bundle while leaving user data in place.
If an old app cannot launch, manually replace it with the new download; do not run full uninstall first.

### 中文

如果只想卸载 Planora App，将 `/Applications/planora.app` 移到废纸篓即可。

如果希望**完整删除 Planora 以及它在当前 Mac 用户账户中保存的本地数据、偏好设置、缓存、日志、保存状态和 Sparkle 更新数据**，请先退出 Planora，然后在 Terminal 中执行下面的命令。

**注意：完整删除会永久删除本机 Planora 的本地数据。执行前请先导出或备份仍然需要的 Planora 数据。**

```bash
osascript -e 'tell application "planora" to quit' 2>/dev/null || true
sleep 2

rm -rf "/Applications/planora.app"
rm -rf "$HOME/Applications/planora.app"

rm -rf "$HOME/Library/Application Support/Planora"
rm -rf "$HOME/Library/Application Support/com.zhangchengze.planora.mac"

rm -f "$HOME/Library/Preferences/com.zhangchengze.planora.mac.plist"
rm -rf "$HOME/Library/Caches/com.zhangchengze.planora.mac"

rm -rf "$HOME/Library/Saved Application State/com.zhangchengze.planora.mac.savedState"

rm -rf "$HOME/Library/Logs/Planora"
rm -rf "$HOME/Library/Logs/com.zhangchengze.planora.mac"

rm -rf "$HOME/Library/WebKit/com.zhangchengze.planora.mac"
rm -rf "$HOME/Library/HTTPStorages/com.zhangchengze.planora.mac"
rm -rf "$HOME/Library/HTTPStorages/com.zhangchengze.planora.mac.binarycookies"

rm -rf "$HOME/Library/Caches/com.zhangchengze.planora.mac/org.sparkle-project.Sparkle"
rm -rf "$HOME/Library/Application Support/com.zhangchengze.planora.mac/Update"

find "$HOME/Library" -maxdepth 4 \
  \( -iname '*com.zhangchengze.planora.mac*' -o -iname '*planora*' \) \
  -print 2>/dev/null

```

最后的 `find` 命令只会**列出**仍然包含 `Planora` 或 `com.zhangchengze.planora.mac` 名称的项目，不会自动删除这些额外项目。这样可以在删除未知文件之前先进行检查。

如果只需要删除 App，而希望保留任务、设置和其他本地数据，请不要执行完整删除命令，只删除：

```bash
rm -rf "/Applications/planora.app"
```

### English

To remove only the Planora application, move `/Applications/planora.app` to the Trash.

To **completely remove Planora together with local data, preferences, caches, logs, saved application state, and Sparkle update data stored in the current Mac user account**, quit Planora first and run the following commands in Terminal.

**Warning: a complete uninstall permanently removes Planora's local data from this Mac. Export or back up any Planora data you still need before running these commands.**

```bash
osascript -e 'tell application "planora" to quit' 2>/dev/null || true
sleep 2

rm -rf "/Applications/planora.app"
rm -rf "$HOME/Applications/planora.app"

rm -rf "$HOME/Library/Application Support/Planora"
rm -rf "$HOME/Library/Application Support/com.zhangchengze.planora.mac"

rm -f "$HOME/Library/Preferences/com.zhangchengze.planora.mac.plist"
rm -rf "$HOME/Library/Caches/com.zhangchengze.planora.mac"

rm -rf "$HOME/Library/Saved Application State/com.zhangchengze.planora.mac.savedState"

rm -rf "$HOME/Library/Logs/Planora"
rm -rf "$HOME/Library/Logs/com.zhangchengze.planora.mac"

rm -rf "$HOME/Library/WebKit/com.zhangchengze.planora.mac"
rm -rf "$HOME/Library/HTTPStorages/com.zhangchengze.planora.mac"
rm -rf "$HOME/Library/HTTPStorages/com.zhangchengze.planora.mac.binarycookies"

rm -rf "$HOME/Library/Caches/com.zhangchengze.planora.mac/org.sparkle-project.Sparkle"
rm -rf "$HOME/Library/Application Support/com.zhangchengze.planora.mac/Update"

find "$HOME/Library" -maxdepth 4 \
  \( -iname '*com.zhangchengze.planora.mac*' -o -iname '*planora*' \) \
  -print 2>/dev/null

```

The final `find` command only **lists** remaining items whose names contain `Planora` or `com.zhangchengze.planora.mac`; it does not automatically delete those additional items. This allows them to be reviewed before removing anything unexpected.

If you only want to remove the application while keeping tasks, settings, and other local data, do not run the complete-uninstall commands. Remove only:

```bash
rm -rf "/Applications/planora.app"
```

<!-- PLANORA_UNINSTALL_END -->
