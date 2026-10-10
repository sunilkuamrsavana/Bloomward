import Foundation

/// An optional refinement of the parent's days, not a separate session type.
public struct RoutineSchedule: Hashable, Codable, Sendable {
    public var weekdays: Set<Int>
    public var startMinute: Int?

    public init(weekdays: Set<Int> = Set(1...7), startMinute: Int? = nil) {
        self.weekdays = weekdays
        self.startMinute = startMinute
    }

    public var isValid: Bool {
        !weekdays.isEmpty && weekdays.allSatisfy { (1...7).contains($0) }
            && (startMinute.map { (0..<1440).contains($0) } ?? true)
    }

    public func includes(_ day: LocalDay) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) else { return false }
        return weekdays.contains(calendar.component(.weekday, from: date))
    }
}

public struct RoutineExecutionStep: Hashable, Codable, Sendable {
    public var step: RoutineStep
    public var path: [String]
    public init(step: RoutineStep, path: [String] = []) { self.step = step; self.path = path }
}

public extension RoutineStep {
    var leafSteps: [RoutineStep] { children.map { $0.flatMap(\.leafSteps) } ?? [self] }

    func executionSteps(on day: LocalDay, path: [String] = []) -> [RoutineExecutionStep] {
        guard schedule?.includes(day) != false else { return [] }
        if let children {
            return children.flatMap { $0.executionSteps(on: day, path: path + [title]) }
        }
        return [RoutineExecutionStep(step: self, path: path)]
    }

    mutating func renameHabit(_ id: Habit.ID, to title: String) {
        if habitID == id { self.title = title }
        if let count = children?.count {
            for index in 0..<count { children?[index].renameHabit(id, to: title) }
        }
    }
}

public extension Routine {
    var leafSteps: [RoutineStep] { steps.flatMap(\.leafSteps) }
    func executionSteps(on day: LocalDay) -> [RoutineExecutionStep] {
        guard schedule?.includes(day) != false else { return [] }
        return steps.flatMap { $0.executionSteps(on: day) }
    }
}

public extension ActiveRoutine {
    func executionSteps(in routine: Routine) -> [RoutineExecutionStep] {
        // Legacy active runs were flat and must retain their original index mapping.
        plan ?? routine.steps.map { RoutineExecutionStep(step: $0) }
    }
}
