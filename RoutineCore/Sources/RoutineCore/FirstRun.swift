import Foundation

public enum FirstRunStep: String, Codable, Sendable { case welcome, start, habit, setup }
public enum FirstRunChoice: String, Codable, Sendable { case habit, routine }
public enum FirstHabit: String, CaseIterable, Codable, Sendable {
    case water, read, walk, breathe, custom
    public var title: String {
        switch self {
        case .water: "Drink a Glass of Water"
        case .read: "Read for 5 Minutes"
        case .walk: "Take a Short Walk"
        case .breathe: "Breathe for 1 Minute"
        case .custom: "My small habit"
        }
    }
    public var symbol: String {
        switch self {
        case .water: "drop.fill"
        case .read: "book"
        case .walk: "figure.walk"
        case .breathe, .custom: "leaf.fill"
        }
    }
    public var initialGoal: Int { self == .read || self == .walk ? 5 : 1 }
}

/// A draft is persisted separately; choosing suggestions never creates sample data.
public struct FirstRunDraft: Codable, Equatable, Sendable {
    public var step: FirstRunStep = .welcome
    public var choice: FirstRunChoice?
    public var habit: FirstHabit?
    public var customName = ""
    public var goal = 1
    public var weekdays: Set<Int> = Set(1...7)
    public var reminderEnabled = false
    public var reminderMinute = 9 * 60
    public var habitIDs = [UUID(), UUID(), UUID()]
    public var routineID = UUID()
    public init() { }

    public var habitTitle: String {
        guard let habit else { return "Choose a habit" }
        switch habit {
        case .water: return goal == 1 ? habit.title : "Drink \(goal) Glasses of Water"
        case .read: return "Read for \(goal) \(goal == 1 ? "Minute" : "Minutes")"
        case .walk: return "Walk for \(goal) \(goal == 1 ? "Minute" : "Minutes")"
        case .breathe: return "Breathe for \(goal) \(goal == 1 ? "Minute" : "Minutes")"
        case .custom: return customName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    public var goalLabel: String {
        if habit == .custom { return "Once" }
        return habit == .water ? "\(goal) \(goal == 1 ? "glass" : "glasses")" : "\(goal) min"
    }

    public func plan(on day: LocalDay) -> AppState? {
        guard choice != nil, !weekdays.isEmpty, weekdays.allSatisfy({ (1...7).contains($0) }),
              (0..<1440).contains(reminderMinute), (1...60).contains(goal),
              habitIDs.count == 3, Set(habitIDs).count == 3 else { return nil }
        var settings = HabitSettings()
        settings.weekdays = weekdays
        settings.timeWindowEnabled = false
        settings.carryForward = false
        settings.allowsRest = true
        settings.endOfDayMinute = nil
        settings.createdOn = day
        if choice == .routine {
            let suggestions: [FirstHabit] = [.breathe, .water, .read]
            let habits = suggestions.enumerated().map { index, item in
                Habit(id: habitIDs[index], title: item.title, symbolName: item.symbol, settings: settings)
            }
            let routine = Routine(id: routineID, title: "A Gentle Start", symbolName: "sun.max.fill",
                steps: habits.enumerated().map { index, item in
                    RoutineStep(title: item.title, habitID: item.id, estimatedDurationSeconds: [60, 60, 300][index])
                })
            return AppState(habits: habits, routines: [routine])
        }
        guard let habit, !habitTitle.isEmpty, habitTitle.count <= 60 else { return nil }
        settings.category = habit == .read || habit == .breathe ? .mind : habit == .custom ? .custom : .health
        return AppState(habits: [Habit(id: habitIDs[0], title: habitTitle, symbolName: habit.symbol, settings: settings)])
    }
}

public enum LocalAccountImport {
    /// Explicitly requested additive import. Account-owned conflicts win; neither input is erased.
    /// A running guest timer and guest profile preferences never cross into an account.
    public static func merging(guest: AppState, into account: AppState) -> AppState {
        var result = SyncMerger.merge(base: SyncSnapshot(), local: SyncSnapshot(state: guest),
            remote: SyncSnapshot(state: account), choice: .cloud).snapshot.state
        result.activeRoutine = account.activeRoutine
        return result
    }
}
