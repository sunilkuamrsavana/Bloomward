import Foundation

/// A calendar day without an implicit time zone.
///
/// The UI decides which calendar and time zone turn a `Date` into a `LocalDay`.
/// Keeping that decision outside the reducer makes state transitions repeatable.
public struct LocalDay: Hashable, Codable, Sendable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        precondition((1...12).contains(month), "Month must be between 1 and 12")
        precondition((1...31).contains(day), "Day must be between 1 and 31")

        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            preconditionFailure("The supplied calendar could not resolve a day")
        }

        self.init(year: year, month: month, day: day)
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

public struct Habit: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var symbolName: String
    public var minimumTitle: String?
    public var isArchived: Bool
    public var settings: HabitSettings?

    public init(
        id: UUID = UUID(),
        title: String,
        symbolName: String = "checkmark.circle",
        minimumTitle: String? = nil,
        isArchived: Bool = false,
        settings: HabitSettings? = nil
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.minimumTitle = minimumTitle
        self.isArchived = isArchived
        self.settings = settings
    }
}

public enum HabitCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case health = "Health", mind = "Mind", productivity = "Productivity", lifestyle = "Lifestyle", custom = "Custom"
    public var id: Self { self }
}

public enum HabitReminderStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case gentle = "Gentle", persistent = "Persistent", critical = "Critical"
    public var id: Self { self }
}

public struct HabitSettings: Hashable, Codable, Sendable {
    public var category: HabitCategory = .health
    public var weekdays: Set<Int> = [2, 4, 6]
    public var timeWindowEnabled = true
    public var startMinute = 16 * 60
    public var endMinute = 19 * 60
    public var carryForward = true
    public var allowsRest = true
    public var isPaused = false
    public var endOfDayMinute: Int? = 23 * 60
    public var reminderStyle: HabitReminderStyle = .persistent
    public var notes = ""
    public var createdOn: LocalDay?

    public init() { }

    public var isValid: Bool {
        !weekdays.isEmpty && weekdays.allSatisfy { (1...7).contains($0) }
            && (0..<1440).contains(startMinute) && (0..<1440).contains(endMinute)
            && (!timeWindowEnabled || startMinute < endMinute)
            && (endOfDayMinute.map { (0..<1440).contains($0) } ?? true)
    }
}

public extension Habit {
    func isScheduled(on day: LocalDay, calendar: Calendar) -> Bool {
        guard let settings else { return true }
        guard settings.createdOn.map({ day >= $0 }) ?? true,
              let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) else { return false }
        return settings.weekdays.contains(calendar.component(.weekday, from: date))
    }
}

public struct RoutineStep: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var habitID: Habit.ID?
    public var estimatedDurationSeconds: Int?
    /// nil is an action; a non-nil list is an embedded sub-routine.
    public var children: [RoutineStep]?
    public var schedule: RoutineSchedule?
    public var notes: String?

    public init(
        id: UUID = UUID(),
        title: String,
        habitID: Habit.ID? = nil,
        estimatedDurationSeconds: Int? = nil,
        children: [RoutineStep]? = nil,
        schedule: RoutineSchedule? = nil,
        notes: String? = nil
    ) {
        precondition(
            estimatedDurationSeconds.map { $0 >= 0 } ?? true,
            "Estimated duration cannot be negative"
        )

        self.id = id
        self.title = title
        self.habitID = habitID
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.children = children
        self.schedule = schedule
        self.notes = notes
    }
}

public struct Routine: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var symbolName: String
    public var steps: [RoutineStep]
    public var isArchived: Bool
    public var schedule: RoutineSchedule?

    public init(
        id: UUID = UUID(),
        title: String,
        symbolName: String = "list.bullet.rectangle",
        steps: [RoutineStep],
        isArchived: Bool = false,
        schedule: RoutineSchedule? = nil
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.steps = steps
        self.isArchived = isArchived
        self.schedule = schedule
    }
}

public enum DailyHabitStatus: String, Hashable, Codable, Sendable, CaseIterable {
    case pending
    case completed
    case minimum
    case skipped
    case rest
}

public struct DailyHabitEntry: Hashable, Codable, Sendable {
    public let habitID: Habit.ID
    public var status: DailyHabitStatus
    public var updatedAt: Date

    public init(habitID: Habit.ID, status: DailyHabitStatus, updatedAt: Date) {
        self.habitID = habitID
        self.status = status
        self.updatedAt = updatedAt
    }
}

public struct DailyState: Hashable, Codable, Sendable {
    public let day: LocalDay
    public var entries: [Habit.ID: DailyHabitEntry]

    public init(day: LocalDay, entries: [Habit.ID: DailyHabitEntry] = [:]) {
        self.day = day
        self.entries = entries
    }

    public func status(for habitID: Habit.ID) -> DailyHabitStatus {
        entries[habitID]?.status ?? .pending
    }

    public func entry(for habitID: Habit.ID) -> DailyHabitEntry? {
        entries[habitID]
    }

    mutating func setStatus(
        _ status: DailyHabitStatus,
        for habitID: Habit.ID,
        at date: Date
    ) {
        entries[habitID] = DailyHabitEntry(
            habitID: habitID,
            status: status,
            updatedAt: date
        )
    }
}

public enum RoutineStepOutcome: String, Hashable, Codable, Sendable {
    case pending
    case completed
    case skipped
}

public struct ActiveRoutine: Hashable, Codable, Sendable {
    public let routineID: Routine.ID
    public let day: LocalDay
    public let startedAt: Date
    public var currentStepStartedAt: Date
    public var pausedAt: Date?
    public var currentStepIndex: Int
    public var outcomes: [RoutineStepOutcome]
    /// Freeze today's eligible leaf steps so edits, midnight, and sync cannot change an active run.
    public var plan: [RoutineExecutionStep]?

    public init(
        routineID: Routine.ID,
        day: LocalDay,
        startedAt: Date,
        currentStepStartedAt: Date? = nil,
        pausedAt: Date? = nil,
        currentStepIndex: Int = 0,
        outcomes: [RoutineStepOutcome],
        plan: [RoutineExecutionStep]? = nil
    ) {
        self.routineID = routineID
        self.day = day
        self.startedAt = startedAt
        self.currentStepStartedAt = currentStepStartedAt ?? startedAt
        self.pausedAt = pausedAt
        self.currentStepIndex = currentStepIndex
        self.outcomes = outcomes
        self.plan = plan
    }

    public var completedStepCount: Int {
        outcomes.lazy.filter { $0 == .completed }.count
    }

    private enum CodingKeys: String, CodingKey {
        case routineID
        case day
        case startedAt
        case currentStepStartedAt
        case pausedAt
        case currentStepIndex
        case outcomes
        case plan
    }

    /// Keeps persisted in-progress routines compatible with the first schema,
    /// which did not store per-step timing or pause state.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routineID = try container.decode(Routine.ID.self, forKey: .routineID)
        day = try container.decode(LocalDay.self, forKey: .day)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        let decodedStepStart = try container.decodeIfPresent(Date.self, forKey: .currentStepStartedAt)
        let decodedPausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
        currentStepStartedAt = decodedStepStart ?? startedAt
        pausedAt = decodedStepStart == nil ? (decodedPausedAt ?? startedAt) : decodedPausedAt
        currentStepIndex = try container.decode(Int.self, forKey: .currentStepIndex)
        outcomes = try container.decode([RoutineStepOutcome].self, forKey: .outcomes)
        plan = try container.decodeIfPresent([RoutineExecutionStep].self, forKey: .plan)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(routineID, forKey: .routineID)
        try container.encode(day, forKey: .day)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(currentStepStartedAt, forKey: .currentStepStartedAt)
        try container.encodeIfPresent(pausedAt, forKey: .pausedAt)
        try container.encode(currentStepIndex, forKey: .currentStepIndex)
        try container.encode(outcomes, forKey: .outcomes)
        try container.encodeIfPresent(plan, forKey: .plan)
    }
}

public enum RoutineRunResult: String, Hashable, Codable, Sendable {
    case completed
    case partial
    case skipped
}

public struct RoutineRun: Hashable, Codable, Sendable {
    public let routineID: Routine.ID
    public let day: LocalDay
    public let startedAt: Date
    public let endedAt: Date
    public let outcomes: [RoutineStepOutcome]
    public let result: RoutineRunResult

    public init(
        routineID: Routine.ID,
        day: LocalDay,
        startedAt: Date,
        endedAt: Date,
        outcomes: [RoutineStepOutcome],
        result: RoutineRunResult
    ) {
        self.routineID = routineID
        self.day = day
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.outcomes = outcomes
        self.result = result
    }
}

/// A lower-pressure alternative offered when the original habit is no longer realistic.
public enum RecoveryChoice: String, Hashable, Codable, Sendable, CaseIterable {
    case minimum
    case skip
    case rest
}
