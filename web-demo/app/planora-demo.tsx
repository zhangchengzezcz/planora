"use client";

import {
  Archive,
  Bell,
  BookOpen,
  CalendarDays,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronLeft,
  Circle,
  Clock3,
  FileText,
  FlaskConical,
  Gauge,
  GraduationCap,
  HeartHandshake,
  Home,
  LayoutGrid,
  Lightbulb,
  ListChecks,
  Menu,
  Moon,
  Palette,
  Plus,
  RotateCcw,
  Search,
  Settings2,
  Sparkles,
  Sun,
  TestTube2,
  UserRound,
  X,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

type Tab = "home" | "tasks" | "search" | "profile";
type TaskType =
  | "assignment"
  | "practical"
  | "revision"
  | "ia"
  | "ee"
  | "tok"
  | "cas"
  | "exam"
  | "event"
  | "custom";
type Priority = "low" | "medium" | "high";
type Theme = "classic" | "ocean" | "forest" | "sunset";
type Density = "comfortable" | "compact";
type SortOrder = "smart" | "deadline" | "priority" | "title";
type Screen =
  | { kind: "tab" }
  | { kind: "task"; taskId: string }
  | { kind: "today" }
  | { kind: "week" }
  | { kind: "create" }
  | { kind: "settings"; section: "appearance" | "display" };

interface PlanoraItem {
  id: string;
  title: string;
  subject: string;
  type: TaskType;
  priority: Priority;
  deadline?: string;
  plannedDate?: string;
  progressKind: "percentage" | "stage";
  progress: number;
  stage: string;
  notes: string;
  completed: boolean;
  recurring: boolean;
}

interface DemoSettings {
  theme: Theme;
  dark: boolean;
  density: Density;
  sortOrder: SortOrder;
  showCompleted: boolean;
  showPercentage: boolean;
  showNotes: boolean;
}

const STORAGE_TASKS = "planora.demo.tasks.v2";
const STORAGE_SETTINGS = "planora.demo.settings.v2";
const dayMs = 86_400_000;

const taskMeta: Record<
  TaskType,
  { title: string; icon: LucideIcon; color: string; defaultStage: string }
> = {
  assignment: {
    title: "作业",
    icon: FileText,
    color: "blue",
    defaultStage: "进行中",
  },
  practical: {
    title: "实践",
    icon: TestTube2,
    color: "green",
    defaultStage: "准备",
  },
  revision: {
    title: "复习",
    icon: BookOpen,
    color: "amber",
    defaultStage: "第一轮",
  },
  ia: {
    title: "IA",
    icon: FlaskConical,
    color: "blue",
    defaultStage: "研究问题",
  },
  ee: {
    title: "EE",
    icon: BookOpen,
    color: "green",
    defaultStage: "研究",
  },
  tok: {
    title: "TOK",
    icon: Lightbulb,
    color: "amber",
    defaultStage: "提纲",
  },
  cas: {
    title: "CAS",
    icon: HeartHandshake,
    color: "pink",
    defaultStage: "反思",
  },
  exam: {
    title: "考试",
    icon: GraduationCap,
    color: "purple",
    defaultStage: "复习中",
  },
  event: {
    title: "活动",
    icon: CalendarDays,
    color: "teal",
    defaultStage: "待参加",
  },
  custom: {
    title: "自定义",
    icon: LayoutGrid,
    color: "ink",
    defaultStage: "进行中",
  },
};

const priorities: Record<Priority, { title: string; weight: number }> = {
  low: { title: "低", weight: 0 },
  medium: { title: "中", weight: 1 },
  high: { title: "高", weight: 2 },
};

const defaultSettings: DemoSettings = {
  theme: "classic",
  dark: false,
  density: "comfortable",
  sortOrder: "smart",
  showCompleted: true,
  showPercentage: true,
  showNotes: true,
};

function localISO(date: Date) {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

function offsetISO(offset: number) {
  return localISO(new Date(Date.now() + offset * dayMs));
}

function seedTasks(): PlanoraItem[] {
  return [
    {
      id: "physics-ia",
      title: "Physics IA",
      subject: "Physics HL",
      type: "ia",
      priority: "high",
      deadline: offsetISO(3),
      plannedDate: offsetISO(0),
      progressKind: "percentage",
      progress: 64,
      stage: "Data Collection",
      notes: "整理实验数据，补做异常值并开始绘制图表。",
      completed: false,
      recurring: false,
    },
    {
      id: "math-assignment",
      title: "Calculus Problem Set",
      subject: "Mathematics AA HL",
      type: "assignment",
      priority: "high",
      deadline: offsetISO(1),
      plannedDate: offsetISO(0),
      progressKind: "percentage",
      progress: 35,
      stage: "进行中",
      notes: "完成第 7 章导数应用题。",
      completed: false,
      recurring: false,
    },
    {
      id: "tok-exhibition",
      title: "TOK Exhibition",
      subject: "TOK",
      type: "tok",
      priority: "medium",
      deadline: offsetISO(10),
      plannedDate: offsetISO(3),
      progressKind: "stage",
      progress: 42,
      stage: "Outline ready",
      notes: "确认三个物件与 prompt 的联系。",
      completed: false,
      recurring: false,
    },
    {
      id: "english-reading",
      title: "Weekly English Reading",
      subject: "English B HL",
      type: "assignment",
      priority: "medium",
      deadline: offsetISO(5),
      plannedDate: offsetISO(2),
      progressKind: "percentage",
      progress: 20,
      stage: "阅读中",
      notes: "阅读两篇文章并记录新词。",
      completed: false,
      recurring: true,
    },
    {
      id: "cas-reflection",
      title: "CAS Reflection",
      subject: "CAS",
      type: "cas",
      priority: "low",
      plannedDate: offsetISO(0),
      progressKind: "stage",
      progress: 100,
      stage: "已完成",
      notes: "完成摄影活动反思。",
      completed: true,
      recurring: false,
    },
  ];
}

function formatDay(value?: string, long = false) {
  if (!value) return "无截止日期";
  const date = new Date(`${value}T12:00:00`);
  return new Intl.DateTimeFormat("zh-CN", {
    month: long ? "long" : "short",
    day: "numeric",
    weekday: long ? "short" : undefined,
  }).format(date);
}

function daysUntil(value?: string) {
  if (!value) return null;
  const start = new Date(`${localISO(new Date())}T12:00:00`);
  const end = new Date(`${value}T12:00:00`);
  return Math.round((end.getTime() - start.getTime()) / dayMs);
}

function deadlineLabel(value?: string) {
  const days = daysUntil(value);
  if (days === null) return "无截止日期";
  if (days < 0) return `已逾期 ${Math.abs(days)} 天`;
  if (days === 0) return "今天截止";
  if (days === 1) return "明天截止";
  return `还有 ${days} 天`;
}

function sortTasks(items: PlanoraItem[], sortOrder: SortOrder) {
  return [...items].sort((a, b) => {
    if (sortOrder === "title") return a.title.localeCompare(b.title);
    if (sortOrder === "priority")
      return priorities[b.priority].weight - priorities[a.priority].weight;
    if (sortOrder === "deadline")
      return (a.deadline ?? "9999").localeCompare(b.deadline ?? "9999");

    if (a.completed !== b.completed) return Number(a.completed) - Number(b.completed);
    const priority =
      priorities[b.priority].weight - priorities[a.priority].weight;
    if (priority !== 0) return priority;
    return (a.deadline ?? "9999").localeCompare(b.deadline ?? "9999");
  });
}

export function PlanoraDemo() {
  const [tasks, setTasks] = useState<PlanoraItem[]>(seedTasks);
  const [settings, setSettings] = useState<DemoSettings>(defaultSettings);
  const [tab, setTab] = useState<Tab>("home");
  const [screen, setScreen] = useState<Screen>({ kind: "tab" });
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      try {
        const savedTasks = window.localStorage.getItem(STORAGE_TASKS);
        const savedSettings = window.localStorage.getItem(STORAGE_SETTINGS);
        if (savedTasks) setTasks(JSON.parse(savedTasks) as PlanoraItem[]);
        if (savedSettings)
          setSettings({
            ...defaultSettings,
            ...(JSON.parse(savedSettings) as Partial<DemoSettings>),
          });
      } catch {
        window.localStorage.removeItem(STORAGE_TASKS);
        window.localStorage.removeItem(STORAGE_SETTINGS);
      } finally {
        setHydrated(true);
      }
    });

    return () => window.cancelAnimationFrame(frame);
  }, []);

  useEffect(() => {
    if (hydrated)
      window.localStorage.setItem(STORAGE_TASKS, JSON.stringify(tasks));
  }, [tasks, hydrated]);

  useEffect(() => {
    if (hydrated)
      window.localStorage.setItem(STORAGE_SETTINGS, JSON.stringify(settings));
  }, [settings, hydrated]);

  function updateTask(updated: PlanoraItem) {
    setTasks((current) =>
      current.map((task) => (task.id === updated.id ? updated : task)),
    );
  }

  function chooseTab(next: Tab) {
    setTab(next);
    setScreen({ kind: "tab" });
  }

  function resetDemo() {
    const nextTasks = seedTasks();
    setTasks(nextTasks);
    setSettings(defaultSettings);
    setTab("home");
    setScreen({ kind: "tab" });
  }

  const activeTask =
    screen.kind === "task"
      ? tasks.find((task) => task.id === screen.taskId)
      : undefined;

  return (
    <main
      className={`showcase theme-${settings.theme} ${
        settings.dark ? "is-dark" : ""
      }`}
    >
      <aside className="showcase-context">
        <div className="showcase-brand">
          <LogoMark />
          <div>
            <strong>Planora</strong>
            <span>Interactive Preview</span>
          </div>
        </div>
        <div className="showcase-copy">
          <p className="eyebrow">IB · IGCSE 学习规划</p>
          <h1>把 Deadline 变成清晰的行动。</h1>
          <p>
            这是基于真实 SwiftUI 项目制作的浏览器演示。任务与外观设置只保存在当前浏览器。
          </p>
        </div>
        <div className="showcase-status">
          <span>
            <span className="status-dot" />
            交互数据已启用
          </span>
          <button type="button" onClick={resetDemo}>
            <RotateCcw size={16} />
            重置演示
          </button>
        </div>
      </aside>

      <section className="device-stage" aria-label="Planora App 交互式演示">
        <div className="device">
          <div className="device-speaker" aria-hidden="true" />
          <div className="device-screen">
            <StatusBar dark={settings.dark} />
            <div className="app-content">
              {screen.kind === "tab" && tab === "home" && (
                <HomeScreen
                  tasks={tasks}
                  settings={settings}
                  onOpenTask={(taskId) => setScreen({ kind: "task", taskId })}
                  onOpenToday={() => setScreen({ kind: "today" })}
                  onOpenWeek={() => setScreen({ kind: "week" })}
                  onCreate={() => setScreen({ kind: "create" })}
                />
              )}
              {screen.kind === "tab" && tab === "tasks" && (
                <TasksScreen
                  tasks={tasks}
                  settings={settings}
                  onOpenTask={(taskId) => setScreen({ kind: "task", taskId })}
                  onToggle={(task) =>
                    updateTask({ ...task, completed: !task.completed })
                  }
                />
              )}
              {screen.kind === "tab" && tab === "search" && (
                <SearchScreen
                  tasks={tasks}
                  onOpenTask={(taskId) => setScreen({ kind: "task", taskId })}
                />
              )}
              {screen.kind === "tab" && tab === "profile" && (
                <ProfileScreen
                  tasks={tasks}
                  settings={settings}
                  onOpenSettings={(section) =>
                    setScreen({ kind: "settings", section })
                  }
                  onReset={resetDemo}
                />
              )}
              {screen.kind === "task" && activeTask && (
                <TaskDetailScreen
                  task={activeTask}
                  onBack={() => setScreen({ kind: "tab" })}
                  onChange={updateTask}
                />
              )}
              {screen.kind === "today" && (
                <TodayScreen
                  tasks={tasks}
                  onBack={() => setScreen({ kind: "tab" })}
                  onOpenTask={(taskId) => setScreen({ kind: "task", taskId })}
                />
              )}
              {screen.kind === "week" && (
                <WeekScreen
                  tasks={tasks}
                  onBack={() => setScreen({ kind: "tab" })}
                  onOpenTask={(taskId) => setScreen({ kind: "task", taskId })}
                />
              )}
              {screen.kind === "settings" && (
                <SettingsScreen
                  section={screen.section}
                  settings={settings}
                  onChange={setSettings}
                  onBack={() => setScreen({ kind: "tab" })}
                />
              )}
              {screen.kind === "create" && (
                <CreateScreen
                  onClose={() => setScreen({ kind: "tab" })}
                  onSave={(task) => {
                    setTasks((current) => [task, ...current]);
                    setTab("home");
                    setScreen({ kind: "tab" });
                  }}
                />
              )}
            </div>

            {screen.kind !== "create" && (
              <TabBar
                active={tab}
                onSelect={chooseTab}
                onCreate={() => setScreen({ kind: "create" })}
              />
            )}
          </div>
        </div>
      </section>
    </main>
  );
}

function LogoMark({ small = false }: { small?: boolean }) {
  return (
    <div className={`logo-mark ${small ? "small" : ""}`} aria-label="Planora">
      <Sparkles className="logo-spark" />
      <span>P</span>
    </div>
  );
}

function StatusBar({ dark }: { dark: boolean }) {
  return (
    <div className="status-bar" aria-hidden="true">
      <span>9:41</span>
      <div className="dynamic-island" />
      <div className="status-icons">
        <span className="signal">▮▮▮</span>
        <span>⌁</span>
        <span className="battery">{dark ? "87" : "82"}</span>
      </div>
    </div>
  );
}

function ScreenHeader({
  title,
  subtitle,
  onBack,
}: {
  title: string;
  subtitle?: string;
  onBack?: () => void;
}) {
  return (
    <header className={`screen-header ${onBack ? "with-back" : ""}`}>
      {onBack && (
        <button className="icon-button back-button" type="button" onClick={onBack}>
          <ChevronLeft />
          <span className="sr-only">返回</span>
        </button>
      )}
      <div>
        <h2>{title}</h2>
        {subtitle && <p>{subtitle}</p>}
      </div>
    </header>
  );
}

function HomeScreen({
  tasks,
  settings,
  onOpenTask,
  onOpenToday,
  onOpenWeek,
  onCreate,
}: {
  tasks: PlanoraItem[];
  settings: DemoSettings;
  onOpenTask: (taskId: string) => void;
  onOpenToday: () => void;
  onOpenWeek: () => void;
  onCreate: () => void;
}) {
  const openTasks = sortTasks(
    tasks.filter((task) => !task.completed),
    "smart",
  );
  const focus = openTasks[0];
  const completed = tasks.filter((task) => task.completed).length;
  const subjectProgress = Object.entries(
    tasks.reduce<Record<string, number[]>>((groups, task) => {
      groups[task.subject] ??= [];
      groups[task.subject].push(task.completed ? 100 : task.progress);
      return groups;
    }, {}),
  )
    .slice(0, 3)
    .map(([subject, values]) => ({
      subject,
      value: Math.round(values.reduce((sum, value) => sum + value, 0) / values.length),
    }));

  return (
    <div className="screen scroll-screen">
      <div className="home-header">
        <div>
          <p className="eyebrow">今天 · {formatDay(localISO(new Date()), true)}</p>
          <h2>你好，Mitty</h2>
          <p>现在最需要关注什么？</p>
        </div>
        <button className="curriculum-badge" type="button">
          IB <ChevronDown size={15} />
        </button>
      </div>

      <div className="planning-strip">
        <PlanningButton
          title="今日"
          subtitle="安排今日执行"
          icon={Sun}
          color="amber"
          onClick={onOpenToday}
        />
        <PlanningButton
          title="本周"
          subtitle="查看七天负载"
          icon={CalendarDays}
          color="blue"
          onClick={onOpenWeek}
        />
      </div>

      {!focus ? (
        <section className="empty-panel">
          <ListChecks />
          <h3>还没有任务</h3>
          <p>点击加号创建第一个学习任务。</p>
          <button className="primary-button" type="button" onClick={onCreate}>
            <Plus size={18} />
            新建任务
          </button>
        </section>
      ) : (
        <>
          <section
            className="focus-panel"
            onClick={() => onOpenTask(focus.id)}
            role="button"
            tabIndex={0}
            onKeyDown={(event) => {
              if (event.key === "Enter") onOpenTask(focus.id);
            }}
          >
            <div className="focus-topline">
              <span className="eyebrow">CURRENT FOCUS</span>
              <PriorityBadge priority={focus.priority} />
            </div>
            <h3>{focus.title}</h3>
            <p>
              {focus.subject} · {deadlineLabel(focus.deadline)}
            </p>
            <ProgressBar value={focus.progress} color={taskMeta[focus.type].color} />
            <div className="focus-footer">
              <span>
                {focus.progressKind === "stage" ? focus.stage : `${focus.progress}%`}
              </span>
              <span>完成下一个阶段目标</span>
            </div>
          </section>

          <SectionTitle title="即将到来" value={`${openTasks.length} 项`} />
          <div className="stack-list">
            {openTasks.slice(1, 4).map((task) => (
              <TaskRow
                key={task.id}
                task={task}
                density={settings.density}
                showPercentage={settings.showPercentage}
                showNotes={false}
                onOpen={() => onOpenTask(task.id)}
              />
            ))}
          </div>

          <SectionTitle title="学习进度" value={`${completed} / ${tasks.length}`} />
          <section className="plain-section progress-section">
            {subjectProgress.map((subject, index) => (
              <div className="subject-progress" key={subject.subject}>
                <div>
                  <span>{subject.subject}</span>
                  <strong>{subject.value}%</strong>
                </div>
                <ProgressBar
                  value={subject.value}
                  color={["blue", "green", "amber"][index % 3]}
                />
              </div>
            ))}
            <div className="insight-grid">
              <Insight value={`${completed}`} label="本周完成" />
              <Insight value={openTasks[0]?.subject ?? "暂无"} label="当前重点" />
              <Insight
                value={`${openTasks.filter((task) => (daysUntil(task.deadline) ?? 99) <= 7).length}`}
                label="未来七天"
              />
            </div>
          </section>

          <SectionTitle title="日历预览" value="本周" />
          <MiniCalendar tasks={tasks} onOpenTask={onOpenTask} />
        </>
      )}
    </div>
  );
}

function PlanningButton({
  title,
  subtitle,
  icon: Icon,
  color,
  onClick,
}: {
  title: string;
  subtitle: string;
  icon: LucideIcon;
  color: string;
  onClick: () => void;
}) {
  return (
    <button className={`planning-button tone-${color}`} type="button" onClick={onClick}>
      <Icon />
      <strong>{title}</strong>
      <span>{subtitle}</span>
    </button>
  );
}

function TasksScreen({
  tasks,
  settings,
  onOpenTask,
  onToggle,
}: {
  tasks: PlanoraItem[];
  settings: DemoSettings;
  onOpenTask: (taskId: string) => void;
  onToggle: (task: PlanoraItem) => void;
}) {
  const visible = sortTasks(
    tasks.filter((task) => settings.showCompleted || !task.completed),
    settings.sortOrder,
  );

  return (
    <div className="screen scroll-screen">
      <ScreenHeader title="任务" subtitle="根据设置显示和排序任务。" />
      <div className={`task-list density-${settings.density}`}>
        {visible.map((task) => (
          <TaskRow
            key={task.id}
            task={task}
            density={settings.density}
            showPercentage={settings.showPercentage}
            showNotes={settings.showNotes}
            onOpen={() => onOpenTask(task.id)}
            onToggle={() => onToggle(task)}
          />
        ))}
      </div>
    </div>
  );
}

function TaskRow({
  task,
  density,
  showPercentage,
  showNotes,
  onOpen,
  onToggle,
}: {
  task: PlanoraItem;
  density: Density;
  showPercentage: boolean;
  showNotes: boolean;
  onOpen: () => void;
  onToggle?: () => void;
}) {
  const meta = taskMeta[task.type];
  const Icon = meta.icon;
  return (
    <article
      className={`task-row ${task.completed ? "is-complete" : ""} ${density}`}
      onClick={onOpen}
    >
      <div className={`task-icon tone-${meta.color}`}>
        <Icon />
      </div>
      <div className="task-copy">
        <div className="task-title-line">
          <h3>{task.title}</h3>
          <span className={`type-pill tone-${meta.color}`}>{meta.title}</span>
        </div>
        <p>{task.subject}</p>
        <div className="task-metrics">
          <span>
            <CalendarDays />
            {formatDay(task.deadline)}
          </span>
          <span>
            {task.progressKind === "percentage" && showPercentage
              ? `${task.progress}%`
              : task.stage}
          </span>
        </div>
        {showNotes && density === "comfortable" && task.notes && (
          <p className="task-note">{task.notes}</p>
        )}
      </div>
      <div className="task-side">
        <PriorityBadge priority={task.priority} compact />
        {onToggle && (
          <button
            className="complete-button"
            type="button"
            onClick={(event) => {
              event.stopPropagation();
              onToggle();
            }}
            aria-label={task.completed ? "重新打开任务" : "完成任务"}
          >
            {task.completed ? <CheckCircle2 /> : <Circle />}
          </button>
        )}
      </div>
    </article>
  );
}

function SearchScreen({
  tasks,
  onOpenTask,
}: {
  tasks: PlanoraItem[];
  onOpenTask: (taskId: string) => void;
}) {
  const [query, setQuery] = useState("");
  const [subject, setSubject] = useState("all");
  const [type, setType] = useState("all");
  const [status, setStatus] = useState("all");
  const inputRef = useRef<HTMLInputElement>(null);
  const subjects = [...new Set(tasks.map((task) => task.subject))];

  const results = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase();
    return sortTasks(
      tasks.filter((task) => {
        if (subject !== "all" && task.subject !== subject) return false;
        if (type !== "all" && task.type !== type) return false;
        if (status === "open" && task.completed) return false;
        if (status === "completed" && !task.completed) return false;
        if (!normalized) return true;
        return [task.title, task.subject, task.notes, task.stage]
          .join(" ")
          .toLocaleLowerCase()
          .includes(normalized);
      }),
      "smart",
    );
  }, [query, status, subject, tasks, type]);

  return (
    <div className="screen scroll-screen search-screen">
      <ScreenHeader title="搜索" subtitle="快速查找任务、活动和重要日期。" />
      <div className="search-control-row">
        <label className="search-field">
          <Search />
          <input
            ref={inputRef}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="搜索"
            inputMode="search"
          />
        </label>
        <button
          className="search-close"
          type="button"
          onClick={() => {
            setQuery("");
            inputRef.current?.blur();
          }}
          aria-label="清除搜索并收起键盘"
        >
          <X />
        </button>
      </div>
      <div className="filter-scroll">
        <FilterSelect
          icon={BookOpen}
          value={subject}
          onChange={setSubject}
          options={[
            ["all", "科目"],
            ...subjects.map((item) => [item, item] as [string, string]),
          ]}
        />
        <FilterSelect
          icon={LayoutGrid}
          value={type}
          onChange={setType}
          options={[
            ["all", "任务类型"],
            ...Object.entries(taskMeta).map(([value, meta]) => [
              value,
              meta.title,
            ] as [string, string]),
          ]}
        />
        <FilterSelect
          icon={CheckCircle2}
          value={status}
          onChange={setStatus}
          options={[
            ["all", "状态"],
            ["open", "进行中"],
            ["completed", "已完成"],
          ]}
        />
      </div>
      <SectionTitle title={query ? "搜索结果" : "所有项目"} value={`${results.length}`} />
      <div className="search-results">
        {results.map((task) => (
          <TaskRow
            key={task.id}
            task={task}
            density="compact"
            showPercentage
            showNotes={false}
            onOpen={() => onOpenTask(task.id)}
          />
        ))}
        {results.length === 0 && (
          <div className="simple-empty">
            <Search />
            <strong>没有匹配项目</strong>
            <span>试试其他关键词或筛选条件。</span>
          </div>
        )}
      </div>
    </div>
  );
}

function FilterSelect({
  icon: Icon,
  value,
  onChange,
  options,
}: {
  icon: LucideIcon;
  value: string;
  onChange: (value: string) => void;
  options: [string, string][];
}) {
  return (
    <label className="filter-chip">
      <Icon />
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        {options.map(([optionValue, title]) => (
          <option key={optionValue} value={optionValue}>
            {title}
          </option>
        ))}
      </select>
      <ChevronDown />
    </label>
  );
}

function ProfileScreen({
  tasks,
  settings,
  onOpenSettings,
  onReset,
}: {
  tasks: PlanoraItem[];
  settings: DemoSettings;
  onOpenSettings: (section: "appearance" | "display") => void;
  onReset: () => void;
}) {
  const subjects = [...new Set(tasks.map((task) => task.subject))];
  return (
    <div className="screen scroll-screen">
      <ScreenHeader title="我的" />
      <section className="profile-card">
        <LogoMark small />
        <div>
          <h3>Mitty</h3>
          <p>IB 学习空间</p>
        </div>
      </section>

      <SectionTitle title="设置" />
      <section className="settings-list">
        <SettingsRow
          icon={Palette}
          title="外观"
          value={themeTitle(settings.theme)}
          onClick={() => onOpenSettings("appearance")}
        />
        <SettingsRow
          icon={Settings2}
          title="任务显示"
          value={settings.density === "comfortable" ? "舒适" : "紧凑"}
          onClick={() => onOpenSettings("display")}
        />
      </section>

      <SectionTitle title="任务存储" />
      <section className="backup-card">
        <Archive />
        <div>
          <strong>{tasks.length} 项任务</strong>
          <span>JSON v8 · 浏览器本地演示</span>
        </div>
        <button type="button" onClick={onReset}>
          恢复演示
        </button>
      </section>

      <SectionTitle title="当前科目" value={`${subjects.length}`} />
      <section className="subject-list">
        {subjects.map((subject) => (
          <div key={subject}>
            <BookOpen />
            <span>{subject}</span>
            <strong>{tasks.filter((task) => task.subject === subject).length}</strong>
          </div>
        ))}
      </section>
    </div>
  );
}

function SettingsRow({
  icon: Icon,
  title,
  value,
  onClick,
}: {
  icon: LucideIcon;
  title: string;
  value: string;
  onClick: () => void;
}) {
  return (
    <button type="button" onClick={onClick}>
      <span className="settings-icon">
        <Icon />
      </span>
      <span>{title}</span>
      <small>{value}</small>
      <ChevronDown className="row-chevron" />
    </button>
  );
}

function SettingsScreen({
  section,
  settings,
  onChange,
  onBack,
}: {
  section: "appearance" | "display";
  settings: DemoSettings;
  onChange: (settings: DemoSettings) => void;
  onBack: () => void;
}) {
  if (section === "appearance") {
    return (
      <div className="screen scroll-screen">
        <ScreenHeader title="外观" subtitle="选择颜色主题与显示模式。" onBack={onBack} />
        <SectionTitle title="颜色主题" />
        <div className="theme-grid">
          {(["classic", "ocean", "forest", "sunset"] as Theme[]).map((theme) => (
            <button
              type="button"
              key={theme}
              className={`theme-option theme-preview-${theme} ${
                settings.theme === theme ? "selected" : ""
              }`}
              onClick={() => onChange({ ...settings, theme })}
            >
              <span className="theme-swatch" />
              <strong>{themeTitle(theme)}</strong>
              {settings.theme === theme && <Check />}
            </button>
          ))}
        </div>
        <SectionTitle title="显示模式" />
        <section className="segmented-setting">
          <button
            className={!settings.dark ? "selected" : ""}
            type="button"
            onClick={() => onChange({ ...settings, dark: false })}
          >
            <Sun />
            浅色
          </button>
          <button
            className={settings.dark ? "selected" : ""}
            type="button"
            onClick={() => onChange({ ...settings, dark: true })}
          >
            <Moon />
            深色
          </button>
        </section>
      </div>
    );
  }

  return (
    <div className="screen scroll-screen">
      <ScreenHeader
        title="任务显示"
        subtitle="控制任务列表的外观与排序。"
        onBack={onBack}
      />
      <SectionTitle title="列表密度" />
      <section className="segmented-setting">
        {(["comfortable", "compact"] as Density[]).map((density) => (
          <button
            className={settings.density === density ? "selected" : ""}
            type="button"
            key={density}
            onClick={() => onChange({ ...settings, density })}
          >
            {density === "comfortable" ? <LayoutGrid /> : <Menu />}
            {density === "comfortable" ? "舒适" : "紧凑"}
          </button>
        ))}
      </section>
      <SectionTitle title="排序" />
      <section className="settings-radio-list">
        {(
          [
            ["smart", "智能排序"],
            ["deadline", "截止日期"],
            ["priority", "优先级"],
            ["title", "标题"],
          ] as [SortOrder, string][]
        ).map(([order, title]) => (
          <button
            type="button"
            key={order}
            onClick={() => onChange({ ...settings, sortOrder: order })}
          >
            <span>{title}</span>
            {settings.sortOrder === order ? <CheckCircle2 /> : <Circle />}
          </button>
        ))}
      </section>
      <SectionTitle title="内容" />
      <section className="toggle-list">
        <ToggleRow
          title="显示已完成任务"
          checked={settings.showCompleted}
          onChange={(showCompleted) => onChange({ ...settings, showCompleted })}
        />
        <ToggleRow
          title="显示进度百分比"
          checked={settings.showPercentage}
          onChange={(showPercentage) => onChange({ ...settings, showPercentage })}
        />
        <ToggleRow
          title="显示备注"
          checked={settings.showNotes}
          onChange={(showNotes) => onChange({ ...settings, showNotes })}
        />
      </section>
    </div>
  );
}

function ToggleRow({
  title,
  checked,
  onChange,
}: {
  title: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label>
      <span>{title}</span>
      <input
        type="checkbox"
        checked={checked}
        onChange={(event) => onChange(event.target.checked)}
      />
      <i />
    </label>
  );
}

function TaskDetailScreen({
  task,
  onBack,
  onChange,
}: {
  task: PlanoraItem;
  onBack: () => void;
  onChange: (task: PlanoraItem) => void;
}) {
  const meta = taskMeta[task.type];
  const Icon = meta.icon;
  const stages = [
    "Research Question",
    "Methodology",
    "Data Collection",
    "Analysis",
    "Evaluation",
    "Final Submission",
  ];

  return (
    <div className="screen scroll-screen detail-screen">
      <ScreenHeader title="任务详情" onBack={onBack} />
      <div className="detail-title">
        <span className={`task-icon large tone-${meta.color}`}>
          <Icon />
        </span>
        <div>
          <h2>{task.title}</h2>
          <p>{task.subject}</p>
        </div>
        <PriorityBadge priority={task.priority} />
      </div>
      <section className="detail-list">
        <DetailLine icon={LayoutGrid} title="类型" value={meta.title} />
        <DetailLine
          icon={CalendarDays}
          title="截止日期"
          value={formatDay(task.deadline, true)}
        />
        <DetailLine
          icon={Clock3}
          title="计划完成"
          value={task.plannedDate ? formatDay(task.plannedDate, true) : "未安排"}
        />
        <DetailLine icon={Bell} title="提醒" value="提前 1 天 · 当天" />
      </section>

      <SectionTitle title="进度" />
      <section className="detail-progress">
        {task.progressKind === "percentage" ? (
          <>
            <div>
              <span>完成度</span>
              <strong>{task.progress}%</strong>
            </div>
            <input
              type="range"
              min="0"
              max="100"
              step="5"
              value={task.progress}
              onChange={(event) =>
                onChange({ ...task, progress: Number(event.target.value) })
              }
            />
            <ProgressBar value={task.progress} color={meta.color} />
          </>
        ) : (
          <div className="stage-picker">
            {stages.map((stage, index) => {
              const activeIndex = Math.max(0, stages.indexOf(task.stage));
              const done = index < activeIndex;
              const active = stage === task.stage;
              return (
                <button
                  type="button"
                  key={stage}
                  className={active ? "active" : done ? "done" : ""}
                  onClick={() =>
                    onChange({
                      ...task,
                      stage,
                      progress: Math.round(((index + 1) / stages.length) * 100),
                    })
                  }
                >
                  {done ? <CheckCircle2 /> : active ? <Gauge /> : <Circle />}
                  <span>{stage}</span>
                </button>
              );
            })}
          </div>
        )}
      </section>

      <SectionTitle title="备注" />
      <section className="notes-panel">{task.notes || "暂无备注"}</section>

      <button
        className="primary-button full"
        type="button"
        onClick={() => onChange({ ...task, completed: !task.completed })}
      >
        {task.completed ? <RotateCcw /> : <CheckCircle2 />}
        {task.completed ? "重新打开任务" : "标记为已完成"}
      </button>
    </div>
  );
}

function DetailLine({
  icon: Icon,
  title,
  value,
}: {
  icon: LucideIcon;
  title: string;
  value: string;
}) {
  return (
    <div>
      <Icon />
      <span>{title}</span>
      <strong>{value}</strong>
    </div>
  );
}

function TodayScreen({
  tasks,
  onBack,
  onOpenTask,
}: {
  tasks: PlanoraItem[];
  onBack: () => void;
  onOpenTask: (taskId: string) => void;
}) {
  const today = localISO(new Date());
  const overdue = tasks.filter(
    (task) => !task.completed && task.deadline && task.deadline < today,
  );
  const due = tasks.filter(
    (task) => !task.completed && task.deadline === today,
  );
  const planned = tasks.filter(
    (task) =>
      !task.completed &&
      task.plannedDate === today &&
      task.deadline !== today,
  );
  const empty = overdue.length + due.length + planned.length === 0;

  return (
    <div className="screen scroll-screen">
      <ScreenHeader
        title="今日"
        subtitle={new Intl.DateTimeFormat("zh-CN", { dateStyle: "full" }).format(
          new Date(),
        )}
        onBack={onBack}
      />
      {empty && <div className="simple-empty"><Sun /><strong>今天没有安排</strong></div>}
      <PlanningGroup title="逾期" tasks={overdue} onOpenTask={onOpenTask} />
      <PlanningGroup title="今天截止" tasks={due} onOpenTask={onOpenTask} />
      <PlanningGroup title="计划今天完成" tasks={planned} onOpenTask={onOpenTask} />
    </div>
  );
}

function WeekScreen({
  tasks,
  onBack,
  onOpenTask,
}: {
  tasks: PlanoraItem[];
  onBack: () => void;
  onOpenTask: (taskId: string) => void;
}) {
  const days = Array.from({ length: 7 }, (_, index) => offsetISO(index));
  const open = tasks.filter((task) => !task.completed);
  const unscheduled = open.filter((task) => !task.plannedDate && !task.deadline);
  const busiest = days
    .map((day) => ({
      day,
      count: open.filter(
        (task) => (task.plannedDate ?? task.deadline) === day,
      ).length,
    }))
    .sort((a, b) => b.count - a.count)[0];

  return (
    <div className="screen scroll-screen">
      <ScreenHeader
        title="本周"
        subtitle={
          busiest?.count
            ? `最忙：${formatDay(busiest.day, true)} · ${busiest.count} 项任务`
            : "本周还没有安排"
        }
        onBack={onBack}
      />
      <div className="week-list">
        {days.map((day) => {
          const dayTasks = open.filter(
            (task) => (task.plannedDate ?? task.deadline) === day,
          );
          return (
            <section key={day}>
              <h3>{formatDay(day, true)}</h3>
              {dayTasks.length ? (
                dayTasks.map((task) => (
                  <button
                    type="button"
                    key={task.id}
                    onClick={() => onOpenTask(task.id)}
                  >
                    <span className={`week-dot tone-${taskMeta[task.type].color}`} />
                    <span>{task.title}</span>
                    <small>{task.subject}</small>
                  </button>
                ))
              ) : (
                <p>无安排</p>
              )}
            </section>
          );
        })}
      </div>
      {unscheduled.length > 0 && (
        <PlanningGroup
          title={`未安排 · ${unscheduled.length}`}
          tasks={unscheduled}
          onOpenTask={onOpenTask}
        />
      )}
    </div>
  );
}

function PlanningGroup({
  title,
  tasks,
  onOpenTask,
}: {
  title: string;
  tasks: PlanoraItem[];
  onOpenTask: (taskId: string) => void;
}) {
  if (!tasks.length) return null;
  return (
    <>
      <SectionTitle title={title} value={`${tasks.length}`} />
      <div className="stack-list">
        {tasks.map((task) => (
          <TaskRow
            key={task.id}
            task={task}
            density="compact"
            showPercentage
            showNotes={false}
            onOpen={() => onOpenTask(task.id)}
          />
        ))}
      </div>
    </>
  );
}

function CreateScreen({
  onClose,
  onSave,
}: {
  onClose: () => void;
  onSave: (task: PlanoraItem) => void;
}) {
  const [mode, setMode] = useState<"select" | "quick" | "full">("select");
  const [type, setType] = useState<TaskType>("assignment");
  const [title, setTitle] = useState("");
  const [subject, setSubject] = useState("Physics HL");
  const [hasDeadline, setHasDeadline] = useState(true);
  const [deadline, setDeadline] = useState(offsetISO(7));
  const [plannedDate, setPlannedDate] = useState("");
  const [priority, setPriority] = useState<Priority>("medium");
  const [progressKind, setProgressKind] = useState<"percentage" | "stage">(
    "percentage",
  );
  const [notes, setNotes] = useState("");
  const [recurring, setRecurring] = useState(false);

  function chooseType(nextType: TaskType) {
    setType(nextType);
    setTitle(taskMeta[nextType].title);
    setProgressKind(["tok", "ee", "ia", "cas"].includes(nextType) ? "stage" : "percentage");
    setMode("full");
  }

  function save() {
    const cleanTitle = title.trim();
    if (!cleanTitle) return;
    onSave({
      id: crypto.randomUUID(),
      title: cleanTitle,
      subject,
      type,
      priority: mode === "quick" ? "medium" : priority,
      deadline: hasDeadline ? deadline : undefined,
      plannedDate: plannedDate || undefined,
      progressKind: mode === "quick" ? "percentage" : progressKind,
      progress: 0,
      stage: taskMeta[type].defaultStage,
      notes: mode === "quick" ? "" : notes,
      completed: false,
      recurring: mode === "full" && recurring,
    });
  }

  return (
    <div className="create-overlay">
      <div className="create-topbar">
        {mode !== "select" ? (
          <button className="icon-button" type="button" onClick={() => setMode("select")}>
            <ChevronLeft />
          </button>
        ) : (
          <span />
        )}
        <h2>{mode === "select" ? "新建任务" : mode === "quick" ? "快速新建" : taskMeta[type].title}</h2>
        <button className="icon-button" type="button" onClick={onClose}>
          <X />
        </button>
      </div>

      {mode === "select" ? (
        <div className="create-content scroll-screen">
          <button className="quick-create-card" type="button" onClick={() => setMode("quick")}>
            <span><Sparkles /></span>
            <div>
              <strong>快速新建</strong>
              <small>只填写标题、科目和日期。</small>
            </div>
          </button>
          <div className="type-grid">
            {(Object.keys(taskMeta) as TaskType[]).map((taskType) => {
              const meta = taskMeta[taskType];
              const Icon = meta.icon;
              return (
                <button
                  type="button"
                  key={taskType}
                  className={`tone-${meta.color}`}
                  onClick={() => chooseType(taskType)}
                >
                  <span><Icon /></span>
                  <strong>{meta.title}</strong>
                </button>
              );
            })}
          </div>
        </div>
      ) : (
        <div className="create-content scroll-screen">
          <section className="form-panel">
            <FormField label="标题">
              <input
                value={title}
                onChange={(event) => setTitle(event.target.value)}
                placeholder="任务名称"
              />
            </FormField>
            <FormField label="科目">
              <select value={subject} onChange={(event) => setSubject(event.target.value)}>
                <option>Physics HL</option>
                <option>Mathematics AA HL</option>
                <option>English B HL</option>
                <option>TOK</option>
                <option>CAS</option>
              </select>
            </FormField>
            <ToggleRow title="截止日期" checked={hasDeadline} onChange={setHasDeadline} />
            {hasDeadline && (
              <FormField label="日期">
                <input type="date" value={deadline} onChange={(event) => setDeadline(event.target.value)} />
              </FormField>
            )}
            <FormField label="计划完成日期">
              <input type="date" value={plannedDate} onChange={(event) => setPlannedDate(event.target.value)} />
            </FormField>
            {mode === "full" && (
              <>
                <FormField label="优先级">
                  <div className="segmented-inline">
                    {(["low", "medium", "high"] as Priority[]).map((item) => (
                      <button
                        type="button"
                        key={item}
                        className={priority === item ? "selected" : ""}
                        onClick={() => setPriority(item)}
                      >
                        {priorities[item].title}
                      </button>
                    ))}
                  </div>
                </FormField>
                <FormField label="进度方式">
                  <div className="segmented-inline">
                    <button
                      type="button"
                      className={progressKind === "percentage" ? "selected" : ""}
                      onClick={() => setProgressKind("percentage")}
                    >
                      百分比
                    </button>
                    <button
                      type="button"
                      className={progressKind === "stage" ? "selected" : ""}
                      onClick={() => setProgressKind("stage")}
                    >
                      阶段
                    </button>
                  </div>
                </FormField>
                <ToggleRow title="重复任务" checked={recurring} onChange={setRecurring} />
                <FormField label="备注">
                  <textarea value={notes} onChange={(event) => setNotes(event.target.value)} rows={3} />
                </FormField>
              </>
            )}
          </section>
          <button className="primary-button full" type="button" onClick={save} disabled={!title.trim()}>
            <Check />
            保存任务
          </button>
        </div>
      )}
    </div>
  );
}

function FormField({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="form-field">
      <span>{label}</span>
      {children}
    </label>
  );
}

function TabBar({
  active,
  onSelect,
  onCreate,
}: {
  active: Tab;
  onSelect: (tab: Tab) => void;
  onCreate: () => void;
}) {
  const tabs: { id: Tab; title: string; icon: LucideIcon }[] = [
    { id: "home", title: "首页", icon: Home },
    { id: "tasks", title: "任务", icon: ListChecks },
    { id: "search", title: "搜索", icon: Search },
    { id: "profile", title: "我的", icon: UserRound },
  ];
  return (
    <nav className="tab-bar" aria-label="主导航">
      {tabs.slice(0, 2).map((item) => (
        <TabButton key={item.id} item={item} active={active} onSelect={onSelect} />
      ))}
      <button className="create-tab" type="button" onClick={onCreate} aria-label="新建任务">
        <Plus />
      </button>
      {tabs.slice(2).map((item) => (
        <TabButton key={item.id} item={item} active={active} onSelect={onSelect} />
      ))}
    </nav>
  );
}

function TabButton({
  item,
  active,
  onSelect,
}: {
  item: { id: Tab; title: string; icon: LucideIcon };
  active: Tab;
  onSelect: (tab: Tab) => void;
}) {
  const Icon = item.icon;
  return (
    <button
      className={active === item.id ? "active" : ""}
      type="button"
      onClick={() => onSelect(item.id)}
    >
      <Icon />
      <span>{item.title}</span>
    </button>
  );
}

function MiniCalendar({
  tasks,
  onOpenTask,
}: {
  tasks: PlanoraItem[];
  onOpenTask: (taskId: string) => void;
}) {
  const days = Array.from({ length: 7 }, (_, index) => offsetISO(index));
  return (
    <section className="mini-calendar">
      <div className="calendar-days">
        {days.map((day) => {
          const date = new Date(`${day}T12:00:00`);
          const dayTasks = tasks.filter(
            (task) => task.deadline === day || task.plannedDate === day,
          );
          return (
            <div key={day} className={day === localISO(new Date()) ? "today" : ""}>
              <span>{new Intl.DateTimeFormat("zh-CN", { weekday: "short" }).format(date)}</span>
              <strong>{date.getDate()}</strong>
              <i className={dayTasks.length ? "has-event" : ""} />
            </div>
          );
        })}
      </div>
      <div className="calendar-events">
        {tasks
          .filter((task) => {
            const day = task.plannedDate ?? task.deadline;
            return day && days.includes(day) && !task.completed;
          })
          .slice(0, 3)
          .map((task) => (
            <button type="button" key={task.id} onClick={() => onOpenTask(task.id)}>
              <span className={`week-dot tone-${taskMeta[task.type].color}`} />
              <span>{task.title}</span>
              <small>{formatDay(task.plannedDate ?? task.deadline)}</small>
            </button>
          ))}
      </div>
    </section>
  );
}

function SectionTitle({ title, value }: { title: string; value?: string }) {
  return (
    <div className="section-title">
      <h3>{title}</h3>
      {value && <span>{value}</span>}
    </div>
  );
}

function PriorityBadge({
  priority,
  compact = false,
}: {
  priority: Priority;
  compact?: boolean;
}) {
  return (
    <span className={`priority priority-${priority} ${compact ? "compact" : ""}`}>
      {priority === "high" && "!"}
      {!compact && priorities[priority].title}
    </span>
  );
}

function ProgressBar({ value, color }: { value: number; color: string }) {
  return (
    <div className={`progress-track tone-${color}`}>
      <span style={{ width: `${Math.min(100, Math.max(0, value))}%` }} />
    </div>
  );
}

function Insight({ value, label }: { value: string; label: string }) {
  return (
    <div>
      <strong>{value}</strong>
      <span>{label}</span>
    </div>
  );
}

function themeTitle(theme: Theme) {
  return {
    classic: "经典",
    ocean: "海洋",
    forest: "森林",
    sunset: "日落",
  }[theme];
}
