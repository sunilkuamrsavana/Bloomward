import { z } from "zod";

const id = z.uuid();
const text = z.string().max(2000);
const title = z.string().min(1).max(200);
const date = z.number().finite(); // Swift Date's reference-date seconds.
const day = z.object({ year: z.int().min(1).max(9999), month: z.int().min(1).max(12), day: z.int().min(1).max(31) }).strict();
const settings = z.object({
  category: z.enum(["Health", "Mind", "Productivity", "Lifestyle", "Custom"]),
  weekdays: z.array(z.int().min(1).max(7)).min(1).max(7),
  timeWindowEnabled: z.boolean(), startMinute: z.int().min(0).max(1439), endMinute: z.int().min(0).max(1439),
  carryForward: z.boolean(), allowsRest: z.boolean(), isPaused: z.boolean(),
  endOfDayMinute: z.int().min(0).max(1439).nullable().optional(),
  reminderStyle: z.enum(["Gentle", "Persistent", "Critical"]), notes: text, createdOn: day.nullable().optional(),
}).strict();
const habit = z.object({ id, title, symbolName: z.string().max(100), minimumTitle: text.nullable().optional(),
  isArchived: z.boolean(), settings: settings.nullable().optional() }).strict();
const schedule = z.object({ weekdays: z.array(z.int().min(1).max(7)).min(1).max(7)
  .refine(days => new Set(days).size === days.length), startMinute: z.int().min(0).max(1439).nullable().optional() }).strict();
interface RoutineStepRecord {
  id: string; title: string; habitID?: string | null; estimatedDurationSeconds?: number | null;
  schedule?: z.infer<typeof schedule> | null; notes?: string | null; children?: RoutineStepRecord[] | null;
}
// Bound the shape before parsing: untrusted JSON cannot recurse without limit.
function stepSchema(depth: number): z.ZodType<RoutineStepRecord> {
  return z.object({ id, title, habitID: id.nullable().optional(),
    estimatedDurationSeconds: z.int().min(0).max(86400).nullable().optional(),
    schedule: schedule.nullable().optional(), notes: text.nullable().optional(),
    children: (depth < 4 ? z.array(stepSchema(depth + 1)).min(1).max(1000) : z.never()).nullable().optional(),
  }).strict().refine(s => !s.children || !s.habitID, "A sub-routine cannot also be a habit");
}
const step = stepSchema(0);
const routine = z.object({ id, title, symbolName: z.string().max(100), steps: z.array(step).max(1000),
  isArchived: z.boolean(), schedule: schedule.nullable().optional() }).strict().refine(r => {
    const ids = new Set<string>();
    function valid(items: RoutineStepRecord[], parentDays: number[]): boolean {
      return items.every(item => {
        const key = item.id.toLowerCase();
        if (ids.has(key) || ids.size >= 1000) return false;
        ids.add(key);
        const days = parentDays.filter(day => !item.schedule || item.schedule.weekdays.includes(day));
        return days.length > 0 && (!item.children || valid(item.children, days));
      });
    }
    return valid(r.steps, r.schedule?.weekdays ?? [1,2,3,4,5,6,7]);
  }, "Invalid routine structure or schedule");
const entry = z.object({ habitID: id, status: z.enum(["pending", "completed", "minimum", "skipped", "rest"]), updatedAt: date }).strict();
const syncDay = z.object({ day, entries: z.array(entry).max(1000) }).strict();
const run = z.object({ routineID: id, day, startedAt: date, endedAt: date,
  outcomes: z.array(z.enum(["pending", "completed", "skipped"])).max(1000), result: z.enum(["completed", "partial", "skipped"]) }).strict();
const preferences = z.object({
  "daymark.profile-name": z.string().max(40).optional(),
  "daymark.day-start-hour": z.enum(["0", "4", "5", "6", "7"]).optional(),
  "daymark.week-start": z.enum(["1", "2"]).optional(),
  "daymark.default-carry-forward": z.enum(["true", "false"]).optional(),
  "daymark.default-rest-days": z.enum(["true", "false"]).optional(),
}).strict();
const planStep = z.object({ id, title, isDone: z.boolean(), notes: text.nullable().optional() }).strict();
const planTask = z.object({ id, title, notes: z.string().max(20000), startsOn: day, endsOn: day.nullable().optional(),
  minute: z.int().min(0).max(1439).nullable().optional(),
  weekdays: z.array(z.int().min(1).max(7)).min(1).max(7).refine(days => new Set(days).size === days.length).nullable().optional(),
  steps: z.array(planStep).max(1000), routineID: id.nullable().optional(), isArchived: z.boolean() }).strict();
const occurrence = z.object({ taskID: id, day, title, notes: z.string().max(20000),
  minute: z.int().min(0).max(1439).nullable().optional(), steps: z.array(planStep).max(1000),
  status: z.enum(["pending", "completed", "partial", "skipped", "moved"]),
  isRemoved: z.boolean(), movedTo: day.nullable().optional(), order: z.int().min(0).max(1000000),
}).strict().refine(o => o.status === "moved" ? !!o.movedTo : !o.movedTo, "Invalid move destination");
const note = z.object({ id, day, title: z.string().max(200), body: z.string().max(100000),
  updatedAt: date, isArchived: z.boolean() }).strict();
function unique<T>(values: T[], key: (item: T) => string): boolean { return new Set(values.map(key)).size === values.length; }
export const snapshotSchema = z.object({
  schemaVersion: z.union([z.literal(1), z.literal(2), z.literal(3)]), habits: z.array(habit).max(1000), routines: z.array(routine).max(500),
  days: z.array(syncDay).max(20000), routineHistory: z.array(run).max(20000), preferences,
  planTasks: z.array(planTask).max(10000).optional(),
  planOccurrences: z.array(occurrence).max(50000).optional(), dayNotes: z.array(note).max(20000).optional(),
}).strict().refine(s => unique(s.habits, h => h.id.toLowerCase()) && unique(s.routines, r => r.id.toLowerCase())
  && s.routines.every(r => unique(r.steps, step => step.id.toLowerCase()))
  && unique(s.days, d => JSON.stringify(d.day)) && s.days.every(d => unique(d.entries, e => e.habitID.toLowerCase()))
  && unique(s.routineHistory, r => `${r.routineID.toLowerCase()}:${r.startedAt}`), "Duplicate record identifiers")
  .refine(s => s.schemaVersion >= 2 || s.routines.every(r => !r.schedule &&
    r.steps.every(step => !step.children && !step.schedule && !step.notes)), "Routine extensions require schema 2")
  .refine(s => s.schemaVersion === 3 ? !!s.planTasks && !!s.planOccurrences && !!s.dayNotes
    : s.planTasks === undefined && s.planOccurrences === undefined && s.dayNotes === undefined, "Planner records require schema 3")
  .refine(s => unique(s.planTasks ?? [], t => t.id.toLowerCase()) &&
    unique(s.planOccurrences ?? [], o => `${o.taskID.toLowerCase()}:${JSON.stringify(o.day)}`) &&
    unique(s.dayNotes ?? [], n => n.id.toLowerCase()) &&
    (s.planTasks ?? []).every(t => unique(t.steps, step => step.id.toLowerCase())) &&
    (s.planOccurrences ?? []).every(o => unique(o.steps, step => step.id.toLowerCase())), "Duplicate planner identifiers");
export const uploadSchema = z.object({ baseRevision: z.int().min(0).max(Number.MAX_SAFE_INTEGER - 1), snapshot: snapshotSchema }).strict();
