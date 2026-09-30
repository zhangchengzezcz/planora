import SwiftUI

struct HelpCopy {
    let zh: String
    let en: String
    var ja: String? = nil

    func value(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh": zh
        case "ja": ja ?? en
        default: en
        }
    }
}

struct HelpArticle: Identifiable {
    let id: String
    var title: HelpCopy
    var body: HelpCopy
}

struct HelpCategory: Identifiable {
    let id: String
    var title: HelpCopy
    let symbol: String
    var articles: [HelpArticle]
}

enum PlanoraHelpContent {
    static let categories: [HelpCategory] = [
        HelpCategory(id: "start", title: .init(zh: "开始使用", en: "Get started"), symbol: "sparkles", articles: [
            .init(id: "first", title: .init(zh: "第一次打开该做什么？", en: "What should I do first?"), body: .init(zh: "选择课程体系和科目后，就可以创建任务。ManageBac 连接是可选的；连接后，课程、任务、消息和时间表会出现在相应页面。", en: "Choose your curriculum and subjects, then create a task. Connecting ManageBac is optional. Once connected, courses, tasks, messages, and the timetable appear in their respective views.")),
            .init(id: "navigation", title: .init(zh: "在哪里找到今天和本周？", en: "Where are Today and This Week?"), body: .init(zh: "从导航栏打开“今天”或“本周”。首页展示近期重点和日历预览；点击日历的左右箭头可以查看其他周，点击任务可打开详情。", en: "Open Today or This Week from navigation. Home shows your focus and a calendar preview. Use the calendar arrows to move between weeks and select a task for details.")),
            .init(id: "search", title: .init(zh: "怎样快速找到任务？", en: "How do I find a task quickly?"), body: .init(zh: "使用侧栏或页面中的搜索框，输入标题或关键词。也可以在任务页按状态和来源筛选。", en: "Use the sidebar or page search field and enter a title or keyword. You can also filter the task list by status and source."))
        ]),
        HelpCategory(id: "managebac", title: .init(zh: "ManageBac 同步", en: "ManageBac sync"), symbol: "arrow.triangle.2.circlepath", articles: [
            .init(id: "connect", title: .init(zh: "如何连接 ManageBac？", en: "How do I connect ManageBac?"), body: .init(zh: "打开课程页的 ManageBac 入口，按提示在学校的登录网页中完成登录，再确认导入内容。Planora 不要求你在任务表单里填写学校密码。", en: "Open ManageBac from Courses, sign in on your school's web page, then review the import. You do not enter your school password into a Planora task form.")),
            .init(id: "resync", title: .init(zh: "为什么新任务还没出现？", en: "Why is a new task missing?"), body: .init(zh: "在 ManageBac 连接页重新同步，并检查该课程和任务是否包含在导入结果中。学校页面尚未发布、需要重新登录或网络中断时，内容可能暂时缺失。", en: "Sync again from the ManageBac connection page and check whether the course and task are in the import results. Content can be missing if the school has not published it, sign-in has expired, or the network is unavailable.")),
            .init(id: "remote-status", title: .init(zh: "未评分是否表示没完成？", en: "Does ungraded mean incomplete?"), body: .init(zh: "不一定。成绩和完成状态是两件事：老师尚未评分的作业也可能已经提交或完成。以 ManageBac 的完成状态为准；发现不一致时重新同步并查看原任务。", en: "Not necessarily. A grade and completion are different: submitted work may not have been graded yet. Check the completion state in ManageBac; if it differs, sync again and inspect the original task.")),
            .init(id: "sync-limit", title: .init(zh: "同步会修改学校里的内容吗？", en: "Does syncing change school records?"), body: .init(zh: "同步用于读取并导入学校页面的信息。Planora 中的个人计划、置顶和本地备注不会替你向学校提交作业；需要提交时，请前往 ManageBac。", en: "Sync reads and imports information from your school's pages. Personal plans, pins, and local notes in Planora do not submit work to school; submit in ManageBac when required."))
        ]),
        HelpCategory(id: "tasks", title: .init(zh: "任务与提醒", en: "Tasks and reminders"), symbol: "checklist", articles: [
            .init(id: "create", title: .init(zh: "如何新建或编辑任务？", en: "How do I create or edit a task?"), body: .init(zh: "点击新建按钮，填写标题、科目和日期。打开已有任务的详情可调整进度、子任务、计划时间、提醒和其他信息。", en: "Select New Task and enter a title, subject, and date. Open an existing task to change progress, subtasks, planned time, reminders, and other details.")),
            .init(id: "deadline", title: .init(zh: "截止日期和计划日期有什么区别？", en: "What is the difference between due and planned dates?"), body: .init(zh: "截止日期表示任务最晚应完成的时间；计划日期表示你打算什么时候处理。改变计划日期不会改变学校给出的截止时间。", en: "The due date is when a task must be finished. The planned date is when you intend to work on it. Changing your plan does not change a school deadline.")),
            .init(id: "completion", title: .init(zh: "完成任务后会发生什么？", en: "What happens when I complete a task?"), body: .init(zh: "任务会从进行中的列表移至已完成。ManageBac 导入任务的本地完成标记不等于向学校提交；学校端状态会在后续同步时更新。", en: "The task moves from In Progress to Completed. Marking an imported task complete locally does not submit it to school; the school status updates on a later sync.")),
            .init(id: "reminders", title: .init(zh: "提醒为什么没有出现？", en: "Why did a reminder not appear?"), body: .init(zh: "检查任务是否设有截止时间、提醒是否开启，以及系统是否允许 Planora 发送通知。已经完成的任务或过期的提醒可能不会继续通知。", en: "Check that the task has a due time, reminders are enabled, and system notifications are allowed for Planora. Completed tasks or expired reminder times may no longer notify you.")),
            .init(id: "archive", title: .init(zh: "归档与删除有何区别？", en: "How are archive and delete different?"), body: .init(zh: "归档把任务移出日常列表，但仍可在归档中查看。删除的任务会进入最近删除；清空前请确认不再需要。", en: "Archiving removes a task from your daily list but keeps it in Archive. Deleted tasks go to Recently Deleted; review them before permanently removing them."))
        ]),
        HelpCategory(id: "learning", title: .init(zh: "课程与日历", en: "Courses and calendar"), symbol: "books.vertical", articles: [
            .init(id: "courses", title: .init(zh: "课程和科目从哪里来？", en: "Where do courses and subjects come from?"), body: .init(zh: "你可以自行选择科目并管理学习内容。连接 ManageBac 后，学校课程及老师信息会通过同步导入；两者在课程页汇总。", en: "You can choose subjects and organize your own learning. After connecting ManageBac, school courses and teacher details are imported through sync and shown in Courses.")),
            .init(id: "calendar", title: .init(zh: "日历里显示哪些内容？", en: "What appears on the calendar?"), body: .init(zh: "日历预览按日期展示有截止时间或安排时间的任务。切换周或月以查看其他日期；学校时间表则在课程页的时间表入口查看。", en: "The calendar preview shows tasks with due or scheduled dates. Switch weeks or months to inspect other dates; find the school timetable under Courses.")),
            .init(id: "missing-timetable", title: .init(zh: "为什么看不到时间表？", en: "Why is the timetable empty?"), body: .init(zh: "时间表取决于学校是否在 ManageBac 开放相应页面，以及最近一次同步是否成功。先在学校网站确认，再返回 Planora 重新同步。", en: "The timetable depends on whether your school exposes it in ManageBac and whether the latest sync succeeded. Check the school website first, then sync again in Planora."))
        ]),
        HelpCategory(id: "results", title: .init(zh: "成绩与出勤", en: "Grades and attendance"), symbol: "chart.bar.xaxis", articles: [
            .init(id: "grades", title: .init(zh: "成绩何时更新？", en: "When do grades update?"), body: .init(zh: "老师在 ManageBac 发布成绩后，重新同步即可尝试读取。未评分的任务不会因为没有分数而自动变成未完成。课程页可切换数字、柱状图和折线图；Mac 与 iPad 首页还可切换成绩显示。", en: "After a teacher posts a grade in ManageBac, sync again to read it. An ungraded task does not automatically become incomplete. Courses offers number, bar, and line views; Home on Mac and iPad also offers grade display modes.")),
            .init(id: "attendance", title: .init(zh: "出勤率如何计算？", en: "How is attendance calculated?"), body: .init(zh: "已记录课次中，“出席”和“迟到”计入出勤；“缺席”不计入出勤。“未记录”不参与分母。学校时间表的出勤汇总可能比逐节课记录更完整，最终以学校页面为准。", en: "Among recorded lessons, Present and Late count toward attendance; Absent does not. Unrecorded lessons are excluded from the denominator. The school timetable summary can be more complete than individual lesson records; the school page is authoritative.")),
            .init(id: "unrecorded", title: .init(zh: "为什么出勤显示未记录？", en: "Why does attendance say Unrecorded?"), body: .init(zh: "老师可能尚未记录，也可能是同步时无法读到该节课的状态。请在学校时间表的 Details 中核对颜色和汇总，再重新同步。不要仅凭课程卡片颜色推断最终记录。", en: "A teacher may not have recorded it yet, or sync may not have read that lesson's state. Check the color and summary under Details on the school timetable, then sync again. Do not rely on card color alone as the final record."))
        ]),
        HelpCategory(id: "data", title: .init(zh: "数据与更新", en: "Data and updates"), symbol: "externaldrive", articles: [
            .init(id: "backup", title: .init(zh: "怎样备份或恢复任务？", en: "How do I back up or restore tasks?"), body: .init(zh: "在个人页面找到备份与恢复，导出 JSON 文件并妥善保存。导入时先检查预览和重复项处理方式，再确认写入。重新安装或清除应用数据之前请先备份。", en: "In Profile, find Backup and Restore. Export a JSON file and keep it safely. On import, review the preview and duplicate handling before confirming. Back up before reinstalling or clearing app data.")),
            .init(id: "import-recovery", title: .init(zh: "导入了错误的课程怎么办？", en: "How do I remove incorrectly imported courses?"), body: .init(zh: "在同步页、设置或个人页面选择撤销最近一次导入，恢复导入或同步前的完整学习数据。恢复点从 1.7.17 开始记录；之后的学习数据编辑也会被替换。也可清空全部学习数据，包括个人任务及内部恢复备份。两种操作均保留姓名、头像和外观，并断开同步。清空前请导出备份。", en: "Use Undo Latest Import from sync, Settings or Profile to restore all learning data from before the latest import or sync. Recovery points start with 1.7.17 and replace later learning-data edits too. Alternatively, clear all learning data, including personal tasks and internal recovery backups. Both preserve your name, avatar and appearance and disconnect sync. Export a backup before clearing.")),
            .init(id: "local-data", title: .init(zh: "我的资料存在哪里？", en: "Where is my information stored?"), body: .init(zh: "Planora 的任务和个人设置保存在本机应用数据中。ManageBac 的学校记录仍以学校网站为准。卸载应用前请不要假设本地数据会自动恢复到其他设备。", en: "Planora stores tasks and personal settings in local app data. School records in ManageBac remain authoritative on the school website. Do not assume local data will automatically reappear on another device after uninstalling.")),
            .init(id: "updates", title: .init(zh: "如何检查软件更新？", en: "How do I check for updates?"), body: .init(zh: "Mac 版可在设置的“软件更新”中检查。iPhone 和 iPad 不使用 Mac 的应用内更新功能，请通过你安装应用的渠道获取新版。", en: "On Mac, check Software Update in Settings. iPhone and iPad do not use the Mac in-app updater; get new versions from the channel where you installed the app."))
        ]),
        HelpCategory(id: "trouble", title: .init(zh: "故障排查", en: "Troubleshooting"), symbol: "wrench.and.screwdriver", articles: [
            .init(id: "sync-failed", title: .init(zh: "同步失败怎么办？", en: "What if sync fails?"), body: .init(zh: "先确认网络和学校网页能正常打开，再返回 Planora 重试。如果学校要求重新登录，请在连接流程中完成。仍有问题时记录失败页面和提示，不要先删除应用数据库。", en: "Check your network and that the school website opens, then retry in Planora. If the school requires sign-in, complete it in the connection flow. If it still fails, note the page and error; do not delete app data first.")),
            .init(id: "wrong-data", title: .init(zh: "任务、分数或时间不对怎么办？", en: "What if a task, grade, or time looks wrong?"), body: .init(zh: "在 ManageBac 原页面核对同一条记录并重新同步。若仍不一致，反馈时附上 Planora 版本、设备系统版本、相关页面和预期结果；分享截图前请遮挡个人信息。", en: "Compare the same record on the original ManageBac page and sync again. If it still differs, include the Planora version, OS version, relevant page, and expected result in your report. Hide personal details in screenshots.")),
            .init(id: "feedback", title: .init(zh: "怎样反馈问题？", en: "How do I report a problem?"), body: .init(zh: "在下方打开项目的问题反馈页面，说明复现步骤和实际表现。请不要公开学校密码、登录 Cookie、完整成绩单或同学信息。", en: "Open the project's issue tracker below and describe the steps to reproduce and what happened. Do not post school passwords, sign-in cookies, full transcripts, or classmates' details."))
        ])
    ].map { category in
        var category = category
        category.title.ja = JapaneseHelpContent.categories[category.id]
        category.articles = category.articles.map { article in
            var article = article
            article.title.ja = JapaneseHelpContent.articles[article.id]?.0
            article.body.ja = JapaneseHelpContent.articles[article.id]?.1
            return article
        }
        return category
    }

    static func search(_ query: String, locale: Locale, categoryID: String? = nil) -> [HelpCategory] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return categories.filter { categoryID == nil || $0.id == categoryID } }
        return categories.compactMap { category in
            let matches = category.articles.filter { article in
                [article.title.value(for: locale), article.body.value(for: locale), category.title.value(for: locale)]
                    .contains { $0.localizedStandardContains(query) }
            }
            return matches.isEmpty ? nil : HelpCategory(id: category.id, title: category.title, symbol: category.symbol, articles: matches)
        }
    }
}

struct HelpCenterView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var initialCategory: String? = nil
    var standalone = false

    private var categories: [HelpCategory] {
        PlanoraHelpContent.search(query, locale: locale, categoryID: initialCategory)
    }

    var body: some View {
        Group {
            if standalone {
                NavigationStack { content }
            } else {
                content
            }
        }
#if os(macOS)
        .frame(minWidth: 620, minHeight: 580)
#endif
    }

    private var content: some View {
        List {
                if query.isEmpty {
                    Section {
                        Text(HelpCopy(zh: "让计划、课程和学校信息各归其位。选择一个问题，几步就能找到答案。",
                                      en: "Keep plans, courses, and school information in one place. Choose a question for a short answer.",
                                      ja: "予定、科目、学校の情報をひとつに。質問を選ぶと、簡潔な回答を確認できます。").value(for: locale))
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    }
                }
                ForEach(categories) { category in
                    Section {
                        ForEach(category.articles) { article in
                            NavigationLink {
                                HelpArticleView(article: article)
                            } label: {
                                Text(article.title.value(for: locale))
                                    .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Label(category.title.value(for: locale), systemImage: category.symbol)
                    }
                }
                Section {
                    Link(destination: URL(string: "https://github.com/zhangchengzezcz/planora/issues")!) {
                        Label(HelpCopy(zh: "反馈问题", en: "Report an issue", ja: "問題を報告").value(for: locale),
                              systemImage: "arrow.up.right.square")
                    }
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("Planora \(version)").foregroundStyle(.secondary)
                    }
                }
        }
        .navigationTitle(HelpCopy(zh: "帮助中心", en: "Help Center", ja: "ヘルプセンター").value(for: locale))
        .toolbar {
            if standalone {
                ToolbarItem(placement: .cancellationAction) {
                    Button(HelpCopy(zh: "完成", en: "Done", ja: "完了").value(for: locale)) { dismiss() }
                }
            }
        }
        .searchable(text: $query, prompt: HelpCopy(zh: "搜索问题", en: "Search help", ja: "ヘルプを検索").value(for: locale))
        .overlay {
            if categories.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }
}

private struct HelpArticleView: View {
    let article: HelpArticle
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(article.title.value(for: locale))
                    .font(.title2.weight(.semibold))
                Text(article.body.value(for: locale))
                    .font(.body)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                Spacer(minLength: 24)
            }
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(24)
        }
        .navigationTitle(HelpCopy(zh: "帮助", en: "Help", ja: "ヘルプ").value(for: locale))
    }
}
