"use client";

import { useEffect, useRef, useState } from "react";
import { ArrowLeft, BarChart3, Bell, BookOpen, CalendarDays, Check, CheckCircle2, ChevronRight, CircleHelp, Clock3, LineChart, ListOrdered, RefreshCw, Undo2, UserCheck, X } from "lucide-react";
import type { DemoLocale } from "./planora-copy";

export type WorkspacePage = "courses" | "course" | "timetable" | "attendance" | "messages" | "sync" | "help";
type AttendanceStatus = "present" | "late" | "absent" | "unrecorded";
type Course = { name: string; teacher: string; room: string; color: string };
type Lesson = { id: string; course: string; date: string; time: string; status: AttendanceStatus };
type Message = { id: string; title: string; author: string; body: string; read: boolean; date: string };
type Workspace = { courses: Course[]; lessons: Lesson[]; messages: Message[]; syncedAt?: string };
const key = "planora.demo.workspace.v1";

const translations: Record<string, [string, string]> = {
  "课程": ["Courses", "コース"], "时间表": ["Timetable", "時間割"], "出勤": ["Attendance", "出席"],
  "消息": ["Messages", "メッセージ"], "同步": ["Sync", "同期"], "返回": ["Back", "戻る"], "完成": ["Done", "完了"],
  "最近 7 天": ["Last 7 days", "過去7日間"], "出勤率": ["Attendance rate", "出席率"],
  "出席": ["Present", "出席"], "迟到": ["Late", "遅刻"], "缺席": ["Absent", "欠席"], "未记录": ["Unrecorded", "未記録"],
  "成绩": ["Grades", "成績"], "数字": ["Numbers", "数値"], "柱状图": ["Bars", "棒グラフ"], "折线图": ["Line", "折れ線"],
  "课程与时间表": ["Courses & Timetable", "コースと時間割"], "任课教师": ["Teacher", "担当教員"], "教室": ["Room", "教室"],
  "全部科目": ["All subjects", "全科目"], "快速同步": ["Quick sync", "クイック同期"], "完整同步": ["Full sync", "完全同期"],
  "取消": ["Cancel", "キャンセル"], "开始同步": ["Start sync", "同期を開始"], "同步完成": ["Sync complete", "同期完了"],
  "课程与任务": ["Courses & tasks", "コースとタスク"], "撤销最近一次同步": ["Undo latest sync", "直前の同期を取り消す"],
  "清除学习数据": ["Clear learning data", "学習データを消去"], "再次点击确认清除": ["Tap again to clear", "もう一度押して消去"],
  "帮助中心": ["Help Center", "ヘルプセンター"], "搜索帮助": ["Search help", "ヘルプを検索"],
  "尚无记录": ["No records yet", "記録はありません"], "尚未同步": ["Not synced yet", "未同期"],
  "标记全部已读": ["Mark all read", "すべて既読にする"], "没有匹配的结果": ["No matching results", "一致する結果はありません"],
};
export function workspaceText(locale: DemoLocale, text: string) {
  return locale === "zh-Hans" ? text : translations[text]?.[locale === "en" ? 0 : 1] ?? text;
}
function day(offset: number) {
  const date = new Date(); date.setDate(date.getDate() + offset);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}
function seedWorkspace(): Workspace {
  const courses = [
    { name: "Mathematics", teacher: "Teacher A", room: "Room 101", color: "#3978cc" },
    { name: "Physics", teacher: "Teacher B", room: "Lab 2", color: "#178774" },
    { name: "Chinese", teacher: "Teacher C", room: "Room 103", color: "#ad5893" },
    { name: "Global Perspectives", teacher: "Teacher D", room: "Room 104", color: "#b97824" },
  ];
  const lessons: Lesson[] = [];
  for (let offset = -6; offset <= 2; offset++) {
    if ([0, 6].includes(new Date(`${day(offset)}T12:00:00`).getDay())) continue;
    courses.forEach((course, index) => lessons.push({ id: `${day(offset)}-${index}`, course: course.name,
      date: day(offset), time: ["07:30–08:10", "08:20–09:00", "09:30–10:10", "10:25–11:05"][index],
      status: offset > 0 ? "unrecorded" : offset === -2 && index === 1 ? "late" : offset === -3 && index === 2 ? "absent" : "present" }));
  }
  return { courses, lessons, messages: [
    { id: "m1", title: "Exam style question 1-2", author: "Teacher B", body: "Complete the practice questions and show your working. Due Friday at 7:30 AM.", read: false, date: day(0) },
    { id: "m2", title: "术语阅读练习：《退稿信》", author: "Teacher C", body: "请阅读材料，完成课堂讨论笔记并准备下一次课的分享。", read: false, date: day(-1) },
    { id: "m3", title: "Week 5 · Course update", author: "Course team", body: "The timetable has been updated. Check the room and period for your next lesson.", read: true, date: day(-2) },
  ] };
}
function validWorkspace(value: unknown): value is Workspace {
  if (!value || typeof value !== "object") return false;
  const record = value as Workspace;
  const validDate = (date: unknown) => typeof date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(date) && Number.isFinite(new Date(`${date}T12:00:00`).getTime());
  return Array.isArray(record.courses) && record.courses.length <= 200 && record.courses.every(c => c && typeof c.name === "string" && typeof c.teacher === "string" && typeof c.room === "string" && typeof c.color === "string")
    && Array.isArray(record.lessons) && record.lessons.length <= 10000 && record.lessons.every(l => l && validDate(l.date) && typeof l.id === "string" && typeof l.time === "string" && typeof l.course === "string" && ["present", "late", "absent", "unrecorded"].includes(l.status))
    && Array.isArray(record.messages) && record.messages.length <= 1000 && record.messages.every(m => m && typeof m.id === "string" && validDate(m.date) && typeof m.read === "boolean" && typeof m.title === "string" && typeof m.body === "string");
}
export function useDemoWorkspace() {
  const [data, setData] = useState<Workspace>(() => seedWorkspace());
  const [ready, setReady] = useState(false);
  const [previous, setPrevious] = useState<Workspace | null>(null);
  useEffect(() => {
    const frame = requestAnimationFrame(() => {
      try { const saved = JSON.parse(localStorage.getItem(key) ?? "null"); if (validWorkspace(saved)) setData({ ...saved,
        courses: saved.courses.map((course, i) => ({ ...course, teacher: `Teacher ${String.fromCharCode(65 + i % 26)}` })),
        messages: saved.messages.map(message => ({ ...message, author: "Course team" })) }); } catch { /* Keep fresh demo data when storage is invalid. */ }
      setReady(true);
    });
    return () => cancelAnimationFrame(frame);
  }, []);
  useEffect(() => { if (ready) { try { localStorage.setItem(key, JSON.stringify(data)); } catch { /* The current session remains usable without storage. */ } } }, [data, ready]);
  function sync(mode: "quick" | "full", messages: boolean, timetable: boolean) {
    const next = seedWorkspace(); setPrevious(data);
    setData({ courses: next.courses, messages: mode === "quick" || messages ? next.messages : data.messages,
      lessons: mode === "quick" || timetable ? next.lessons : data.lessons, syncedAt: new Date().toISOString() });
  }
  return { data, setData, sync, canUndo: previous !== null,
    undo: () => { if (previous) { setData(previous); setPrevious(null); } },
    clear: () => { setData({ courses: [], lessons: [], messages: [] }); setPrevious(null); },
    reset: () => { setData(seedWorkspace()); setPrevious(null); } };
}
export type DemoWorkspaceController = ReturnType<typeof useDemoWorkspace>;

export function AttendanceSummary({ controller, locale, onOpen }: { controller: DemoWorkspaceController; locale: DemoLocale; onOpen: () => void }) {
  const t = (text: string) => workspaceText(locale, text);
  const lessons = controller.data.lessons.filter(l => l.date >= day(-6) && l.date <= day(0));
  const recorded = lessons.filter(l => l.status !== "unrecorded");
  const present = recorded.filter(l => l.status === "present" || l.status === "late").length;
  return <button className="attendance-summary" onClick={onOpen}>
    <span className="workspace-title"><UserCheck size={21}/><strong>{t("出勤")}</strong><ChevronRight size={18}/></span>
    <span className="attendance-value">{recorded.length ? `${Math.round(present / recorded.length * 100)}%` : "—"}<small>{t("最近 7 天")}</small></span>
    <span className="attendance-meter"><span style={{ width: recorded.length ? `${present / recorded.length * 100}%` : "0%" }}/></span>
    <span className="attendance-counts">{(["present", "late", "absent", "unrecorded"] as AttendanceStatus[]).map((status, i) => <span key={status} className={`attendance-${status}`}>{t(["出席", "迟到", "缺席", "未记录"][i])} {lessons.filter(l => l.status === status).length}</span>)}</span>
  </button>;
}

function GradePanel({ courses, course, locale }: { courses: Course[]; course?: string; locale: DemoLocale }) {
  const [mode, setMode] = useState(0);
  const [filter, setFilter] = useState(course ?? "all");
  const t = (text: string) => workspaceText(locale, text);
  const grades = Array.from({ length: 12 }, (_, i) => ({ subject: courses[i % Math.max(1, courses.length)]?.name ?? "", score: [82, 91, 88, 76, 89, 94, 92, 84, 87, 96, 90, 86][i], date: day(i * 2 - 24), id: i })).filter(g => g.subject && (filter === "all" || g.subject === filter));
  const icons = [ListOrdered, BarChart3, LineChart];
  const ref = useRef<HTMLDivElement>(null);
  function selectAt(clientX: number) { const bounds = ref.current!.getBoundingClientRect(); setMode(Math.max(0, Math.min(2, Math.floor((clientX - bounds.left) / (bounds.width / 3))))); }
  return <section className="workspace-section">
    <div className="workspace-title"><h3>{t("成绩")}</h3><div ref={ref} className="glass-segments" role="group" aria-label={t("成绩")}
      onPointerDown={e => { e.currentTarget.setPointerCapture(e.pointerId); selectAt(e.clientX); }} onPointerMove={e => { if (e.buttons === 1) selectAt(e.clientX); }}>
      <span className="segment-thumb" style={{ transform: `translateX(${mode * 100}%)` }}/>
      {icons.map((Icon, i) => <button key={i} aria-label={t(["数字", "柱状图", "折线图"][i])} aria-pressed={mode === i} title={t(["数字", "柱状图", "折线图"][i])} onClick={() => setMode(i)}><Icon size={19}/></button>)}
    </div></div>
    {!course && <select className="workspace-select" aria-label={t("全部科目")} value={filter} onChange={e => setFilter(e.target.value)}><option value="all">{t("全部科目")}</option>{courses.map(c => <option key={c.name}>{c.name}</option>)}</select>}
    {mode === 0 ? <div className="grade-records">{grades.slice().reverse().map(g => <div key={g.id}><span><strong>{g.subject}</strong><small>{g.date} · Assessment {g.id + 1}</small></span><b style={{ color: courses.find(c => c.name === g.subject)?.color }}>{g.score}<small>/100</small></b></div>)}</div>
      : <div className="grade-chart-scroll" tabIndex={0} aria-label={t(mode === 1 ? "柱状图" : "折线图")}><div className="grade-chart" style={{ minWidth: Math.max(300, grades.length * 72) }}>
        {mode === 2 && <svg viewBox={`0 0 ${Math.max(300, grades.length * 72)} 170`} preserveAspectRatio="none" className="grade-line" aria-hidden="true"><polyline fill="none" stroke="var(--accent)" strokeWidth="2.5" points={grades.map((g, i) => `${i * 72 + 36},${165 - g.score * 1.5}`).join(" ")}/></svg>}
        {grades.map(g => <div className="grade-column" key={g.id}><span className={mode === 2 ? "grade-dot" : "grade-bar"} style={{ height: mode === 1 ? `${g.score * 1.5}px` : undefined, bottom: mode === 2 ? `${g.score * 1.5}px` : undefined, background: courses.find(c => c.name === g.subject)?.color }}><b>{g.score}</b></span><small>{g.subject}</small><time>{g.date.slice(5)}</time></div>)}
      </div></div>}
    {!grades.length && <p className="workspace-muted">{t("尚无记录")}</p>}
  </section>;
}

const helpArticles = [
  ["任务与计划", "Tasks & planning", "タスクと計画", "点击加号创建任务。在详情中编辑截止日期、计划日期、进度及优先级。今天和本周依据日期归类。", "Create tasks with +. Edit deadlines, planned dates, progress and priority in task details. Today and This Week group tasks by date.", "＋でタスクを作成します。詳細で期限・予定日・進捗・優先度を編集できます。"],
  ["快速与完整同步", "Quick and full sync", "同期の種類", "快速同步读取任务、消息和当周课表。完整同步还补全课程内容，可选择是否读取消息与课表。网页使用示例数据，不需要学校账号。", "Quick sync reads tasks, messages and the current timetable. Full sync also reads course content with optional message/timetable modules. This demo uses sample data, not a school account.", "クイック同期はタスク・メッセージ・今週の時間割を更新します。ウェブ版はサンプルデータのみです。"],
  ["为什么显示未记录？", "Why is attendance unrecorded?", "未記録の理由", "学校尚未录入或对应课次未同步时显示未记录。最近七天统计排除未来课次与未记录；迟到计入出勤，班会与课程统计不能混用。", "Unrecorded means the school has not recorded attendance or a lesson has not synced. Last-seven-day totals exclude future and unrecorded lessons; late arrivals count as attendance. Homeroom and class totals differ.", "未入力・未同期の授業は未記録です。将来の授業と未記録は集計対象外、遅刻は出席に含みます。"],
  ["撤销与清除数据", "Undo and reset", "取り消しと消去", "撤销最近一次同步恢复同步前的学习数据。清除学习数据会删除课程、任务和消息，但保留个人名称与外观。请先导出任务备份。", "Undo latest sync restores the previous learning data. Clearing learning data removes courses, tasks and messages but keeps your name and appearance. Export a task backup first.", "直前の同期を取り消すと元のデータに戻ります。学習データを消去しても名前と外観は残ります。"],
  ["隐私与备份", "Privacy and backups", "プライバシーとバックアップ", "网页数据只保存在当前浏览器。可导出及导入本演示的任务 JSON；它不是原生 App 的完整备份。清除浏览器存储后演示数据会重置。", "Demo data stays in this browser. Export/import the demo task JSON; it is not a full native-app backup. Clearing browser storage resets the demo.", "データはブラウザ内に保存されます。ウェブ版のJSONはアプリの完全なバックアップではありません。"],
  ["成绩与课程", "Grades and courses", "成績とコース", "课程详情提供数字、柱状图和折线图，图表按时间排序并支持横向浏览。iPhone 首页不显示成绩切换。任务详情中的课程入口可直接跳转。", "Course details offer numbers, bars and lines ordered by date, with horizontal scrolling. iPhone Home has no grade-mode switch. Open the course directly from task details.", "コースの成績は数値・棒・折れ線で表示できます。タスクからコースへ移動できます。"],
];

export function WorkspaceScreen({ page, course, locale, controller, onBack, onNavigate, onSyncTasks, onUndoTasks, onClearTasks }: {
  page: WorkspacePage; course?: string; locale: DemoLocale; controller: DemoWorkspaceController;
  onBack: () => void; onNavigate: (page: WorkspacePage, course?: string) => void;
  onSyncTasks: () => void; onUndoTasks: () => void; onClearTasks: () => void;
}) {
  const t = (text: string) => workspaceText(locale, text);
  const [mode, setMode] = useState<"quick" | "full">("quick");
  const [messages, setMessages] = useState(true); const [timetable, setTimetable] = useState(true);
  const [phase, setPhase] = useState(-1); const [done, setDone] = useState(false); const [confirmClear, setConfirmClear] = useState(false);
  const [query, setQuery] = useState(""); const [selectedDate, setSelectedDate] = useState(day(0));
  const [openedMessage, setOpenedMessage] = useState<string | null>(null);
  const data = controller.data;
  const modules = ["课程与任务", ...(mode === "quick" || messages ? ["消息"] : []), ...(mode === "quick" || timetable ? ["时间表", "出勤"] : [])];
  useEffect(() => {
    if (phase < 0) return;
    const timer = window.setTimeout(() => {
      if (phase + 1 >= modules.length) { controller.sync(mode, messages, timetable); onSyncTasks(); setDone(true); setPhase(-1); }
      else setPhase(phase + 1);
    }, 450);
    return () => clearTimeout(timer);
  }, [phase, modules.length, mode, messages, timetable, controller, onSyncTasks]);
  const title = page === "course" ? course ?? t("课程") : t(({ courses: "课程", timetable: "时间表", attendance: "出勤", messages: "消息", sync: "同步", help: "帮助中心" } as Record<string, string>)[page]);
  const dateLabel = (value: string) => new Intl.DateTimeFormat(locale === "zh-Hans" ? "zh-CN" : locale, { month: "short", day: "numeric", weekday: "short" }).format(new Date(`${value}T12:00:00`));
  return <div className="screen scroll-screen workspace-screen">
    <header className="workspace-header"><button className="icon-button" onClick={onBack} aria-label={t("返回")}><ArrowLeft/></button><h2>{title}</h2>
      {page === "sync" ? <button className="glass-action" onClick={onBack}>{t(done ? "完成" : "取消")}</button> : <button className="icon-button" onClick={() => onNavigate("sync")} aria-label={t("同步")}><RefreshCw/></button>}</header>
    {page === "courses" && <>
      <div className="workspace-links"><button onClick={() => onNavigate("timetable")}><CalendarDays/>{t("时间表")}<ChevronRight/></button><button onClick={() => onNavigate("attendance")}><UserCheck/>{t("出勤")}<ChevronRight/></button></div>
      {data.courses.map(c => <button className="course-row" key={c.name} onClick={() => onNavigate("course", c.name)}><span className="course-symbol" style={{ color: c.color }}><BookOpen/></span><span><strong>{c.name}</strong><small>{c.teacher}</small></span><ChevronRight/></button>)}
      {!data.courses.length && <p>{t("尚无记录")}</p>}
    </>}
    {page === "course" && <>
      <section className="workspace-section"><h3>{t("任课教师")}</h3><p>{data.courses.find(c => c.name === course)?.teacher ?? "—"}</p><p className="workspace-muted">{t("教室")} {data.courses.find(c => c.name === course)?.room ?? "—"}</p></section>
      <GradePanel courses={data.courses} course={course} locale={locale}/>
      <section className="workspace-section"><h3>ManageBac</h3><p>{course}</p><p className="workspace-muted">{locale === "zh-Hans" ? "只读课程 · 示例数据" : locale === "en" ? "Read-only course · Sample data" : "読み取り専用・サンプルデータ"}</p></section>
    </>}
    {page === "attendance" && <><AttendanceSummary controller={controller} locale={locale} onOpen={() => onNavigate("timetable")}/>
      <section className="workspace-section">{data.lessons.filter(l => l.date >= day(-6) && l.date <= day(0)).slice().reverse().map(l => <div className="lesson-row" key={l.id}><span><strong>{l.course}</strong><small>{dateLabel(l.date)} · {l.time}</small></span><span className={`attendance-${l.status}`}>{t({ present: "出席", late: "迟到", absent: "缺席", unrecorded: "未记录" }[l.status])}</span></div>)}</section></>}
    {page === "timetable" && <><div className="date-strip">{Array.from({ length: 9 }, (_, i) => day(i - 6)).map(date => <button key={date} aria-pressed={date === selectedDate} onClick={() => setSelectedDate(date)}>{dateLabel(date)}</button>)}</div>
      {data.lessons.filter(l => l.date === selectedDate).map(l => <button className={`lesson-card attendance-${l.status}`} key={l.id} onClick={() => onNavigate("course", l.course)}><span><Clock3 size={15}/>{l.time}</span><strong>{l.course}</strong><small>{data.courses.find(c => c.name === l.course)?.teacher} · {data.courses.find(c => c.name === l.course)?.room}</small><span>{t({ present: "出席", late: "迟到", absent: "缺席", unrecorded: "未记录" }[l.status])}</span></button>)}
      {!data.lessons.some(l => l.date === selectedDate) && <p className="workspace-muted">{t("尚无记录")}</p>}</>}
    {page === "messages" && <><button className="glass-action" onClick={() => controller.setData({ ...data, messages: data.messages.map(m => ({ ...m, read: true })) })}>{t("标记全部已读")}</button>
      {data.messages.map(m => <button className={`message-row ${!m.read ? "unread" : ""}`} key={m.id} onClick={() => { setOpenedMessage(openedMessage === m.id ? null : m.id); controller.setData({ ...data, messages: data.messages.map(item => item.id === m.id ? { ...item, read: true } : item) }); }}><Bell size={18}/><span><strong>{m.title}</strong><small>{m.author} · {dateLabel(m.date)}</small><p className={openedMessage === m.id ? "" : "message-preview"}>{m.body}</p></span></button>)}</>}
    {page === "sync" && <>
      <p className="workspace-muted">{locale === "zh-Hans" ? "演示同步 · 不连接真实学校账号" : locale === "en" ? "Demo sync · No school account connection" : "デモ同期・学校アカウントには接続しません"}</p>
      <div className="glass-segments text-segments">{(["quick", "full"] as const).map(value => <button disabled={phase >= 0} key={value} aria-pressed={mode === value} onClick={() => setMode(value)}>{t(value === "quick" ? "快速同步" : "完整同步")}</button>)}</div>
      {mode === "full" && <section className="workspace-section">{[["消息", messages, setMessages], ["时间表", timetable, setTimetable]].map(([label, checked, setter]) => <label className="workspace-toggle" key={label as string}><span>{t(label as string)}</span><input type="checkbox" role="switch" disabled={phase >= 0} checked={checked as boolean} onChange={e => (setter as (value: boolean) => void)(e.target.checked)}/></label>)}</section>}
      <section className="sync-modules" aria-live="polite">{modules.map((module, i) => <div key={module}><span>{t(module)}</span>{done || phase > i ? <CheckCircle2 className="attendance-present"/> : phase === i ? <RefreshCw className="sync-spinning"/> : <span className="sync-pending"/>}</div>)}</section>
      {done ? <p className="sync-success"><Check/>{t("同步完成")}</p> : <button className="glass-action full-action" disabled={phase >= 0} onClick={() => { setDone(false); setPhase(0); }}>{t("开始同步")}</button>}
      <button className="glass-action full-action" disabled={!controller.canUndo || phase >= 0} onClick={() => { controller.undo(); onUndoTasks(); setDone(false); }}><Undo2 size={18}/>{t("撤销最近一次同步")}</button>
      <button className="glass-action full-action destructive" disabled={phase >= 0} onClick={() => { if (!confirmClear) setConfirmClear(true); else { controller.clear(); onClearTasks(); setConfirmClear(false); setDone(false); } }}><X size={18}/>{t(confirmClear ? "再次点击确认清除" : "清除学习数据")}</button>
    </>}
    {page === "help" && <><label className="workspace-search"><CircleHelp size={18}/><input aria-label={t("搜索帮助")} placeholder={t("搜索帮助")} value={query} onChange={e => setQuery(e.target.value)}/></label>
      {helpArticles.filter(a => a.join(" ").toLowerCase().includes(query.toLowerCase())).map(a => <details className="help-article" key={a[0]}><summary>{a[locale === "zh-Hans" ? 0 : locale === "en" ? 1 : 2]}</summary><p>{a[locale === "zh-Hans" ? 3 : locale === "en" ? 4 : 5]}</p></details>)}
      {!helpArticles.some(a => a.join(" ").toLowerCase().includes(query.toLowerCase())) && <p>{t("没有匹配的结果")}</p>}</>}
  </div>;
}
