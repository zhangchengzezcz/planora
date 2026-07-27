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
  ChevronRight,
  Circle,
  Clock3,
  FileText,
  FlaskConical,
  Gauge,
  Globe2,
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
import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  browserLocale,
  copy,
  dateLocale,
  demoLocales,
  localeCode,
  localeLabel,
  type DemoLocale,
} from "./planora-copy";

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
type Curriculum = "ib" | "igcse";
type Theme = "classic" | "ocean" | "forest" | "sunset";
type Density = "comfortable" | "compact";
type SortOrder = "smart" | "deadline" | "priority" | "title";
type Screen =
  | { kind: "tab" }
  | { kind: "task"; taskId: string }
  | { kind: "today" }
  | { kind: "week" }
  | { kind: "create" }
  | {
      kind: "settings";
      section: "appearance" | "display" | "language";
    };

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
const STORAGE_LOCALE = "planora.demo.locale.v1";
const STORAGE_CURRICULUM = "planora.demo.curriculum.v1";
const STORAGE_INTRO = "planora.demo.intro.v1";
const dayMs = 86_400_000;

const LocaleContext = createContext<DemoLocale>("zh-Hans");

function useDemoCopy() {
  const locale = useContext(LocaleContext);
  return {
    locale,
    t: (source: string) => copy(locale, source),
  };
}

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

function formatDay(value: string | undefined, locale: DemoLocale, long = false) {
  if (!value) return copy(locale, "无截止日期");
  const date = new Date(`${value}T12:00:00`);
  return new Intl.DateTimeFormat(dateLocale(locale), {
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

function deadlineLabel(value: string | undefined, locale: DemoLocale) {
  const days = daysUntil(value);
  if (days === null) return copy(locale, "无截止日期");
  if (days < 0) {
    const overdue = Math.abs(days);
    if (locale === "en") return `${overdue} ${overdue === 1 ? "day" : "days"} overdue`;
    if (locale === "ja") return `${overdue}日超過`;
    return `已逾期 ${overdue} 天`;
  }
  if (days === 0) return copy(locale, "今天截止");
  if (days === 1)
    return locale === "en"
      ? "Due tomorrow"
      : locale === "ja"
        ? "明日締切"
        : "明天截止";
  if (locale === "en") return `${days} days left`;
  if (locale === "ja") return `あと${days}日`;
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
  const [locale, setLocale] = useState<DemoLocale>("zh-Hans");
  const [curriculum, setCurriculum] = useState<Curriculum>("igcse");
  const [introComplete, setIntroComplete] = useState(false);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      try {
        const savedTasks = window.localStorage.getItem(STORAGE_TASKS);
        const savedSettings = window.localStorage.getItem(STORAGE_SETTINGS);
        const savedLocale = window.localStorage.getItem(
          STORAGE_LOCALE,
        ) as DemoLocale | null;
        const savedCurriculum = window.localStorage.getItem(
          STORAGE_CURRICULUM,
        ) as Curriculum | null;
        if (savedTasks) setTasks(JSON.parse(savedTasks) as PlanoraItem[]);
        if (savedSettings)
          setSettings({
            ...defaultSettings,
            ...(JSON.parse(savedSettings) as Partial<DemoSettings>),
          });
        setLocale(
          demoLocales.includes(savedLocale as DemoLocale)
            ? (savedLocale as DemoLocale)
            : browserLocale(window.navigator.language),
        );
        if (savedCurriculum === "ib" || savedCurriculum === "igcse") {
          setCurriculum(savedCurriculum);
        }
        setIntroComplete(window.localStorage.getItem(STORAGE_INTRO) === "1");
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

  useEffect(() => {
    if (hydrated) window.localStorage.setItem(STORAGE_LOCALE, locale);
  }, [hydrated, locale]);

  useEffect(() => {
    if (hydrated)
      window.localStorage.setItem(STORAGE_CURRICULUM, curriculum);
  }, [curriculum, hydrated]);

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

  function finishIntro() {
    setIntroComplete(true);
    window.localStorage.setItem(STORAGE_INTRO, "1");
  }

  function replayIntro() {
    setTab("home");
    setScreen({ kind: "tab" });
    setIntroComplete(false);
    window.localStorage.removeItem(STORAGE_INTRO);
  }

  const activeTask =
    screen.kind === "task"
      ? tasks.find((task) => task.id === screen.taskId)
      : undefined;

  return (
    <LocaleContext.Provider value={locale}>
      <main
        lang={locale}
        className={`showcase theme-${settings.theme} ${
          settings.dark ? "is-dark" : ""
        }`}
      >
        {introComplete && (
          <LanguageMenu
            locale={locale}
            onChange={setLocale}
            className="site-language-menu"
          />
        )}

        <aside className="showcase-context">
          <div className="showcase-brand">
            <LogoMark />
            <div>
              <strong>Planora</strong>
              <span>{copy(locale, "交互式演示")}</span>
            </div>
          </div>
          <div className="showcase-copy">
            <p className="eyebrow">
              {copy(locale, "IB · IGCSE 学习规划")}
            </p>
            <h1>{copy(locale, "把 Deadline 变成清晰的行动。")}</h1>
            <p>
              {copy(
                locale,
                "这是基于真实 SwiftUI 项目制作的浏览器演示。任务与外观设置只保存在当前浏览器。",
              )}
            </p>
          </div>
          <div className="showcase-status">
            <span>
              <span className="status-dot" />
              {copy(locale, "交互数据已启用")}
            </span>
            <div className="showcase-actions">
              <button type="button" onClick={replayIntro}>
                <Sparkles size={16} />
                {copy(locale, "重播介绍")}
              </button>
              <button type="button" onClick={resetDemo}>
                <RotateCcw size={16} />
                {copy(locale, "重置演示")}
              </button>
            </div>
          </div>
        </aside>

        <section
          className="device-stage"
          aria-label="Planora App interactive demo"
        >
          <div className="device">
            <div className="device-speaker" aria-hidden="true" />
            <div className="device-screen">
              <StatusBar dark={settings.dark} />
              <div className="app-content">
                {!hydrated ? null : !introComplete ? (
                  <Onboarding
                    locale={locale}
                    onLocaleChange={setLocale}
                    onComplete={finishIntro}
                  />
                ) : (
                  <>
                    {screen.kind === "tab" && tab === "home" && (
                      <HomeScreen
                        tasks={tasks}
                        settings={settings}
                        curriculum={curriculum}
                        onCurriculumChange={setCurriculum}
                        onOpenTask={(taskId) =>
                          setScreen({ kind: "task", taskId })
                        }
                        onToggleTask={(task) =>
                          updateTask({
                            ...task,
                            completed: !task.completed,
                          })
                        }
                        onOpenToday={() => setScreen({ kind: "today" })}
                        onOpenWeek={() => setScreen({ kind: "week" })}
                        onCreate={() => setScreen({ kind: "create" })}
                      />
                    )}
                    {screen.kind === "tab" && tab === "tasks" && (
                      <TasksScreen
                        tasks={tasks}
                        settings={settings}
                        onOpenTask={(taskId) =>
                          setScreen({ kind: "task", taskId })
                        }
                        onToggle={(task) =>
                          updateTask({
                            ...task,
                            completed: !task.completed,
                          })
                        }
                      />
                    )}
                    {screen.kind === "tab" && tab === "search" && (
                      <SearchScreen
                        tasks={tasks}
                        onOpenTask={(taskId) =>
                          setScreen({ kind: "task", taskId })
                        }
                      />
                    )}
                    {screen.kind === "tab" && tab === "profile" && (
                      <ProfileScreen
                        tasks={tasks}
                        settings={settings}
                        curriculum={curriculum}
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
                        onOpenTask={(taskId) =>
                          setScreen({ kind: "task", taskId })
                        }
                      />
                    )}
                    {screen.kind === "week" && (
                      <WeekScreen
                        tasks={tasks}
                        onBack={() => setScreen({ kind: "tab" })}
                        onOpenTask={(taskId) =>
                          setScreen({ kind: "task", taskId })
                        }
                      />
                    )}
                    {screen.kind === "settings" && (
                      <SettingsScreen
                        section={screen.section}
                        settings={settings}
                        locale={locale}
                        onChange={setSettings}
                        onLocaleChange={setLocale}
                        onBack={() => setScreen({ kind: "tab" })}
                      />
                    )}
                    {screen.kind === "create" && (
                      <CreateScreen
                        curriculum={curriculum}
                        onClose={() => setScreen({ kind: "tab" })}
                        onSave={(task) => {
                          setTasks((current) => [task, ...current]);
                          setTab("home");
                          setScreen({ kind: "tab" });
                        }}
                      />
                    )}
                  </>
                )}
              </div>

              {hydrated &&
                introComplete &&
                screen.kind !== "create" && (
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
    </LocaleContext.Provider>
  );
}

function LanguageMenu({
  locale,
  onChange,
  className = "",
}: {
  locale: DemoLocale;
  onChange: (locale: DemoLocale) => void;
  className?: string;
}) {
  const [open, setOpen] = useState(false);
  return (
    <div className={`language-menu ${className} ${open ? "is-open" : ""}`}>
      <button
        className="language-menu-trigger"
        type="button"
        aria-expanded={open}
        aria-label={copy(locale, "语言")}
        onClick={() => setOpen((value) => !value)}
      >
        <Globe2 />
        <span>{localeCode(locale)}</span>
        <ChevronDown />
      </button>
      {open && (
        <div className="language-popover" role="menu">
          {demoLocales.map((item) => (
            <button
              type="button"
              role="menuitemradio"
              aria-checked={item === locale}
              key={item}
              onClick={() => {
                onChange(item);
                setOpen(false);
              }}
            >
              <span>{localeLabel(item, locale)}</span>
              {item === locale && <Check />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function LocaleChoices({
  locale,
  onChange,
}: {
  locale: DemoLocale;
  onChange: (locale: DemoLocale) => void;
}) {
  return (
    <div className="locale-choices" aria-label={copy(locale, "语言")}>
      {demoLocales.map((item) => (
        <button
          type="button"
          className={locale === item ? "selected" : ""}
          key={item}
          onClick={() => onChange(item)}
        >
          {localeLabel(item, locale)}
        </button>
      ))}
    </div>
  );
}

function Onboarding({
  locale,
  onLocaleChange,
  onComplete,
}: {
  locale: DemoLocale;
  onLocaleChange: (locale: DemoLocale) => void;
  onComplete: () => void;
}) {
  const [phase, setPhase] = useState<"welcome" | "features">("welcome");

  useEffect(() => {
    const timer = window.setTimeout(() => setPhase("features"), 2350);
    return () => window.clearTimeout(timer);
  }, []);

  return (
    <section className={`onboarding-screen phase-${phase}`}>
      <div className="onboarding-language">
        <Globe2 />
        <LocaleChoices locale={locale} onChange={onLocaleChange} />
      </div>

      {phase === "welcome" ? (
        <div className="welcome-stage">
          <LogoMark />
          <div className="welcome-copy">
            <span>{copy(locale, "欢迎使用")}</span>
            <strong>Planora</strong>
          </div>
          <p>{copy(locale, "学习规划，简单清晰。")}</p>
        </div>
      ) : (
        <div className="feature-intro">
          <div className="feature-intro-heading">
            <LogoMark small />
            <h2>{copy(locale, "欢迎使用 Planora")}</h2>
            <p>
              {copy(
                locale,
                "一款为 IB 和 IGCSE 学生设计的学习规划工具。先选择课程体系与科目，再清晰查看任务、进度和重要日期。",
              )}
            </p>
          </div>
          <div className="feature-intro-list">
            <IntroFeature
              icon={BookOpen}
              tone="blue"
              title={copy(locale, "管理课程")}
              description={copy(locale, "按课程体系整理科目与学习内容。")}
            />
            <IntroFeature
              icon={CalendarDays}
              tone="amber"
              title={copy(locale, "掌握节点")}
              description={copy(
                locale,
                "把作业、考试和长期项目放进清晰时间线。",
              )}
            />
            <IntroFeature
              icon={Gauge}
              tone="green"
              title={copy(locale, "推进进度")}
              description={copy(
                locale,
                "用百分比或阶段追踪每一项学习任务。",
              )}
            />
          </div>
          <button
            className="primary-button onboarding-continue"
            type="button"
            onClick={onComplete}
          >
            {copy(locale, "开始使用")}
          </button>
        </div>
      )}
    </section>
  );
}

function IntroFeature({
  icon: Icon,
  tone,
  title,
  description,
}: {
  icon: LucideIcon;
  tone: string;
  title: string;
  description: string;
}) {
  return (
    <div className="intro-feature">
      <span className={`tone-${tone}`}>
        <Icon />
      </span>
      <div>
        <strong>{title}</strong>
        <p>{description}</p>
      </div>
    </div>
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
  const { t } = useDemoCopy();
  return (
    <header className={`screen-header ${onBack ? "with-back" : ""}`}>
      {onBack && (
        <button className="icon-button back-button" type="button" onClick={onBack}>
          <ChevronLeft />
          <span className="sr-only">{t("返回")}</span>
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
  curriculum,
  onCurriculumChange,
  onOpenTask,
  onToggleTask,
  onOpenToday,
  onOpenWeek,
  onCreate,
}: {
  tasks: PlanoraItem[];
  settings: DemoSettings;
  curriculum: Curriculum;
  onCurriculumChange: (curriculum: Curriculum) => void;
  onOpenTask: (taskId: string) => void;
  onToggleTask: (task: PlanoraItem) => void;
  onOpenToday: () => void;
  onOpenWeek: () => void;
  onCreate: () => void;
}) {
  const { locale, t } = useDemoCopy();
  const [curriculumOpen, setCurriculumOpen] = useState(false);
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
          <h2>
            {locale === "en"
              ? "Hello, Mitty"
              : locale === "ja"
                ? "こんにちは、Mitty"
                : "你好，Mitty"}
          </h2>
          <p>
            {locale === "en"
              ? "What should you focus on now?"
              : locale === "ja"
                ? "今、何に集中しますか？"
                : "现在应该关注什么？"}
          </p>
        </div>
        <div
          className={`curriculum-menu ${curriculumOpen ? "is-open" : ""}`}
        >
          <button
            className="curriculum-badge"
            type="button"
            aria-expanded={curriculumOpen}
            onClick={() => setCurriculumOpen((value) => !value)}
          >
            {curriculum.toUpperCase()} <ChevronDown size={15} />
          </button>
          {curriculumOpen && (
            <div className="curriculum-popover" role="menu">
              {(["ib", "igcse"] as Curriculum[]).map((item) => (
                <button
                  type="button"
                  role="menuitemradio"
                  aria-checked={curriculum === item}
                  key={item}
                  onClick={() => {
                    onCurriculumChange(item);
                    setCurriculumOpen(false);
                  }}
                >
                  <span>
                    <strong>{item.toUpperCase()}</strong>
                    <small>
                      {item === "ib"
                        ? "Diploma Programme"
                        : "International GCSE"}
                    </small>
                  </span>
                  {curriculum === item && <Check />}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="planning-strip">
        <PlanningButton
          title={t("今天")}
          subtitle={t("执行今天的计划")}
          icon={Sun}
          color="amber"
          onClick={onOpenToday}
        />
        <PlanningButton
          title={t("本周")}
          subtitle={t("查看七天负载")}
          icon={CalendarDays}
          color="blue"
          onClick={onOpenWeek}
        />
      </div>

      {!focus ? (
        <section className="empty-panel">
          <ListChecks />
          <h3>{t("还没有任务")}</h3>
          <p>{t("点击加号创建第一个学习任务。")}</p>
          <button className="primary-button" type="button" onClick={onCreate}>
            <Plus size={18} />
            {t("新建任务")}
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
              <span className="eyebrow">{t("当前重点")}</span>
              <PriorityBadge priority={focus.priority} />
            </div>
            <div className="focus-main">
              <button
                className="focus-complete"
                type="button"
                aria-label={t("完成任务")}
                onClick={(event) => {
                  event.stopPropagation();
                  onToggleTask(focus);
                }}
              >
                <Circle />
              </button>
              <div>
                <h3>{focus.title}</h3>
                <p>{focus.subject}</p>
              </div>
              <span className="focus-open" aria-hidden="true">
                <ChevronRight />
              </span>
            </div>
            <p className="focus-message">
              {daysUntil(focus.deadline) !== null &&
              (daysUntil(focus.deadline) ?? 0) < 0
                ? t("已过日期。查看这个作业。")
                : deadlineLabel(focus.deadline, locale)}
            </p>
            <div className="focus-metadata">
              <div>
                <span>{t("截止日期")}</span>
                <strong>{formatDay(focus.deadline, locale)}</strong>
              </div>
              <div>
                <span>
                  {focus.progressKind === "stage" ? t("阶段") : t("进度")}
                </span>
                <strong>
                  {focus.progressKind === "stage"
                    ? t(focus.stage)
                    : `${focus.progress}%`}
                </strong>
              </div>
            </div>
          </section>

          <SectionTitle
            title={t("即将到来的任务")}
            value={
              locale === "en"
                ? `${openTasks.length} items`
                : `${openTasks.length} ${t("项")}`
            }
          />
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

          <SectionTitle
            title={t("学习进度")}
            value={`${completed} / ${tasks.length}`}
          />
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
              <Insight value={`${completed}`} label={t("本周完成")} />
              <Insight
                value={openTasks[0]?.subject ?? t("暂无")}
                label={t("当前重点")}
              />
              <Insight
                value={`${openTasks.filter((task) => (daysUntil(task.deadline) ?? 99) <= 7).length}`}
                label={t("未来七天")}
              />
            </div>
          </section>

          <SectionTitle title={t("日历预览")} value={t("本周")} />
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
  const { t } = useDemoCopy();
  const visible = sortTasks(
    tasks.filter((task) => settings.showCompleted || !task.completed),
    settings.sortOrder,
  );

  return (
    <div className="screen scroll-screen">
      <ScreenHeader
        title={t("任务")}
        subtitle={t("根据设置显示和排序任务。")}
      />
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
  const { locale, t } = useDemoCopy();
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
          <span className={`type-pill tone-${meta.color}`}>
            {t(meta.title)}
          </span>
        </div>
        <p>{task.subject}</p>
        <div className="task-metrics">
          <span>
            <CalendarDays />
            {formatDay(task.deadline, locale)}
          </span>
          <span>
            {task.progressKind === "percentage" && showPercentage
              ? `${task.progress}%`
              : t(task.stage)}
          </span>
        </div>
        {showNotes && density === "comfortable" && task.notes && (
          <p className="task-note">{t(task.notes)}</p>
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
            aria-label={
              task.completed ? t("重新打开任务") : t("完成任务")
            }
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
  const { t } = useDemoCopy();
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
      <ScreenHeader
        title={t("搜索")}
        subtitle={t("快速查找任务、活动和重要日期。")}
      />
      <div className="search-control-row">
        <label className="search-field">
          <Search />
          <input
            ref={inputRef}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder={t("搜索")}
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
          aria-label={t("清除搜索并收起键盘")}
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
            ["all", t("科目")],
            ...subjects.map((item) => [item, item] as [string, string]),
          ]}
        />
        <FilterSelect
          icon={LayoutGrid}
          value={type}
          onChange={setType}
          options={[
            ["all", t("任务类型")],
            ...Object.entries(taskMeta).map(([value, meta]) => [
              value,
              t(meta.title),
            ] as [string, string]),
          ]}
        />
        <FilterSelect
          icon={CheckCircle2}
          value={status}
          onChange={setStatus}
          options={[
            ["all", t("状态")],
            ["open", t("进行中")],
            ["completed", t("已完成")],
          ]}
        />
      </div>
      <SectionTitle
        title={query ? t("搜索结果") : t("所有项目")}
        value={`${results.length}`}
      />
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
            <strong>{t("没有匹配项目")}</strong>
            <span>{t("试试其他关键词或筛选条件。")}</span>
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
  curriculum,
  onOpenSettings,
  onReset,
}: {
  tasks: PlanoraItem[];
  settings: DemoSettings;
  curriculum: Curriculum;
  onOpenSettings: (
    section: "appearance" | "display" | "language",
  ) => void;
  onReset: () => void;
}) {
  const { locale, t } = useDemoCopy();
  const subjects = [...new Set(tasks.map((task) => task.subject))];
  return (
    <div className="screen scroll-screen">
      <ScreenHeader title={t("我的")} />
      <section className="profile-card">
        <LogoMark small />
        <div>
          <h3>Mitty</h3>
          <p>
            {curriculum.toUpperCase()} {t("学习空间")}
          </p>
        </div>
      </section>

      <SectionTitle title={t("设置")} />
      <section className="settings-list">
        <SettingsRow
          icon={Palette}
          title={t("外观")}
          value={themeTitle(settings.theme, locale)}
          onClick={() => onOpenSettings("appearance")}
        />
        <SettingsRow
          icon={Settings2}
          title={t("任务显示")}
          value={
            settings.density === "comfortable" ? t("舒适") : t("紧凑")
          }
          onClick={() => onOpenSettings("display")}
        />
        <SettingsRow
          icon={Globe2}
          title={t("语言")}
          value={localeLabel(locale, locale)}
          onClick={() => onOpenSettings("language")}
        />
      </section>

      <SectionTitle title={t("任务存储")} />
      <section className="backup-card">
        <Archive />
        <div>
          <strong>
            {tasks.length} {t("项")} {t("任务")}
          </strong>
          <span>JSON v8 · {t("浏览器本地演示")}</span>
        </div>
        <button type="button" onClick={onReset}>
          {t("恢复演示")}
        </button>
      </section>

      <SectionTitle title={t("当前科目")} value={`${subjects.length}`} />
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
  locale,
  onChange,
  onLocaleChange,
  onBack,
}: {
  section: "appearance" | "display" | "language";
  settings: DemoSettings;
  locale: DemoLocale;
  onChange: (settings: DemoSettings) => void;
  onLocaleChange: (locale: DemoLocale) => void;
  onBack: () => void;
}) {
  const { t } = useDemoCopy();
  if (section === "appearance") {
    return (
      <div className="screen scroll-screen">
        <ScreenHeader
          title={t("外观")}
          subtitle={t("选择颜色主题与显示模式。")}
          onBack={onBack}
        />
        <SectionTitle title={t("颜色主题")} />
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
              <strong>{themeTitle(theme, locale)}</strong>
              {settings.theme === theme && <Check />}
            </button>
          ))}
        </div>
        <SectionTitle title={t("显示模式")} />
        <section className="segmented-setting">
          <button
            className={!settings.dark ? "selected" : ""}
            type="button"
            onClick={() => onChange({ ...settings, dark: false })}
          >
            <Sun />
            {t("浅色")}
          </button>
          <button
            className={settings.dark ? "selected" : ""}
            type="button"
            onClick={() => onChange({ ...settings, dark: true })}
          >
            <Moon />
            {t("深色")}
          </button>
        </section>
      </div>
    );
  }

  if (section === "language") {
    return (
      <div className="screen scroll-screen">
        <ScreenHeader title={t("语言")} onBack={onBack} />
        <section className="settings-radio-list language-settings-list">
          {demoLocales.map((item) => (
            <button
              type="button"
              key={item}
              onClick={() => onLocaleChange(item)}
            >
              <span>{localeLabel(item, locale)}</span>
              {locale === item ? <CheckCircle2 /> : <Circle />}
            </button>
          ))}
        </section>
      </div>
    );
  }

  return (
    <div className="screen scroll-screen">
      <ScreenHeader
        title={t("任务显示")}
        subtitle={t("控制任务列表的外观与排序。")}
        onBack={onBack}
      />
      <SectionTitle title={t("列表密度")} />
      <section className="segmented-setting">
        {(["comfortable", "compact"] as Density[]).map((density) => (
          <button
            className={settings.density === density ? "selected" : ""}
            type="button"
            key={density}
            onClick={() => onChange({ ...settings, density })}
          >
            {density === "comfortable" ? <LayoutGrid /> : <Menu />}
            {density === "comfortable" ? t("舒适") : t("紧凑")}
          </button>
        ))}
      </section>
      <SectionTitle title={t("排序")} />
      <section className="settings-radio-list">
        {(
          [
            ["smart", t("智能排序")],
            ["deadline", t("截止日期")],
            ["priority", t("优先级")],
            ["title", t("标题")],
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
      <SectionTitle title={t("内容")} />
      <section className="toggle-list">
        <ToggleRow
          title={t("显示已完成任务")}
          checked={settings.showCompleted}
          onChange={(showCompleted) => onChange({ ...settings, showCompleted })}
        />
        <ToggleRow
          title={t("显示进度百分比")}
          checked={settings.showPercentage}
          onChange={(showPercentage) => onChange({ ...settings, showPercentage })}
        />
        <ToggleRow
          title={t("显示备注")}
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
  const { locale, t } = useDemoCopy();
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
      <ScreenHeader title={t("任务详情")} onBack={onBack} />
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
        <DetailLine icon={LayoutGrid} title={t("类型")} value={t(meta.title)} />
        <DetailLine
          icon={CalendarDays}
          title={t("截止日期")}
          value={formatDay(task.deadline, locale, true)}
        />
        <DetailLine
          icon={Clock3}
          title={t("计划完成")}
          value={
            task.plannedDate
              ? formatDay(task.plannedDate, locale, true)
              : t("未安排")
          }
        />
        <DetailLine
          icon={Bell}
          title={t("提醒")}
          value={t("提前 1 天 · 当天")}
        />
      </section>

      <SectionTitle title={t("进度")} />
      <section className="detail-progress">
        {task.progressKind === "percentage" ? (
          <>
            <div>
              <span>{t("完成度")}</span>
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
                  <span>{t(stage)}</span>
                </button>
              );
            })}
          </div>
        )}
      </section>

      <SectionTitle title={t("备注")} />
      <section className="notes-panel">
        {task.notes ? t(task.notes) : t("暂无备注")}
      </section>

      <button
        className="primary-button full"
        type="button"
        onClick={() => onChange({ ...task, completed: !task.completed })}
      >
        {task.completed ? <RotateCcw /> : <CheckCircle2 />}
        {task.completed ? t("重新打开任务") : t("标记为已完成")}
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
  const { locale, t } = useDemoCopy();
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
        title={t("今天")}
        subtitle={new Intl.DateTimeFormat(dateLocale(locale), {
          dateStyle: "full",
        }).format(new Date())}
        onBack={onBack}
      />
      {empty && (
        <div className="simple-empty">
          <Sun />
          <strong>{t("今天没有安排")}</strong>
        </div>
      )}
      <PlanningGroup title={t("逾期")} tasks={overdue} onOpenTask={onOpenTask} />
      <PlanningGroup
        title={t("今天截止")}
        tasks={due}
        onOpenTask={onOpenTask}
      />
      <PlanningGroup
        title={t("计划今天完成")}
        tasks={planned}
        onOpenTask={onOpenTask}
      />
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
  const { locale, t } = useDemoCopy();
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
        title={t("本周")}
        subtitle={
          busiest?.count
            ? locale === "en"
              ? `Busiest: ${formatDay(busiest.day, locale, true)} · ${busiest.count} tasks`
              : locale === "ja"
                ? `最多：${formatDay(busiest.day, locale, true)}・${busiest.count}件`
                : `最忙：${formatDay(busiest.day, locale, true)} · ${busiest.count} 项任务`
            : t("本周还没有安排")
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
              <h3>{formatDay(day, locale, true)}</h3>
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
                <p>{t("无安排")}</p>
              )}
            </section>
          );
        })}
      </div>
      {unscheduled.length > 0 && (
        <PlanningGroup
          title={`${t("未安排任务")} · ${unscheduled.length}`}
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
  curriculum,
  onClose,
  onSave,
}: {
  curriculum: Curriculum;
  onClose: () => void;
  onSave: (task: PlanoraItem) => void;
}) {
  const { t } = useDemoCopy();
  const subjects =
    curriculum === "ib"
      ? ["Physics HL", "Mathematics AA HL", "English B HL", "TOK", "CAS"]
      : [
          "Mathematics",
          "English as a Second Language",
          "Physics",
          "Chemistry",
          "Biology",
        ];
  const [mode, setMode] = useState<"select" | "quick" | "full">("select");
  const [type, setType] = useState<TaskType>("assignment");
  const [title, setTitle] = useState("");
  const [subject, setSubject] = useState(subjects[0]);
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
    setTitle(t(taskMeta[nextType].title));
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
      stage: t(taskMeta[type].defaultStage),
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
        <h2>
          {mode === "select"
            ? t("新建任务")
            : mode === "quick"
              ? t("快速新建")
              : t(taskMeta[type].title)}
        </h2>
        <button
          className="icon-button"
          type="button"
          onClick={onClose}
          aria-label={t("关闭")}
        >
          <X />
        </button>
      </div>

      {mode === "select" ? (
        <div className="create-content scroll-screen">
          <button className="quick-create-card" type="button" onClick={() => setMode("quick")}>
            <span><Sparkles /></span>
            <div>
              <strong>{t("快速新建")}</strong>
              <small>{t("只填写标题、科目和日期。")}</small>
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
                  <strong>{t(meta.title)}</strong>
                </button>
              );
            })}
          </div>
        </div>
      ) : (
        <div className="create-content scroll-screen">
          <section className="form-panel">
            <FormField label={t("标题")}>
              <input
                value={title}
                onChange={(event) => setTitle(event.target.value)}
                placeholder={t("任务名称")}
              />
            </FormField>
            <FormField label={t("科目")}>
              <select value={subject} onChange={(event) => setSubject(event.target.value)}>
                {subjects.map((item) => (
                  <option key={item}>{item}</option>
                ))}
              </select>
            </FormField>
            <ToggleRow
              title={t("截止日期")}
              checked={hasDeadline}
              onChange={setHasDeadline}
            />
            {hasDeadline && (
              <FormField label={t("日期")}>
                <input type="date" value={deadline} onChange={(event) => setDeadline(event.target.value)} />
              </FormField>
            )}
            <FormField label={t("计划完成日期")}>
              <input type="date" value={plannedDate} onChange={(event) => setPlannedDate(event.target.value)} />
            </FormField>
            {mode === "full" && (
              <>
                <FormField label={t("优先级")}>
                  <div className="segmented-inline">
                    {(["low", "medium", "high"] as Priority[]).map((item) => (
                      <button
                        type="button"
                        key={item}
                        className={priority === item ? "selected" : ""}
                        onClick={() => setPriority(item)}
                      >
                        {t(priorities[item].title)}
                      </button>
                    ))}
                  </div>
                </FormField>
                <FormField label={t("进度方式")}>
                  <div className="segmented-inline">
                    <button
                      type="button"
                      className={progressKind === "percentage" ? "selected" : ""}
                      onClick={() => setProgressKind("percentage")}
                    >
                      {t("百分比")}
                    </button>
                    <button
                      type="button"
                      className={progressKind === "stage" ? "selected" : ""}
                      onClick={() => setProgressKind("stage")}
                    >
                      {t("阶段")}
                    </button>
                  </div>
                </FormField>
                <ToggleRow
                  title={t("重复任务")}
                  checked={recurring}
                  onChange={setRecurring}
                />
                <FormField label={t("备注")}>
                  <textarea value={notes} onChange={(event) => setNotes(event.target.value)} rows={3} />
                </FormField>
              </>
            )}
          </section>
          <button className="primary-button full" type="button" onClick={save} disabled={!title.trim()}>
            <Check />
            {t("保存任务")}
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
  const { t } = useDemoCopy();
  const tabs: { id: Tab; title: string; icon: LucideIcon }[] = [
    { id: "home", title: t("首页"), icon: Home },
    { id: "tasks", title: t("任务"), icon: ListChecks },
    { id: "profile", title: t("我的"), icon: UserRound },
    { id: "search", title: t("搜索"), icon: Search },
  ];
  return (
    <div className="tab-bar">
      <nav className="tab-cluster" aria-label={t("主导航")}>
        {tabs.map((item) => (
          <TabButton
            key={item.id}
            item={item}
            active={active}
            onSelect={onSelect}
          />
        ))}
      </nav>
      <button
        className="create-tab"
        type="button"
        onClick={onCreate}
        aria-label={t("新建任务")}
      >
        <Plus />
      </button>
    </div>
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
  const { locale } = useDemoCopy();
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
              <span>
                {new Intl.DateTimeFormat(dateLocale(locale), {
                  weekday: "short",
                }).format(date)}
              </span>
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
              <small>
                {formatDay(task.plannedDate ?? task.deadline, locale)}
              </small>
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
  const { t } = useDemoCopy();
  return (
    <span className={`priority priority-${priority} ${compact ? "compact" : ""}`}>
      {priority === "high" && "!"}
      {!compact && t(priorities[priority].title)}
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

function themeTitle(theme: Theme, locale: DemoLocale) {
  const source = {
    classic: "经典",
    ocean: "海洋",
    forest: "森林",
    sunset: "日落",
  }[theme];
  return copy(locale, source);
}
