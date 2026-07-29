"use client";

import {
  BadgeCheck,
  Bell,
  BookMarked,
  BookOpen,
  CalendarDays,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronsUpDown,
  Circle,
  CircleAlert,
  CircleUserRound,
  Clock3,
  FileSearch,
  Flag,
  FlaskConical,
  Gauge,
  Globe2,
  HardDrive,
  HeartHandshake,
  Home,
  LayoutGrid,
  Lightbulb,
  ListChecks,
  Menu,
  Mic,
  Moon,
  Palette,
  Plus,
  RotateCcw,
  Search,
  Settings,
  Settings2,
  Share2,
  Sparkles,
  Sun,
  TestTube2,
  Download,
  Upload,
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
  type CSSProperties,
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
type DisplayMode = "system" | "light" | "dark";
type BackgroundStyle = "sky" | "ocean" | "mint" | "rose";
type AccentColor = "blue" | "green" | "amber" | "pink";
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
      section: "home" | "appearance" | "display";
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
  displayMode: DisplayMode;
  background: BackgroundStyle;
  accent: AccentColor;
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
const deviceWidth = 422;
const deviceHeight = 894;
const defaultDeviceScale = 0.78;

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
    icon: BookMarked,
    color: "blue",
    defaultStage: "进行中",
  },
  practical: {
    title: "实验实践",
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
    icon: BadgeCheck,
    color: "purple",
    defaultStage: "复习中",
  },
  event: {
    title: "事件",
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
  displayMode: "system",
  background: "sky",
  accent: "green",
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

function seedTasks(curriculum: Curriculum = "igcse"): PlanoraItem[] {
  if (curriculum === "igcse") {
    return [
      {
        id: "igcse-english-coursework",
        title: "English Coursework Draft",
        subject: "English as a Second Language",
        type: "assignment",
        priority: "high",
        deadline: offsetISO(2),
        plannedDate: offsetISO(0),
        progressKind: "percentage",
        progress: 65,
        stage: "进行中",
        notes: "完成论点段落并核对引用格式。",
        completed: false,
        recurring: false,
      },
      {
        id: "igcse-math-assignment",
        title: "Algebra Problem Set",
        subject: "Mathematics",
        type: "assignment",
        priority: "high",
        deadline: offsetISO(1),
        plannedDate: offsetISO(0),
        progressKind: "percentage",
        progress: 35,
        stage: "进行中",
        notes: "完成二次函数与不等式练习。",
        completed: false,
        recurring: false,
      },
      {
        id: "igcse-physics-practical",
        title: "Physics Practical Report",
        subject: "Physics",
        type: "practical",
        priority: "medium",
        deadline: offsetISO(7),
        plannedDate: offsetISO(3),
        progressKind: "stage",
        progress: 45,
        stage: "Data Collection",
        notes: "整理实验数据并完成误差分析。",
        completed: false,
        recurring: false,
      },
      {
        id: "igcse-chemistry-revision",
        title: "Weekly Chemistry Revision",
        subject: "Chemistry",
        type: "revision",
        priority: "medium",
        deadline: offsetISO(5),
        plannedDate: offsetISO(2),
        progressKind: "percentage",
        progress: 20,
        stage: "第一轮",
        notes: "复习化学计量并完成一组真题。",
        completed: false,
        recurring: true,
      },
      {
        id: "igcse-biology-exam",
        title: "Biology Mock Exam",
        subject: "Biology",
        type: "exam",
        priority: "low",
        deadline: offsetISO(14),
        progressKind: "stage",
        progress: 0,
        stage: "复习中",
        notes: "覆盖细胞、生物运输与遗传。",
        completed: false,
        recurring: false,
      },
    ];
  }

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

function taskTracksProgress(task: PlanoraItem) {
  return !["exam", "event", "custom"].includes(task.type);
}

function fallsInCurrentWeek(value?: string) {
  if (!value) return false;

  const date = new Date(`${value}T12:00:00`);
  const today = new Date();
  const daysSinceMonday = (today.getDay() + 6) % 7;
  const weekStart = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate() - daysSinceMonday,
    0,
    0,
    0,
    0,
  );
  const weekEnd = new Date(weekStart.getTime() + 7 * dayMs);
  return date >= weekStart && date < weekEnd;
}

export function PlanoraDemo() {
  const [tasks, setTasks] = useState<PlanoraItem[]>(() =>
    seedTasks("igcse"),
  );
  const [settings, setSettings] = useState<DemoSettings>(defaultSettings);
  const [tab, setTab] = useState<Tab>("home");
  const [screen, setScreen] = useState<Screen>({ kind: "tab" });
  const [locale, setLocale] = useState<DemoLocale>("zh-Hans");
  const [curriculum, setCurriculum] = useState<Curriculum>("igcse");
  const [introComplete, setIntroComplete] = useState(false);
  const [hydrated, setHydrated] = useState(false);
  const [deviceScale, setDeviceScale] = useState(defaultDeviceScale);
  const [systemDark, setSystemDark] = useState(false);

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
    function updateDeviceScale() {
      const narrowLayout = window.innerWidth <= 820;
      const availableWidth = narrowLayout
        ? Math.max(280, window.innerWidth - 28)
        : 440;
      const availableHeight = narrowLayout
        ? Number.POSITIVE_INFINITY
        : Math.max(560, window.innerHeight - 28);
      const nextScale = Math.min(
        1,
        availableWidth / deviceWidth,
        availableHeight / deviceHeight,
      );
      setDeviceScale(Math.max(0.62, nextScale));
    }

    updateDeviceScale();
    window.addEventListener("resize", updateDeviceScale, { passive: true });
    return () => window.removeEventListener("resize", updateDeviceScale);
  }, []);

  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const update = () => setSystemDark(media.matches);
    update();
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
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
    const nextTasks = seedTasks(curriculum);
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
  const effectiveDark =
    settings.displayMode === "system"
      ? systemDark
      : settings.displayMode === "dark";
  const deviceStageStyle = {
    "--device-scale": deviceScale,
    "--device-stage-width": `${deviceWidth * deviceScale}px`,
    "--device-stage-height": `${deviceHeight * deviceScale}px`,
  } as CSSProperties;

  return (
    <LocaleContext.Provider value={locale}>
      <main
        lang={locale}
        className={`showcase theme-${settings.theme} background-${settings.background} accent-${settings.accent} ${
          effectiveDark ? "is-dark" : ""
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
          style={deviceStageStyle}
        >
          <div className="device">
            <div className="device-speaker" aria-hidden="true" />
            <div className="device-screen">
              <StatusBar dark={effectiveDark} />
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
                        curriculum={curriculum}
                        onCurriculumChange={(nextCurriculum) => {
                          setCurriculum(nextCurriculum);
                          setTasks(seedTasks(nextCurriculum));
                        }}
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
                        curriculum={curriculum}
                        onOpenSettings={(section) =>
                          setScreen({ kind: "settings", section })
                        }
                      />
                    )}
                    {screen.kind === "task" && activeTask && (
                      <TaskDetailScreen
                        task={activeTask}
                        onBack={() => setScreen({ kind: "tab" })}
                        onChange={updateTask}
                        onDelete={() => {
                          setTasks((current) =>
                            current.filter((task) => task.id !== activeTask.id),
                          );
                          setScreen({ kind: "tab" });
                        }}
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
                        onNavigate={(section) =>
                          setScreen({ kind: "settings", section })
                        }
                        onBack={() =>
                          screen.section === "home"
                            ? setScreen({ kind: "tab" })
                            : setScreen({
                                kind: "settings",
                                section: "home",
                              })
                        }
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
}: {
  title: string;
  subtitle?: string;
}) {
  return (
    <header className="screen-header">
      <div>
        <h2>{title}</h2>
        {subtitle && <p>{subtitle}</p>}
      </div>
    </header>
  );
}

function DetailNavigationBar({
  title,
  onBack,
  actionTitle,
  onAction,
}: {
  title: string;
  onBack: () => void;
  actionTitle?: string;
  onAction?: () => void;
}) {
  const { t } = useDemoCopy();
  return (
    <header className="detail-navigation">
      <button
        className="icon-button back-button"
        type="button"
        onClick={onBack}
        aria-label={t("返回")}
      >
        <ChevronLeft />
      </button>
      <strong>{title}</strong>
      {actionTitle ? (
        <button className="navigation-action" type="button" onClick={onAction}>
          {actionTitle}
        </button>
      ) : (
        <span aria-hidden="true" />
      )}
    </header>
  );
}

function PageHeading({
  title,
  subtitle,
}: {
  title: string;
  subtitle?: string;
}) {
  return (
    <div className="page-heading">
      <h2>{title}</h2>
      {subtitle && <p>{subtitle}</p>}
    </div>
  );
}

function HomeScreen({
  tasks,
  curriculum,
  onCurriculumChange,
  onOpenTask,
  onToggleTask,
  onOpenToday,
  onOpenWeek,
  onCreate,
}: {
  tasks: PlanoraItem[];
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
  const upcomingProgressTasks = openTasks
    .filter(taskTracksProgress)
    .slice(0, 4);
  const upcomingTimelineItems = openTasks
    .filter((task) => !taskTracksProgress(task))
    .slice(0, 4);
  const subjectProgress = Object.entries(
    tasks.filter(taskTracksProgress).reduce<
      Record<string, { values: number[]; color: string }>
    >((groups, task) => {
      groups[task.subject] ??= {
        values: [],
        color: taskMeta[task.type].color,
      };
      groups[task.subject].values.push(task.completed ? 100 : task.progress);
      return groups;
    }, {}),
  )
    .map(([subject, group]) => ({
      subject,
      value: Math.round(
        group.values.reduce((sum, value) => sum + value, 0) /
          group.values.length,
      ),
      color: group.color,
    }))
    .sort((a, b) => a.subject.localeCompare(b.subject));
  const weeklyTasks = tasks.filter((task) =>
    fallsInCurrentWeek(task.deadline ?? localISO(new Date())),
  );
  const completedThisWeek = weeklyTasks.filter((task) => task.completed).length;
  const subjectActivity = tasks.reduce<Record<string, number>>(
    (counts, task) => {
      if (!task.completed || weeklyTasks.includes(task)) {
        counts[task.subject] = (counts[task.subject] ?? 0) + 1;
      }
      return counts;
    },
    {},
  );
  const mostActiveSubject =
    Object.entries(subjectActivity).sort(
      (a, b) => b[1] - a[1] || a[0].localeCompare(b[0]),
    )[0]?.[0] ?? t("暂无");
  const upcomingSevenDayCount = openTasks.filter((task) => {
    const days = daysUntil(task.deadline);
    return days !== null && days >= 0 && days < 7;
  }).length;
  const overdueCount = openTasks.filter(
    (task) => (daysUntil(task.deadline) ?? 0) < 0,
  ).length;
  const workload =
    upcomingSevenDayCount <= 2
      ? { label: t("低"), color: "green" }
      : upcomingSevenDayCount <= 5
        ? { label: t("中等"), color: "amber" }
        : { label: t("高"), color: "red" };
  const shortItemCount =
    locale === "en"
      ? `${upcomingSevenDayCount} ${
          upcomingSevenDayCount === 1 ? "item" : "items"
        }`
      : locale === "ja"
        ? `${upcomingSevenDayCount}件`
        : `${upcomingSevenDayCount} 项`;

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
                  {taskTracksProgress(focus)
                    ? focus.progressKind === "stage"
                      ? t("阶段")
                      : t("进度")
                    : t("类型")}
                </span>
                <strong>
                  {taskTracksProgress(focus)
                    ? focus.progressKind === "stage"
                      ? t(focus.stage)
                      : `${focus.progress}%`
                    : t(taskMeta[focus.type].title)}
                </strong>
              </div>
            </div>
          </section>

          {upcomingProgressTasks.length > 0 && (
            <>
              <SectionTitle title={t("即将到来的任务")} />
              <HomeTaskList
                tasks={upcomingProgressTasks}
                onOpenTask={onOpenTask}
                onToggleTask={onToggleTask}
              />
            </>
          )}

          {upcomingTimelineItems.length > 0 && (
            <>
              <SectionTitle title={t("时间与事件")} />
              <HomeTaskList
                tasks={upcomingTimelineItems}
                onOpenTask={onOpenTask}
                onToggleTask={onToggleTask}
              />
            </>
          )}

          <SectionTitle title={t("学习进度")} />
          <section className="plain-section learning-progress-panel">
            {subjectProgress.length > 0 && (
              <>
                <p className="progress-group-title">{t("科目进度")}</p>
                <div className="learning-subjects">
                  {subjectProgress.map((subject) => (
                    <div className="subject-progress" key={subject.subject}>
                      <div>
                        <span>{subject.subject}</span>
                        <strong className={`tone-${subject.color}`}>
                          {subject.value}%
                        </strong>
                      </div>
                      <ProgressBar
                        value={subject.value}
                        color={subject.color}
                      />
                    </div>
                  ))}
                </div>
                <hr className="learning-divider" />
              </>
            )}

            <p className="progress-group-title">{t("任务完成")}</p>
            <div className="task-completion-row">
              <div>
                <span>{t("本周")}</span>
                <strong>
                  {completedThisWeek} / {weeklyTasks.length}
                </strong>
              </div>
              <ProgressBar
                value={
                  weeklyTasks.length
                    ? (completedThisWeek / weeklyTasks.length) * 100
                    : 0
                }
                color="green"
              />
            </div>

            <hr className="learning-divider" />

            <div className="learning-insights-grid">
              <LearningInsight
                icon={CheckCircle2}
                value={`${completedThisWeek}`}
                label={t("本周完成")}
                color="green"
              />
              <LearningInsight
                icon={BookOpen}
                value={mostActiveSubject}
                label={t("最活跃科目")}
                color="blue"
              />
              <LearningInsight
                icon={CalendarDays}
                value={`${workload.label} · ${shortItemCount}`}
                label={t("未来任务负载")}
                color={workload.color}
              />
              <LearningInsight
                icon={CircleAlert}
                value={`${overdueCount}`}
                label={t("已逾期")}
                color={overdueCount > 0 ? "red" : "green"}
              />
            </div>
          </section>

          {tasks.some((task) => task.deadline) && (
            <>
              <SectionTitle title={t("日历预览")} />
              <MiniCalendar tasks={tasks} onOpenTask={onOpenTask} />
            </>
          )}
        </>
      )}
    </div>
  );
}

function HomeTaskList({
  tasks,
  onOpenTask,
  onToggleTask,
}: {
  tasks: PlanoraItem[];
  onOpenTask: (taskId: string) => void;
  onToggleTask: (task: PlanoraItem) => void;
}) {
  return (
    <div className="home-task-list">
      {tasks.map((task) => (
        <HomeTaskRow
          key={task.id}
          task={task}
          onOpen={() => onOpenTask(task.id)}
          onToggle={() => onToggleTask(task)}
        />
      ))}
    </div>
  );
}

function HomeTaskRow({
  task,
  onOpen,
  onToggle,
}: {
  task: PlanoraItem;
  onOpen: () => void;
  onToggle: () => void;
}) {
  const { locale, t } = useDemoCopy();
  const meta = taskMeta[task.type];
  const tracksProgress = taskTracksProgress(task);

  return (
    <article
      className="home-task-row"
      onClick={onOpen}
      onKeyDown={(event) => {
        if (event.key === "Enter") onOpen();
      }}
      role="button"
      tabIndex={0}
    >
      <div className="home-task-heading">
        <button
          className="home-task-complete"
          type="button"
          aria-label={t("完成任务")}
          onClick={(event) => {
            event.stopPropagation();
            onToggle();
          }}
        >
          <Circle />
        </button>

        <span className={`home-task-icon tone-${meta.color}`}>
          <FileSearch />
        </span>

        <span className="home-task-copy">
          <strong>{task.title}</strong>
          <small>{task.subject}</small>
        </span>

        <span className="home-task-actions">
          <PriorityBadge priority={task.priority} />
          <ChevronRight aria-hidden="true" />
        </span>
      </div>

      <div className="home-task-status">
        <span>
          <small>{t("截止日期")}</small>
          <strong>{formatDay(task.deadline, locale)}</strong>
        </span>
        <span>
          <small>
            {tracksProgress
              ? task.progressKind === "stage"
                ? t("阶段")
                : t("进度")
              : t("类型")}
          </small>
          <strong className={`tone-${meta.color}`}>
            {tracksProgress
              ? task.progressKind === "stage"
                ? stageTitle(task.stage, locale)
                : `${task.progress}%`
              : t(meta.title)}
          </strong>
        </span>
      </div>

      {tracksProgress && task.progressKind === "percentage" && (
        <ProgressBar value={task.progress} color={meta.color} />
      )}
    </article>
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
}: {
  tasks: PlanoraItem[];
  settings: DemoSettings;
  onOpenTask: (taskId: string) => void;
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
}: {
  task: PlanoraItem;
  density: Density;
  showPercentage: boolean;
  showNotes: boolean;
  onOpen: () => void;
}) {
  const { locale, t } = useDemoCopy();
  const meta = taskMeta[task.type];
  const Icon = meta.icon;
  return (
    <article
      className={`task-row ${task.completed ? "is-complete" : ""} ${density}`}
      onClick={onOpen}
      onKeyDown={(event) => {
        if (event.key === "Enter") onOpen();
      }}
      role="button"
      tabIndex={0}
    >
      <div className="task-row-heading">
        <div className={`task-icon tone-${meta.color}`}>
          <Icon />
        </div>
        <div className="task-copy">
          <h3>{task.title}</h3>
          <p>{task.subject}</p>
        </div>
        <div className="task-side">
          <span className={`type-pill tone-${meta.color}`}>
            {t(meta.title)}
          </span>
          <PriorityBadge priority={task.priority} compact />
        </div>
      </div>
      <div className="task-metrics">
        <span>
          <small>{t("完成时间")}</small>
          <strong>{formatDay(task.deadline, locale)}</strong>
        </span>
        <span>
          <small>
            {task.progressKind === "percentage" && showPercentage
              ? t("进度")
              : t("类型")}
          </small>
          <strong className={`tone-${meta.color}`}>
            {task.progressKind === "percentage" && showPercentage
              ? `${task.progress}%`
              : task.progressKind === "stage"
                ? stageTitle(task.stage, locale)
                : t(meta.title)}
          </strong>
        </span>
      </div>
      {showNotes && density === "comfortable" && task.notes && (
        <p className="task-note">{t(task.notes)}</p>
      )}
    </article>
  );
}

function SearchResultRow({
  task,
  onOpen,
}: {
  task: PlanoraItem;
  onOpen: () => void;
}) {
  const { locale, t } = useDemoCopy();
  const meta = taskMeta[task.type];
  const Icon = meta.icon;
  return (
    <article
      className="search-result-row"
      onClick={onOpen}
      onKeyDown={(event) => {
        if (event.key === "Enter") onOpen();
      }}
      role="button"
      tabIndex={0}
    >
      <div className="search-result-heading">
        <span className={`task-icon tone-${meta.color}`}>
          <Icon />
        </span>
        <span className="search-result-copy">
          <strong>{task.title}</strong>
          <small>{task.subject}</small>
        </span>
        <PriorityBadge priority={task.priority} compact />
        <ChevronRight aria-hidden="true" />
      </div>
      <div className="search-result-metrics">
        <span>
          <small>{t("截止日期")}</small>
          <strong>{formatDay(task.deadline, locale)}</strong>
        </span>
        <span>
          <small>{taskTracksProgress(task) ? t("进度") : t("类型")}</small>
          <strong>
            {taskTracksProgress(task)
              ? task.progressKind === "stage"
                ? stageTitle(task.stage, locale)
                : `${task.progress}%`
              : t(meta.title)}
          </strong>
        </span>
      </div>
      {task.notes && <p>{t(task.notes)}</p>}
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
  const [deadline, setDeadline] = useState("all");
  const [status, setStatus] = useState("all");
  const [priority, setPriority] = useState("all");
  const [searchFocused, setSearchFocused] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const subjects = [...new Set(tasks.map((task) => task.subject))];

  const results = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase();
    return sortTasks(
      tasks.filter((task) => {
        if (subject !== "all" && task.subject !== subject) return false;
        if (type !== "all" && task.type !== type) return false;
        if (priority !== "all" && task.priority !== priority) return false;
        if (status === "open" && task.completed) return false;
        if (status === "completed" && !task.completed) return false;
        const remaining = daysUntil(task.deadline);
        if (deadline === "overdue" && !(remaining !== null && remaining < 0))
          return false;
        if (deadline === "today" && remaining !== 0) return false;
        if (
          deadline === "week" &&
          !(remaining !== null && remaining >= 0 && remaining < 7)
        )
          return false;
        if (deadline === "none" && task.deadline) return false;
        if (!normalized) return true;
        return [task.title, task.subject, task.notes, task.stage]
          .join(" ")
          .toLocaleLowerCase()
          .includes(normalized);
      }),
      "smart",
    );
  }, [deadline, priority, query, status, subject, tasks, type]);

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
            onFocus={() => setSearchFocused(true)}
            onBlur={() => setSearchFocused(false)}
            placeholder={t("搜索")}
            inputMode="search"
          />
          <span className="search-microphone" aria-hidden="true">
            <Mic />
          </span>
        </label>
        {searchFocused && (
          <button
            className="search-close"
            type="button"
            onMouseDown={(event) => event.preventDefault()}
            onClick={() => {
              inputRef.current?.blur();
              setSearchFocused(false);
            }}
            aria-label={t("收起键盘")}
          >
            <X />
          </button>
        )}
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
          icon={CalendarDays}
          value={deadline}
          onChange={setDeadline}
          options={[
            ["all", t("截止日期")],
            ["overdue", t("逾期")],
            ["today", t("今天")],
            ["week", t("未来七天")],
            ["none", t("无截止日期")],
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
        <FilterSelect
          icon={Flag}
          value={priority}
          onChange={setPriority}
          options={[
            ["all", t("优先级")],
            ["high", t("高")],
            ["medium", t("中")],
            ["low", t("低")],
          ]}
        />
      </div>
      <SectionTitle
        title={query ? t("搜索结果") : t("所有项目")}
        value={`${results.length}`}
      />
      <div className="search-results search-result-panel">
        {results.map((task) => (
          <SearchResultRow
            key={task.id}
            task={task}
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
  curriculum,
  onOpenSettings,
}: {
  tasks: PlanoraItem[];
  curriculum: Curriculum;
  onOpenSettings: (
    section: "home" | "appearance" | "display",
  ) => void;
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

      <SectionTitle title={t("个人资料")} />
      <section className="settings-list">
        <SettingsRow
          icon={CircleUserRound}
          title={t("姓名")}
          value="Mitty"
          onClick={() => undefined}
        />
        <SettingsRow
          icon={BookOpen}
          title={t("课程体系")}
          value={curriculum.toUpperCase()}
          onClick={() => undefined}
        />
        <SettingsRow
          icon={BookMarked}
          title={t("我的科目")}
          value={`${subjects.length}`}
          onClick={() => undefined}
        />
        <SettingsRow
          icon={Settings}
          title={t("设置")}
          value=""
          onClick={() => onOpenSettings("home")}
        />
      </section>

      <SectionTitle title={t("任务存储")} />
      <section className="backup-card">
        <div className="backup-heading">
          <span className="backup-drive-icon">
            <HardDrive />
          </span>
          <div>
            <strong>{t("任务备份")}</strong>
            <span>{backupTaskCount(tasks.length, locale)}</span>
          </div>
        </div>

        <p>{t("保存为 JSON 备份文件，或导入并选择如何处理重复任务。")}</p>

        <div className="backup-share-hint">
          <Share2 />
          <span>
            {t(
              "也可以把 JSON 文件直接通过系统分享给 Planora，App 会自动打开并导入 JSON 备份。",
            )}
          </span>
        </div>

        <div className="backup-actions">
          <button type="button">
            <Download />
            <span>{t("保存备份")}</span>
          </button>
          <button type="button">
            <Upload />
            <span>{t("导入备份")}</span>
          </button>
        </div>

        <button className="backup-restore" type="button" disabled>
          <RotateCcw />
          <span>{t("恢复最近自动备份")}</span>
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

function backupTaskCount(count: number, locale: DemoLocale) {
  if (locale === "en")
    return `${count} tasks currently available for backup`;
  if (locale === "ja") return `現在 ${count} 件のタスクをバックアップできます`;
  return `当前有 ${count} 项任务可备份`;
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
  onNavigate,
  onBack,
}: {
  section: "home" | "appearance" | "display";
  settings: DemoSettings;
  locale: DemoLocale;
  onChange: (settings: DemoSettings) => void;
  onNavigate: (section: "home" | "appearance" | "display") => void;
  onBack: () => void;
}) {
  const { t } = useDemoCopy();
  if (section === "home") {
    return (
      <div className="screen scroll-screen detail-page">
        <DetailNavigationBar title="" onBack={onBack} />
        <PageHeading
          title={t("设置")}
          subtitle={t("调整 Planora 的显示方式和任务列表偏好。")}
        />
        <SectionTitle title={t("偏好设置")} />
        <section className="settings-list">
          <SettingsRow
            icon={Palette}
            title={t("外观")}
            value={`${displayModeTitle(settings.displayMode, locale)} · ${backgroundTitle(settings.background, locale)}`}
            onClick={() => onNavigate("appearance")}
          />
          <SettingsRow
            icon={Settings2}
            title={t("任务显示")}
            value={`${settings.density === "comfortable" ? t("舒适") : t("紧凑")} · ${sortOrderTitle(settings.sortOrder, locale)}`}
            onClick={() => onNavigate("display")}
          />
        </section>
      </div>
    );
  }

  if (section === "appearance") {
    return (
      <div className="screen scroll-screen detail-page">
        <DetailNavigationBar title="" onBack={onBack} />
        <PageHeading
          title={t("外观")}
          subtitle={t("调整 Planora 在这台设备上的显示方式。")}
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
          {(["system", "light", "dark"] as DisplayMode[]).map((mode) => (
            <button
              className={settings.displayMode === mode ? "selected" : ""}
              type="button"
              key={mode}
              onClick={() =>
                onChange({
                  ...settings,
                  displayMode: mode,
                  dark: mode === "dark",
                })
              }
            >
              {mode === "system" ? <Settings2 /> : mode === "light" ? <Sun /> : <Moon />}
              {displayModeTitle(mode, locale)}
            </button>
          ))}
        </section>
        <SectionTitle title={t("背景")} />
        <div className="background-grid">
          {(["sky", "ocean", "mint", "rose"] as BackgroundStyle[]).map(
            (background) => (
              <button
                type="button"
                key={background}
                className={`background-option background-preview-${background} ${
                  settings.background === background ? "selected" : ""
                }`}
                onClick={() => onChange({ ...settings, background })}
              >
                <span />
                <strong>{backgroundTitle(background, locale)}</strong>
                {settings.background === background && <Check />}
              </button>
            ),
          )}
        </div>
        <SectionTitle title={t("强调色")} />
        <section className="accent-options">
          {(["blue", "green", "amber", "pink"] as AccentColor[]).map(
            (accent) => (
              <button
                type="button"
                key={accent}
                className={`accent-${accent} ${
                  settings.accent === accent ? "selected" : ""
                }`}
                onClick={() => onChange({ ...settings, accent })}
                aria-label={accentTitle(accent, locale)}
              >
                {settings.accent === accent && <Check />}
              </button>
            ),
          )}
        </section>
        <button
          className="reset-appearance-button"
          type="button"
          onClick={() =>
            onChange({
              ...settings,
              theme: defaultSettings.theme,
              dark: defaultSettings.dark,
              displayMode: defaultSettings.displayMode,
              background: defaultSettings.background,
              accent: defaultSettings.accent,
            })
          }
        >
          <RotateCcw />
          {t("恢复默认外观")}
        </button>
      </div>
    );
  }

  return (
    <div className="screen scroll-screen detail-page">
      <DetailNavigationBar title="" onBack={onBack} />
      <PageHeading
        title={t("任务显示")}
        subtitle={t("这些选项只改变任务列表，不会修改任务内容。")}
      />
      <SectionTitle title={t("任务外观")} />
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
      <label className="sort-select">
        <select
          aria-label={t("排序")}
          value={settings.sortOrder}
          onChange={(event) =>
            onChange({
              ...settings,
              sortOrder: event.target.value as SortOrder,
            })
          }
        >
          <option value="smart">{t("智能排序")}</option>
          <option value="deadline">{t("截止日期")}</option>
          <option value="priority">{t("优先级")}</option>
          <option value="title">{t("标题")}</option>
        </select>
        <ChevronsUpDown aria-hidden="true" />
      </label>
      <SectionTitle title={t("显示内容")} />
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
      <button
        className="reset-display-button"
        type="button"
        onClick={() =>
          onChange({
            ...settings,
            density: defaultSettings.density,
            sortOrder: defaultSettings.sortOrder,
            showCompleted: defaultSettings.showCompleted,
            showPercentage: defaultSettings.showPercentage,
            showNotes: defaultSettings.showNotes,
          })
        }
      >
        <RotateCcw />
        {t("恢复默认任务显示")}
      </button>
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
  onDelete,
}: {
  task: PlanoraItem;
  onBack: () => void;
  onChange: (task: PlanoraItem) => void;
  onDelete: () => void;
}) {
  const { locale, t } = useDemoCopy();
  const [editing, setEditing] = useState(false);
  const [confirmingDelete, setConfirmingDelete] = useState(false);
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
    <div className="screen scroll-screen detail-screen detail-page">
      <DetailNavigationBar
        title={t("任务详情")}
        actionTitle={editing ? t("完成") : t("编辑")}
        onAction={() => setEditing((value) => !value)}
        onBack={onBack}
      />
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
      {editing ? (
        <section className="form-panel detail-edit-panel">
          <FormField label={t("标题")}>
            <input
              value={task.title}
              onChange={(event) =>
                onChange({ ...task, title: event.target.value })
              }
            />
          </FormField>
          <FormField label={t("科目")}>
            <input
              value={task.subject}
              onChange={(event) =>
                onChange({ ...task, subject: event.target.value })
              }
            />
          </FormField>
          <FormField label={t("截止日期")}>
            <input
              type="date"
              value={task.deadline ?? ""}
              onChange={(event) =>
                onChange({ ...task, deadline: event.target.value || undefined })
              }
            />
          </FormField>
          <FormField label={t("计划完成日期")}>
            <input
              type="date"
              value={task.plannedDate ?? ""}
              onChange={(event) =>
                onChange({
                  ...task,
                  plannedDate: event.target.value || undefined,
                })
              }
            />
          </FormField>
          <FormField label={t("优先级")}>
            <div className="segmented-inline">
              {(["low", "medium", "high"] as Priority[]).map((priority) => (
                <button
                  type="button"
                  key={priority}
                  className={task.priority === priority ? "selected" : ""}
                  onClick={() => onChange({ ...task, priority })}
                >
                  {t(priorities[priority].title)}
                </button>
              ))}
            </div>
          </FormField>
          <FormField label={t("备注")}>
            <textarea
              rows={4}
              value={task.notes}
              onChange={(event) =>
                onChange({ ...task, notes: event.target.value })
              }
            />
          </FormField>
        </section>
      ) : (
        <>
          <section className="detail-list">
            <DetailLine icon={LayoutGrid} title={t("类型")} value={t(meta.title)} />
            <DetailLine
              icon={CalendarDays}
              title={t("截止日期")}
              value={formatDay(task.deadline, locale, true)}
            />
            <DetailLine
              icon={Clock3}
              title={t("计划完成日期")}
              value={
                task.plannedDate
                  ? formatDay(task.plannedDate, locale, true)
                  : t("未安排")
              }
            />
            <DetailLine
              icon={RotateCcw}
              title={t("重复")}
              value={task.recurring ? t("每周") : t("不重复")}
            />
            <DetailLine
              icon={Flag}
              title={t("优先级")}
              value={t(priorities[task.priority].title)}
            />
            <DetailLine
              icon={Bell}
              title={t("提醒")}
              value={t("提前 1 天 · 当天")}
              showsChevron
            />
            <DetailLine
              icon={Clock3}
              title={t("创建时间")}
              value={formatDay(offsetISO(-60), locale)}
            />
          </section>

          <section className="detail-progress">
            {task.progressKind === "percentage" ? (
              <>
                <div>
                  <span>
                    <strong>{t("学习进度")}</strong>
                    <small>{t("进度")}</small>
                  </span>
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
                          progress: Math.round(
                            ((index + 1) / stages.length) * 100,
                          ),
                        })
                      }
                    >
                      {done ? <CheckCircle2 /> : active ? <Gauge /> : <Circle />}
                      <span>{stageTitle(stage, locale)}</span>
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
          <button
            className={`delete-task-button ${confirmingDelete ? "confirming" : ""}`}
            type="button"
            onClick={() => {
              if (confirmingDelete) onDelete();
              else setConfirmingDelete(true);
            }}
          >
            {confirmingDelete ? t("再次点击确认删除") : t("删除任务")}
          </button>
        </>
      )}
    </div>
  );
}

function DetailLine({
  icon: Icon,
  title,
  value,
  showsChevron = false,
}: {
  icon: LucideIcon;
  title: string;
  value: string;
  showsChevron?: boolean;
}) {
  return (
    <div>
      <Icon />
      <span>{title}</span>
      <strong>{value}</strong>
      {showsChevron && <ChevronRight aria-hidden="true" />}
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
    <div className="screen scroll-screen detail-page">
      <DetailNavigationBar title={t("今天")} onBack={onBack} />
      <PageHeading
        title={t("今天")}
        subtitle={new Intl.DateTimeFormat(dateLocale(locale), {
          dateStyle: "full",
        }).format(new Date())}
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
    <div className="screen scroll-screen detail-page">
      <DetailNavigationBar title={t("本周")} onBack={onBack} />
      <PageHeading
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
                  <PlanningTaskRow
                    key={task.id}
                    task={task}
                    onClick={() => onOpenTask(task.id)}
                  />
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
          <PlanningTaskRow
            key={task.id}
            task={task}
            onClick={() => onOpenTask(task.id)}
          />
        ))}
      </div>
    </>
  );
}

function PlanningTaskRow({
  task,
  onClick,
}: {
  task: PlanoraItem;
  onClick: () => void;
}) {
  const { t } = useDemoCopy();
  const meta = taskMeta[task.type];
  return (
    <button
      className={`planning-task-row tone-${meta.color}`}
      type="button"
      onClick={onClick}
    >
      <Circle className="planning-complete-icon" />
      <span className="planning-task-copy">
        <strong>{task.title}</strong>
        <small>
          {task.subject}
          {task.recurring ? ` · ${t("重复")}` : ""}
        </small>
      </span>
      <PriorityBadge priority={task.priority} />
      <ChevronRight aria-hidden="true" />
    </button>
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
  const availableTaskTypes: TaskType[] =
    curriculum === "ib"
      ? ["assignment", "ia", "ee", "tok", "cas", "exam", "event", "custom"]
      : ["assignment", "practical", "revision", "exam", "event", "custom"];

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
      <div className={`create-topbar ${mode === "select" ? "select-mode" : ""}`}>
        {mode !== "select" ? (
          <button className="icon-button" type="button" onClick={() => setMode("select")}>
            <ChevronLeft />
          </button>
        ) : (
          <h2>{t("新建任务")}</h2>
        )}
        {mode !== "select" && (
          <h2>{mode === "quick" ? t("快速新建") : t(taskMeta[type].title)}</h2>
        )}
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
            {availableTaskTypes.map((taskType) => {
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
  const { locale, t } = useDemoCopy();
  const now = new Date();
  const today = localISO(now);
  const [monthDate, setMonthDate] = useState(
    () => new Date(now.getFullYear(), now.getMonth(), 1, 12),
  );
  const [selectedDate, setSelectedDate] = useState(today);
  const deadlineTasks = tasks.filter(
    (task): task is PlanoraItem & { deadline: string } => Boolean(task.deadline),
  );
  const monthTasks = deadlineTasks.filter((task) =>
    isSameMonth(task.deadline, monthDate),
  );
  const selectedTasks = sortTasks(
    deadlineTasks.filter((task) => task.deadline === selectedDate),
    "smart",
  );
  const firstOfMonth = new Date(
    monthDate.getFullYear(),
    monthDate.getMonth(),
    1,
    12,
  );
  const daysInMonth = new Date(
    monthDate.getFullYear(),
    monthDate.getMonth() + 1,
    0,
    12,
  ).getDate();
  const leadingEmptyDays = (firstOfMonth.getDay() + 6) % 7;
  const calendarDays: Array<string | null> = [
    ...Array.from({ length: leadingEmptyDays }, () => null),
    ...Array.from({ length: daysInMonth }, (_, index) =>
      localISO(
        new Date(
          monthDate.getFullYear(),
          monthDate.getMonth(),
          index + 1,
          12,
        ),
      ),
    ),
  ];
  const weekdays = Array.from({ length: 7 }, (_, index) =>
    new Intl.DateTimeFormat(dateLocale(locale), { weekday: "short" }).format(
      new Date(2024, 0, index + 1, 12),
    ),
  );

  function itemCount(count: number) {
    if (locale === "en") return `${count} ${count === 1 ? "item" : "items"}`;
    if (locale === "ja") return `${count}件`;
    return `${count} 项任务`;
  }

  function selectMonth(nextMonth: Date) {
    const normalized = new Date(
      nextMonth.getFullYear(),
      nextMonth.getMonth(),
      1,
      12,
    );
    setMonthDate(normalized);

    if (isSameMonth(today, normalized)) {
      setSelectedDate(today);
      return;
    }

    const firstDeadline = deadlineTasks
      .filter((task) => isSameMonth(task.deadline, normalized))
      .map((task) => task.deadline)
      .sort()[0];
    setSelectedDate(firstDeadline ?? localISO(normalized));
  }

  function changeMonth(offset: number) {
    selectMonth(
      new Date(
        monthDate.getFullYear(),
        monthDate.getMonth() + offset,
        1,
        12,
      ),
    );
  }

  return (
    <section className="mini-calendar">
      <div className="calendar-preview-header">
        <div>
          <strong>
            {new Intl.DateTimeFormat(dateLocale(locale), {
              year: "numeric",
              month: "long",
            }).format(monthDate)}
          </strong>
          <span>{itemCount(monthTasks.length)}</span>
        </div>

        <div className="calendar-preview-controls">
          <button
            type="button"
            className="calendar-today"
            onClick={() => selectMonth(now)}
          >
            {t("今天")}
          </button>
          <button
            type="button"
            className="calendar-nav-button"
            onClick={() => changeMonth(-1)}
            aria-label={t("上个月")}
          >
            <ChevronLeft />
          </button>
          <button
            type="button"
            className="calendar-nav-button"
            onClick={() => changeMonth(1)}
            aria-label={t("下个月")}
          >
            <ChevronRight />
          </button>
        </div>
      </div>

      <div className="calendar-month-grid">
        {weekdays.map((weekday, index) => (
          <span className="calendar-weekday" key={`${weekday}-${index}`}>
            {weekday}
          </span>
        ))}
        {calendarDays.map((day, index) => {
          if (!day) {
            return <span className="calendar-empty-day" key={`empty-${index}`} />;
          }

          const dayTasks = monthTasks.filter((task) => task.deadline === day);
          const isSelected = day === selectedDate;
          const isToday = day === today;
          return (
            <button
              type="button"
              key={day}
              className={`calendar-date ${
                isSelected ? "selected" : ""
              } ${isToday && !isSelected ? "today" : ""}`}
              onClick={() => setSelectedDate(day)}
              aria-label={formatDay(day, locale, true)}
              aria-pressed={isSelected}
            >
              <strong>{Number(day.slice(-2))}</strong>
              <span className="calendar-date-dots" aria-hidden="true">
                {dayTasks.slice(0, 3).map((task) => (
                  <i
                    className={`tone-${taskMeta[task.type].color}`}
                    key={task.id}
                  />
                ))}
              </span>
            </button>
          );
        })}
      </div>

      <div className="calendar-selected-day">
        <div className="calendar-selected-heading">
          <strong>{formatDay(selectedDate, locale, true)}</strong>
          <span>{itemCount(selectedTasks.length)}</span>
        </div>

        {selectedTasks.length === 0 ? (
          <p>{t("当天没有截止任务。")}</p>
        ) : (
          <div className="calendar-selected-tasks">
            {selectedTasks.map((task) => {
              const Icon = task.completed
                ? CheckCircle2
                : taskMeta[task.type].icon;
              return (
                <button
                  type="button"
                  key={task.id}
                  className={task.completed ? "completed" : ""}
                  onClick={() => onOpenTask(task.id)}
                >
                  <Icon
                    className={`calendar-task-icon tone-${
                      task.completed ? "green" : taskMeta[task.type].color
                    }`}
                  />
                  <span>
                    <strong>{task.title}</strong>
                    <small>{task.subject}</small>
                  </span>
                  <PriorityBadge priority={task.priority} compact />
                  <ChevronRight className="calendar-task-chevron" />
                </button>
              );
            })}
          </div>
        )}
      </div>
    </section>
  );
}

function isSameMonth(value: string | Date, monthDate: Date) {
  const date =
    typeof value === "string" ? new Date(`${value}T12:00:00`) : value;
  return (
    date.getFullYear() === monthDate.getFullYear() &&
    date.getMonth() === monthDate.getMonth()
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

function LearningInsight({
  icon: Icon,
  value,
  label,
  color,
}: {
  icon: LucideIcon;
  value: string;
  label: string;
  color: string;
}) {
  return (
    <div className="learning-insight">
      <Icon className={`tone-${color}`} />
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

function displayModeTitle(mode: DisplayMode, locale: DemoLocale) {
  const source = {
    system: "跟随系统",
    light: "浅色",
    dark: "深色",
  }[mode];
  return copy(locale, source);
}

function backgroundTitle(
  background: BackgroundStyle,
  locale: DemoLocale,
) {
  const source = {
    sky: "极光",
    ocean: "天空",
    mint: "薄荷",
    rose: "玫瑰",
  }[background];
  return copy(locale, source);
}

function accentTitle(accent: AccentColor, locale: DemoLocale) {
  const source = {
    blue: "蓝色",
    green: "绿色",
    amber: "橙色",
    pink: "粉色",
  }[accent];
  return copy(locale, source);
}

function sortOrderTitle(order: SortOrder, locale: DemoLocale) {
  const source = {
    smart: "智能排序",
    deadline: "截止日期",
    priority: "优先级",
    title: "标题",
  }[order];
  return copy(locale, source);
}

function stageTitle(stage: string, locale: DemoLocale) {
  const translated: Record<string, Record<DemoLocale, string>> = {
    "Research Question": {
      "zh-Hans": "研究问题",
      en: "Research Question",
      ja: "研究課題",
    },
    Methodology: {
      "zh-Hans": "研究方法",
      en: "Methodology",
      ja: "研究方法",
    },
    "Data Collection": {
      "zh-Hans": "数据收集",
      en: "Data Collection",
      ja: "データ収集",
    },
    Analysis: {
      "zh-Hans": "分析",
      en: "Analysis",
      ja: "分析",
    },
    Evaluation: {
      "zh-Hans": "评估",
      en: "Evaluation",
      ja: "評価",
    },
    "Final Submission": {
      "zh-Hans": "最终提交",
      en: "Final Submission",
      ja: "最終提出",
    },
  };
  return translated[stage]?.[locale] ?? copy(locale, stage);
}
