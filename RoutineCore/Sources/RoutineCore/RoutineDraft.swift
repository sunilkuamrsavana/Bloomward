import Foundation

/// New habits stay in this draft until the entire routine is saved.
public struct RoutineDraftStep: Identifiable, Equatable, Sendable {
    public indirect enum Source: Equatable, Sendable {
        case existing(Habit.ID)
        case new(Habit)
        case action(String)
        case group(String, [RoutineDraftStep])
    }

    public let id: UUID
    public var source: Source
    public var schedule: RoutineSchedule?
    public var estimatedDurationSeconds: Int?
    public var notes: String?

    public init(id: UUID = UUID(), source: Source, schedule: RoutineSchedule? = nil,
                estimatedDurationSeconds: Int? = nil, notes: String? = nil) {
        self.id = id
        self.source = source
        self.schedule = schedule
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.notes = notes
    }

    public func habit(in habits: [Habit]) -> Habit? {
        switch source {
        case .existing(let id): return habits.first { $0.id == id && !$0.isArchived }
        case .new(let habit): return habit
        case .action, .group: return nil
        }
    }

    public init(step: RoutineStep) {
        id = step.id
        if let children = step.children { source = .group(step.title, children.map(Self.init(step:))) }
        else if let id = step.habitID { source = .existing(id) }
        else { source = .action(step.title) }
        schedule = step.schedule
        estimatedDurationSeconds = step.estimatedDurationSeconds
        notes = step.notes
    }

    public var children: [RoutineDraftStep]? {
        get { if case .group(_, let steps) = source { return steps }; return nil }
        set { if case .group(let title, _) = source { source = .group(title, newValue ?? []) } }
    }

    public func title(in habits: [Habit]) -> String {
        switch source {
        case .action(let title), .group(let title, _): return title
        case .existing, .new: return habit(in: habits)?.title ?? "Habit unavailable"
        }
    }

    public var habitIDs: [Habit.ID] {
        switch source {
        case .existing(let id): return [id]
        case .new(let habit): return [habit.id]
        case .action: return []
        case .group(_, let children): return children.flatMap(\.habitIDs)
        }
    }
}

public struct RoutineDraft: Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var steps: [RoutineDraftStep]
    public var schedule: RoutineSchedule?
    public var symbolName: String

    public init(id: UUID = UUID(), title: String = "", steps: [RoutineDraftStep] = [],
                schedule: RoutineSchedule? = nil, symbolName: String = "leaf.fill") {
        self.id = id
        self.title = title
        self.steps = steps
        self.schedule = schedule
        self.symbolName = symbolName
    }

    public init(routine: Routine) {
        self.init(id: routine.id, title: routine.title, steps: routine.steps.map(RoutineDraftStep.init(step:)),
                  schedule: routine.schedule, symbolName: routine.symbolName)
    }

    /// Validate everything before returning an updated state: cancelling or failing never leaves orphan habits.
    public func applying(to state: AppState, on day: LocalDay, updating: Bool = false) throws -> AppState {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty && name.count <= 60 else { throw RoutineDraftError.invalidName }
        guard !steps.isEmpty else { throw RoutineDraftError.noSteps }
        let existingIndex = state.routines.firstIndex { $0.id == id && !$0.isArchived }
        guard updating ? existingIndex != nil : existingIndex == nil else { throw RoutineDraftError.alreadySaved }
        guard schedule?.isValid != false else { throw RoutineDraftError.invalidSchedule }
        var result = state
        var seen = Set<Habit.ID>()
        var seenSteps = Set<UUID>()
        func resolve(_ step: RoutineDraftStep, parentDays: Set<Int>, depth: Int) throws -> RoutineStep {
            guard depth < 5, seenSteps.count < 1000, seenSteps.insert(step.id).inserted else {
                throw RoutineDraftError.invalidStructure
            }
            guard step.schedule?.isValid != false else { throw RoutineDraftError.invalidSchedule }
            let days = parentDays.intersection(step.schedule?.weekdays ?? parentDays)
            guard !days.isEmpty else { throw RoutineDraftError.noSharedDays }
            let title = step.title(in: state.habits).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title.count <= 60,
                  (step.estimatedDurationSeconds.map { (0...86400).contains($0) } ?? true),
                  (step.notes?.count ?? 0) <= 2000 else { throw RoutineDraftError.invalidStep }
            var resolved = RoutineStep(id: step.id, title: title, estimatedDurationSeconds: step.estimatedDurationSeconds,
                                       schedule: step.schedule, notes: step.notes)
            switch step.source {
            case .action: break
            case .group(_, let children):
                guard !children.isEmpty else { throw RoutineDraftError.emptyGroup }
                resolved.estimatedDurationSeconds = nil
                resolved.children = try children.map { try resolve($0, parentDays: days, depth: depth + 1) }
            case .existing, .new:
                guard var habit = step.habit(in: state.habits), habit.settings?.isPaused != true else {
                    throw RoutineDraftError.unavailableHabit
                }
                guard seen.insert(habit.id).inserted else { throw RoutineDraftError.duplicateHabit }
                if case .new = step.source {
                    habit.title = title
                    guard !habit.isArchived, habit.settings?.isValid != false else { throw RoutineDraftError.invalidHabit }
                    guard !state.habits.contains(where: { $0.id == habit.id }) else { throw RoutineDraftError.duplicateHabit }
                    var settings = habit.settings ?? .newHabitDefaults
                    settings.createdOn = day
                    habit.settings = settings
                    result.habits.append(habit)
                }
                resolved.habitID = habit.id
            }
            return resolved
        }
        let routineSteps = try steps.map { try resolve($0, parentDays: schedule?.weekdays ?? Set(1...7), depth: 0) }
        let routine = Routine(id: id, title: name, symbolName: symbolName, steps: routineSteps, schedule: schedule)
        if let existingIndex { result.routines[existingIndex] = routine }
        else { result.routines.append(routine) }
        return result
    }
}

public enum RoutineDraftError: Error, LocalizedError {
    case invalidName, noSteps, unavailableHabit, invalidHabit, duplicateHabit, alreadySaved
    case invalidSchedule, noSharedDays, invalidStep, emptyGroup, invalidStructure

    public var errorDescription: String? {
        switch self {
        case .invalidName: "Give your routine a name of 1–60 characters."
        case .noSteps: "Add at least one step to your routine."
        case .unavailableHabit: "A selected habit is paused or no longer available. Remove it or choose another."
        case .invalidHabit: "Check the new habit's name and schedule."
        case .duplicateHabit: "Each habit can appear once in a routine."
        case .alreadySaved: "This routine has already been saved."
        case .invalidSchedule: "Choose at least one day and a valid time."
        case .noSharedDays: "An item's days must overlap with its parent routine's days."
        case .invalidStep: "Give each step a name of 1–60 characters and check its optional details."
        case .emptyGroup: "Add at least one step inside each sub-routine."
        case .invalidStructure: "Use no more than five levels and 1,000 items, with each item added once."
        }
    }
}
