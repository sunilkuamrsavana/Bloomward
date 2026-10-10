import Foundation

public struct AppState: Equatable, Codable, Sendable {
    public var habits: [Habit]
    public var routines: [Routine]
    public var days: [LocalDay: DailyState]
    public var activeRoutine: ActiveRoutine?
    public var routineHistory: [RoutineRun]
    public var planTasks: [PlanTask]
    public var planOccurrences: [PlanOccurrence]
    public var dayNotes: [DayNote]

    public init(
        habits: [Habit] = [],
        routines: [Routine] = [],
        days: [LocalDay: DailyState] = [:],
        activeRoutine: ActiveRoutine? = nil,
        routineHistory: [RoutineRun] = [],
        planTasks: [PlanTask] = [],
        planOccurrences: [PlanOccurrence] = [],
        dayNotes: [DayNote] = []
    ) {
        self.habits = habits
        self.routines = routines
        self.days = days
        self.activeRoutine = activeRoutine
        self.routineHistory = routineHistory
        self.planTasks = planTasks
        self.planOccurrences = planOccurrences
        self.dayNotes = dayNotes
    }

    private enum CodingKeys: String, CodingKey {
        case habits, routines, days, activeRoutine, routineHistory, planTasks, planOccurrences, dayNotes
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        habits = try c.decode([Habit].self, forKey: .habits)
        routines = try c.decode([Routine].self, forKey: .routines)
        days = try c.decode([LocalDay: DailyState].self, forKey: .days)
        activeRoutine = try c.decodeIfPresent(ActiveRoutine.self, forKey: .activeRoutine)
        routineHistory = try c.decode([RoutineRun].self, forKey: .routineHistory)
        planTasks = try c.decodeIfPresent([PlanTask].self, forKey: .planTasks) ?? []
        planOccurrences = try c.decodeIfPresent([PlanOccurrence].self, forKey: .planOccurrences) ?? []
        dayNotes = try c.decodeIfPresent([DayNote].self, forKey: .dayNotes) ?? []
    }

    public func habit(id: Habit.ID) -> Habit? {
        habits.first { $0.id == id }
    }

    public func routine(id: Routine.ID) -> Routine? {
        routines.first { $0.id == id }
    }

    public func dailyState(for day: LocalDay) -> DailyState {
        days[day] ?? DailyState(day: day)
    }

    public func status(for habitID: Habit.ID, on day: LocalDay) -> DailyHabitStatus {
        days[day]?.status(for: habitID) ?? .pending
    }

    public func entry(for habitID: Habit.ID, on day: LocalDay) -> DailyHabitEntry? {
        days[day]?.entry(for: habitID)
    }

    mutating func setStatus(
        _ status: DailyHabitStatus,
        for habitID: Habit.ID,
        on day: LocalDay,
        at date: Date
    ) {
        var dailyState = days[day] ?? DailyState(day: day)
        dailyState.setStatus(status, for: habitID, at: date)
        days[day] = dailyState
    }
}
