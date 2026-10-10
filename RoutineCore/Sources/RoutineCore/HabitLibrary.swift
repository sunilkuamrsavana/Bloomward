import Foundation

public enum HabitLibraryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All", today = "Today", paused = "Paused"
    public var id: Self { self }
}

public extension HabitSettings {
    /// Only used for newly created habits. Never changes a saved user's schedule.
    static var newHabitDefaults: HabitSettings {
        var settings = HabitSettings()
        settings.weekdays = Set(1...7)
        settings.timeWindowEnabled = false
        settings.endOfDayMinute = nil
        return settings
    }
}

public extension AppState {
    func libraryHabits(_ filter: HabitLibraryFilter, on day: LocalDay, calendar: Calendar) -> [Habit] {
        habits.filter { habit in
            guard !habit.isArchived else { return false }
            switch filter {
            case .all: return true
            case .today:
                return habit.settings?.isPaused != true &&
                    (habit.isScheduled(on: day, calendar: calendar) || status(for: habit.id, on: day) != .pending)
            case .paused: return habit.settings?.isPaused == true
            }
        }
    }

    func routines(containing habitID: Habit.ID) -> [Routine] {
        routines.filter { !$0.isArchived && $0.leafSteps.contains { $0.habitID == habitID } }
    }

    /// Standalone creation never depends on a routine. Edits preserve the shared habit identity.
    @discardableResult
    mutating func saveHabit(id: Habit.ID? = nil, title: String, symbol: String,
                            settings: HabitSettings, on day: LocalDay) throws -> Habit.ID {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 60, settings.isValid else { throw HabitSaveError.invalidHabit }
        var settings = settings
        if let id {
            guard let index = habits.firstIndex(where: { $0.id == id && !$0.isArchived }) else {
                throw HabitSaveError.unavailableHabit
            }
            settings.createdOn = habits[index].settings?.createdOn
            habits[index].title = name
            habits[index].symbolName = symbol
            habits[index].settings = settings
            // The runner reads step titles; keep those labels in sync with the linked habit.
            for routineIndex in routines.indices {
                for stepIndex in routines[routineIndex].steps.indices {
                    routines[routineIndex].steps[stepIndex].renameHabit(id, to: name)
                }
            }
            return id
        }
        settings.createdOn = day
        let habit = Habit(title: name, symbolName: symbol,
                          minimumTitle: "A small version of \(name.lowercased())", settings: settings)
        habits.append(habit)
        return habit.id
    }
}

public enum HabitSaveError: Error {
    case invalidHabit, unavailableHabit
}
