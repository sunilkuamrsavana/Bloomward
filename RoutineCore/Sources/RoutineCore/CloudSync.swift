import Foundation

/// Versioned wire format. An active timer and device permissions never leave the device.
public struct SyncSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion = 3
    public var habits: [Habit]
    public var routines: [Routine]
    public var days: [SyncDay]
    public var routineHistory: [RoutineRun]
    public var preferences: [String: String]
    public var planTasks: [PlanTask]
    public var planOccurrences: [PlanOccurrence]
    public var dayNotes: [DayNote]

    public init(state: AppState = AppState(), preferences: [String: String] = [:]) {
        habits = state.habits.sorted { $0.id.uuidString < $1.id.uuidString }
        routines = state.routines.sorted { $0.id.uuidString < $1.id.uuidString }
        days = state.days.values.filter { !$0.entries.isEmpty }.sorted { $0.day < $1.day }.map {
            SyncDay(day: $0.day, entries: $0.entries.values.sorted { $0.habitID.uuidString < $1.habitID.uuidString })
        }
        routineHistory = state.routineHistory.sorted { Self.runKey($0) < Self.runKey($1) }
        self.preferences = preferences
        planTasks = state.planTasks.sorted { $0.id.uuidString < $1.id.uuidString }
        planOccurrences = state.planOccurrences.sorted { $0.id < $1.id }
        dayNotes = state.dayNotes.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, habits, routines, days, routineHistory, preferences, planTasks, planOccurrences, dayNotes
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        habits = try c.decode([Habit].self, forKey: .habits)
        routines = try c.decode([Routine].self, forKey: .routines)
        days = try c.decode([SyncDay].self, forKey: .days)
        routineHistory = try c.decode([RoutineRun].self, forKey: .routineHistory)
        preferences = try c.decode([String: String].self, forKey: .preferences)
        planTasks = try c.decodeIfPresent([PlanTask].self, forKey: .planTasks) ?? []
        planOccurrences = try c.decodeIfPresent([PlanOccurrence].self, forKey: .planOccurrences) ?? []
        dayNotes = try c.decodeIfPresent([DayNote].self, forKey: .dayNotes) ?? []
    }

    public var state: AppState {
        AppState(habits: habits, routines: routines, days: Dictionary(days.map {
            ($0.day, DailyState(day: $0.day, entries: Dictionary($0.entries.map { ($0.habitID, $0) }, uniquingKeysWith: { _, new in new })))
        }, uniquingKeysWith: { _, new in new }), routineHistory: routineHistory,
                 planTasks: planTasks, planOccurrences: planOccurrences, dayNotes: dayNotes)
    }

    public static func runKey(_ run: RoutineRun) -> String {
        "\(run.routineID.uuidString):\(run.startedAt.timeIntervalSinceReferenceDate)"
    }
}

public struct SyncDay: Codable, Equatable, Sendable {
    public var day: LocalDay
    public var entries: [DailyHabitEntry]
    public init(day: LocalDay, entries: [DailyHabitEntry]) { self.day = day; self.entries = entries }
}

public struct SyncEnvelope: Codable, Equatable, Sendable {
    public var revision: Int
    public var snapshot: SyncSnapshot?
    public var updatedAt: String?
    public init(revision: Int = 0, snapshot: SyncSnapshot? = nil, updatedAt: String? = nil) {
        self.revision = revision; self.snapshot = snapshot; self.updatedAt = updatedAt
    }
}

public struct SyncMergeResult: Sendable {
    public let snapshot: SyncSnapshot
    public let conflicts: [String]
}

public enum SyncConflictChoice: Sendable { case thisDevice, cloud }

/// Three-way merge against the last confirmed server snapshot, never against a clock.
/// Independent edits combine. Competing edits require a user's explicit choice.
public enum SyncMerger {
    public static func merge(base: SyncSnapshot, local: SyncSnapshot, remote: SyncSnapshot,
                             choice: SyncConflictChoice? = nil) -> SyncMergeResult {
        var conflicts: [String] = []
        func value<T: Equatable>(_ b: T?, _ l: T?, _ r: T?, label: String) -> T? {
            if l == r { return l }
            if l == b { return r }
            if r == b { return l }
            conflicts.append(label)
            return choice == .cloud ? r : l
        }
        func items<T: Equatable>(_ b: [T], _ l: [T], _ r: [T], key: (T) -> String, label: (T) -> String) -> [T] {
            let bs = Dictionary(b.map { (key($0), $0) }, uniquingKeysWith: { _, new in new })
            let ls = Dictionary(l.map { (key($0), $0) }, uniquingKeysWith: { _, new in new })
            let rs = Dictionary(r.map { (key($0), $0) }, uniquingKeysWith: { _, new in new })
            return Set(bs.keys).union(ls.keys).union(rs.keys).sorted().compactMap { id in
                let name = (ls[id] ?? rs[id] ?? bs[id]).map(label) ?? id
                return value(bs[id], ls[id], rs[id], label: name)
            }
        }
        var state = AppState()
        state.habits = items(base.habits, local.habits, remote.habits, key: { $0.id.uuidString }, label: { $0.title })
        state.routines = items(base.routines, local.routines, remote.routines, key: { $0.id.uuidString }, label: { $0.title })
        let bDays = base.state.days, lDays = local.state.days, rDays = remote.state.days
        for day in Set(bDays.keys).union(lDays.keys).union(rDays.keys).sorted() {
            let b = bDays[day]?.entries ?? [:], l = lDays[day]?.entries ?? [:], r = rDays[day]?.entries ?? [:]
            var entries: [UUID: DailyHabitEntry] = [:]
            for id in Set(b.keys).union(l.keys).union(r.keys).sorted(by: { $0.uuidString < $1.uuidString }) {
                // Logging the same outcome on two devices isn't a meaningful conflict.
                if let left = l[id], let right = r[id], left.status == right.status {
                    entries[id] = left.updatedAt >= right.updatedAt ? left : right
                } else {
                    let title = state.habit(id: id)?.title ?? "Habit"
                    entries[id] = value(b[id], l[id], r[id], label: "\(title) progress (\(day.year)-\(day.month)-\(day.day))")
                }
            }
            if !entries.isEmpty { state.days[day] = DailyState(day: day, entries: entries) }
        }
        state.routineHistory = items(base.routineHistory, local.routineHistory, remote.routineHistory,
                                     key: SyncSnapshot.runKey, label: { _ in "Routine history" })
        state.planTasks = items(base.planTasks, local.planTasks, remote.planTasks,
                               key: { $0.id.uuidString }, label: { $0.title })
        state.planOccurrences = items(base.planOccurrences, local.planOccurrences, remote.planOccurrences,
                                     key: { $0.id }, label: { "\($0.title) on \($0.day.year)-\($0.day.month)-\($0.day.day)" })
        state.dayNotes = items(base.dayNotes, local.dayNotes, remote.dayNotes,
                              key: { $0.id.uuidString }, label: { "Note: \($0.displayTitle)" })
        var preferences: [String: String] = [:]
        for key in Set(base.preferences.keys).union(local.preferences.keys).union(remote.preferences.keys).sorted() {
            preferences[key] = value(base.preferences[key], local.preferences[key], remote.preferences[key], label: "Preference: \(key)")
        }
        return SyncMergeResult(snapshot: SyncSnapshot(state: state, preferences: preferences), conflicts: conflicts)
    }
}
