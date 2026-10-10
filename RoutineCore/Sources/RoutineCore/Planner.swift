import Foundation

public enum PlanStatus: String, Codable, CaseIterable, Sendable {
    case pending, completed, partial, skipped, moved
}

public struct PlanStep: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var isDone: Bool
    public var notes: String?
    public init(id: UUID = UUID(), title: String, isDone: Bool = false, notes: String? = nil) {
        self.id = id; self.title = title; self.isDone = isDone; self.notes = notes
    }
}

/// A one-off task or repeating template. Each day's occurrence is a separate snapshot.
public struct PlanTask: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var startsOn: LocalDay
    public var endsOn: LocalDay?
    public var minute: Int?
    public var weekdays: Set<Int>?
    public var steps: [PlanStep]
    public var routineID: UUID?
    public var isArchived: Bool
    public init(id: UUID = UUID(), title: String, notes: String = "", startsOn: LocalDay,
                endsOn: LocalDay? = nil, minute: Int? = nil, weekdays: Set<Int>? = nil,
                steps: [PlanStep] = [], routineID: UUID? = nil, isArchived: Bool = false) {
        self.id = id; self.title = title; self.notes = notes; self.startsOn = startsOn
        self.endsOn = endsOn; self.minute = minute; self.weekdays = weekdays
        self.steps = steps; self.routineID = routineID; self.isArchived = isArchived
    }
    public func includes(_ day: LocalDay) -> Bool {
        guard !isArchived, day >= startsOn, endsOn.map({ day <= $0 }) ?? true else { return false }
        return weekdays.map { $0.contains(day.weekday) } ?? (day == startsOn)
    }
    public var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 200
            && notes.count <= 20000 && (minute.map { (0..<1440).contains($0) } ?? true)
            && (weekdays.map { !$0.isEmpty && $0.allSatisfy { (1...7).contains($0) } } ?? true)
            && (endsOn.map { $0 >= startsOn } ?? true) && steps.count <= 1000
            && Set(steps.map(\.id)).count == steps.count
            && steps.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.title.count <= 200 }
    }
}

public struct PlanOccurrence: Identifiable, Codable, Equatable, Sendable {
    public var taskID: UUID
    public var day: LocalDay
    public var title: String
    public var notes: String
    public var minute: Int?
    public var steps: [PlanStep]
    public var status: PlanStatus
    public var isRemoved: Bool
    public var movedTo: LocalDay?
    public var order: Int
    public var id: String { "\(taskID.uuidString):\(day.year)-\(day.month)-\(day.day)" }
    public init(task: PlanTask, day: LocalDay, order: Int = 0) {
        taskID = task.id; self.day = day; title = task.title; notes = task.notes
        minute = task.minute; steps = task.steps.map { PlanStep(id: $0.id, title: $0.title, notes: $0.notes) }
        status = .pending; isRemoved = false; movedTo = nil; self.order = order
    }
}

public struct DayNote: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var day: LocalDay
    public var title: String
    public var body: String
    public var updatedAt: Date
    public var isArchived: Bool
    public init(id: UUID = UUID(), day: LocalDay, title: String = "", body: String = "",
                updatedAt: Date = Date(), isArchived: Bool = false) {
        self.id = id; self.day = day; self.title = title; self.body = body
        self.updatedAt = updatedAt; self.isArchived = isArchived
    }
    public var displayTitle: String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Untitled note" : name
    }
    public var isValid: Bool { title.count <= 200 && body.count <= 100000 }
}

public extension LocalDay {
    var weekday: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return calendar.component(.weekday, from: date)
    }
    func adding(days: Int) -> LocalDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return LocalDay(date: calendar.date(byAdding: .day, value: days, to: date)!, calendar: calendar)
    }
}

public enum PlannerError: Error, LocalizedError {
    case invalidTask, missingTask, sameDay, noteChanged, invalidNote
    public var errorDescription: String? {
        switch self {
        case .invalidTask: "Enter a task name and select at least one repeat day. Names can contain up to 200 characters."
        case .missingTask: "This task is no longer available. Your draft has not been discarded."
        case .sameDay: "Choose a different date to move this task."
        case .noteChanged: "This note changed on another device. Your text is still here; copy it before reopening the latest note."
        case .invalidNote: "The note is too long. Titles allow 200 characters and notes allow 100,000 characters."
        }
    }
}

public extension AppState {
    /// Keeps legacy IDs and history. No old records are deleted or renamed on disk.
    mutating func migratePlanner(on day: LocalDay) {
        for habit in habits where !planTasks.contains(where: { $0.id == habit.id }) {
            let logged = days.keys.filter { days[$0]?.entries[habit.id] != nil }.min()
            let start = min(habit.settings?.createdOn ?? logged ?? day, logged ?? day)
            planTasks.append(PlanTask(id: habit.id, title: habit.title, notes: habit.settings?.notes ?? "",
                startsOn: start, minute: habit.settings?.timeWindowEnabled == true ? habit.settings?.startMinute : nil,
                weekdays: habit.settings?.weekdays ?? Set(1...7),
                isArchived: habit.isArchived || habit.settings?.isPaused == true))
        }
        for daily in days.values {
            for entry in daily.entries.values {
                guard let task = planTasks.first(where: { $0.id == entry.habitID }),
                      !planOccurrences.contains(where: { $0.taskID == task.id && $0.day == daily.day }) else { continue }
                var occurrence = PlanOccurrence(task: task, day: daily.day)
                switch entry.status {
                case .completed: occurrence.status = .completed
                case .minimum: occurrence.status = .partial
                case .skipped, .rest: occurrence.status = .skipped
                case .pending: break
                }
                planOccurrences.append(occurrence)
            }
        }
    }

    /// Captures a checklist before it is used; later template edits cannot rewrite it.
    mutating func capturePlan(on day: LocalDay) {
        for (index, task) in planTasks.enumerated() where task.includes(day) {
            if !planOccurrences.contains(where: { $0.taskID == task.id && $0.day == day }) {
                let occurrence = projectedOccurrence(task: task, day: day, order: index)
                if task.routineID == nil || !occurrence.steps.isEmpty { planOccurrences.append(occurrence) }
            }
        }
    }

    func plan(on day: LocalDay, includingRemoved: Bool = false) -> [PlanOccurrence] {
        var result = planOccurrences.filter { $0.day == day && (includingRemoved || !$0.isRemoved) }
        for (index, task) in planTasks.enumerated() where task.includes(day) {
            if !planOccurrences.contains(where: { $0.taskID == task.id && $0.day == day }) {
                let occurrence = projectedOccurrence(task: task, day: day, order: index)
                if task.routineID == nil || !occurrence.steps.isEmpty { result.append(occurrence) }
            }
        }
        return result.sorted {
            if $0.minute != $1.minute { return ($0.minute ?? Int.max) < ($1.minute ?? Int.max) }
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id < $1.id
        }
    }

    private func projectedOccurrence(task: PlanTask, day: LocalDay, order: Int) -> PlanOccurrence {
        var occurrence = PlanOccurrence(task: task, day: day, order: order)
        if task.weekdays != nil, let id = task.routineID, let routine = routine(id: id) {
            occurrence.steps = routine.executionSteps(on: day).map {
                PlanStep(id: $0.step.id, title: ($0.path + [$0.step.title]).joined(separator: " / "), notes: $0.step.notes)
            }
        }
        return occurrence
    }

    mutating func savePlanTask(_ task: PlanTask) throws {
        guard task.isValid else { throw PlannerError.invalidTask }
        if let index = planTasks.firstIndex(where: { $0.id == task.id }) { planTasks[index] = task }
        else { planTasks.append(task) }
    }

    mutating func saveOccurrence(_ occurrence: PlanOccurrence) throws {
        guard planTasks.contains(where: { $0.id == occurrence.taskID }) else { throw PlannerError.missingTask }
        let check = PlanTask(title: occurrence.title, notes: occurrence.notes, startsOn: occurrence.day,
                             minute: occurrence.minute, steps: occurrence.steps)
        guard check.isValid else { throw PlannerError.invalidTask }
        if let index = planOccurrences.firstIndex(where: { $0.id == occurrence.id }) { planOccurrences[index] = occurrence }
        else { planOccurrences.append(occurrence) }
    }

    mutating func moveOccurrence(_ occurrence: PlanOccurrence, to day: LocalDay) throws {
        guard occurrence.day != day else { throw PlannerError.sameDay }
        guard occurrence.status != .moved else { throw PlannerError.missingTask }
        // A new one-off avoids overwriting a repeating occurrence already on the target date.
        let task = PlanTask(title: occurrence.title, notes: occurrence.notes, startsOn: day,
                            minute: occurrence.minute, steps: occurrence.steps.map { PlanStep(title: $0.title, notes: $0.notes) })
        var candidate = self
        try candidate.savePlanTask(task)
        var original = occurrence; original.status = .moved; original.movedTo = day
        try candidate.saveOccurrence(original)
        candidate.capturePlan(on: day)
        self = candidate
    }

    mutating func saveNote(_ note: DayNote, expected: DayNote?) throws {
        guard note.isValid else { throw PlannerError.invalidNote }
        let current = dayNotes.first { $0.id == note.id }
        guard current == expected else { throw PlannerError.noteChanged }
        if let index = dayNotes.firstIndex(where: { $0.id == note.id }) { dayNotes[index] = note }
        else if !note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dayNotes.append(note)
        }
    }
}
