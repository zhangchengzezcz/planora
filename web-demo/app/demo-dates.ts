type Dates = { deadline?: string; plannedDate?: string };
type DemoTask = Dates & { id: string; demoDates?: Dates };
const fields = ["deadline", "plannedDate"] as const;

function dayNumber(value: string) {
  return Date.parse(`${value}T12:00:00Z`) / 86_400_000;
}

export function markDemoDates<T extends DemoTask>(tasks: T[]): T[] {
  return tasks.map(task => ({ ...task, demoDates: {
    deadline: task.deadline, plannedDate: task.plannedDate,
  } }));
}

export function refreshDemoDates<T extends DemoTask>(tasks: T[], templates: T[]): T[] {
  const byID = new Map(templates.map(task => [task.id, task]));
  const shifts = new Map<number, number>();
  // Older demos have no date metadata. Infer their shared seed day, leaving
  // dates outside that cohort unchanged rather than resetting user edits.
  for (const task of tasks) {
    const template = byID.get(task.id);
    if (!template || task.demoDates) continue;
    for (const field of fields) {
      if (task[field] && template[field]) {
        const shift = dayNumber(task[field]) - dayNumber(template[field]);
        if (Number.isFinite(shift)) shifts.set(shift, (shifts.get(shift) ?? 0) + 1);
      }
    }
  }
  const cohort = [...shifts].sort((a, b) => b[1] - a[1])[0];
  const legacyShift = cohort && cohort[1] >= 2 ? cohort[0] : undefined;
  return tasks.map(task => {
    const template = byID.get(task.id);
    if (!template) return task;
    const next = { ...task, demoDates: {} as Dates };
    for (const field of fields) {
      const saved = task[field];
      const fresh = template[field];
      const followsDemo = task.demoDates
        ? typeof task.demoDates[field] === "string" && saved === task.demoDates[field]
        : saved && fresh && legacyShift !== undefined
          && dayNumber(saved) - dayNumber(fresh) === legacyShift;
      if (followsDemo) {
        next[field] = fresh;
        next.demoDates[field] = fresh;
      }
    }
    return next;
  });
}
