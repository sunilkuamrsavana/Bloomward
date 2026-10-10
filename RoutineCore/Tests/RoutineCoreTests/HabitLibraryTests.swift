import XCTest
@testable import RoutineCore

final class HabitLibraryTests: XCTestCase {
    private let tuesday = LocalDay(year: 2026, month: 9, day: 22)
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testStandaloneHabitAppearsWithoutCreatingRoutine() throws {
        var state = AppState()
        let id = try state.saveHabit(title: "Read", symbol: "book", settings: .newHabitDefaults, on: tuesday)
        XCTAssertEqual(state.libraryHabits(.all, on: tuesday, calendar: calendar).map(\.id), [id])
        XCTAssertEqual(state.libraryHabits(.today, on: tuesday, calendar: calendar).map(\.id), [id])
        XCTAssertTrue(state.routines.isEmpty)
    }

    func testOffDayHabitRemainsInAllAndAvailableToRoutinePicker() throws {
        var settings = HabitSettings.newHabitDefaults
        settings.weekdays = [2, 4, 6]
        var state = AppState()
        let id = try state.saveHabit(title: "Walk", symbol: "figure.walk", settings: settings, on: tuesday)
        XCTAssertEqual(state.libraryHabits(.all, on: tuesday, calendar: calendar).map(\.id), [id])
        XCTAssertTrue(state.libraryHabits(.today, on: tuesday, calendar: calendar).isEmpty)
        let draft = RoutineDraft(title: "Move", steps: [RoutineDraftStep(source: .existing(id))])
        let linked = try draft.applying(to: state, on: tuesday)
        XCTAssertEqual(linked.habits.count, 1)
        XCTAssertEqual(linked.routines(containing: id).map(\.id), [draft.id])
    }

    func testNewHabitDefaultsUseEveryDayWithoutInventedTime() {
        let settings = HabitSettings.newHabitDefaults
        XCTAssertEqual(settings.weekdays, Set(1...7))
        XCTAssertFalse(settings.timeWindowEnabled)
        XCTAssertNil(settings.endOfDayMinute)
        XCTAssertTrue(settings.isValid)
    }

    func testPausedAndArchivedFiltersAreExplicit() {
        var settings = HabitSettings.newHabitDefaults
        settings.isPaused = true
        let paused = Habit(title: "Rest", settings: settings)
        let active = Habit(title: "Read", settings: .newHabitDefaults)
        let archived = Habit(title: "Old", isArchived: true)
        let state = AppState(habits: [paused, active, archived])
        XCTAssertEqual(state.libraryHabits(.all, on: tuesday, calendar: calendar).map(\.id), [paused.id, active.id])
        XCTAssertEqual(state.libraryHabits(.paused, on: tuesday, calendar: calendar).map(\.id), [paused.id])
        XCTAssertEqual(state.libraryHabits(.today, on: tuesday, calendar: calendar).map(\.id), [active.id])
    }

    func testRenameUpdatesAllLinkedRoutineLabelsWithoutChangingIdentity() throws {
        let habit = Habit(title: "Read", settings: .newHabitDefaults)
        let step = RoutineStep(title: "Read", habitID: habit.id)
        var state = AppState(habits: [habit], routines: [
            Routine(title: "Morning", steps: [step]), Routine(title: "Evening", steps: [step])
        ])
        let id = try state.saveHabit(id: habit.id, title: "Read a chapter", symbol: "book", settings: .newHabitDefaults, on: tuesday)
        XCTAssertEqual(id, habit.id)
        XCTAssertEqual(state.habits.count, 1)
        XCTAssertTrue(state.routines.allSatisfy { $0.steps[0].id == step.id && $0.steps[0].habitID == habit.id && $0.steps[0].title == "Read a chapter" })
    }

    func testEditingPreservesScheduleAndCreationDay() throws {
        var settings = HabitSettings.newHabitDefaults
        settings.weekdays = [7]
        settings.createdOn = LocalDay(year: 2026, month: 9, day: 19)
        let habit = Habit(title: "Walk", settings: settings)
        var state = AppState(habits: [habit])
        try state.saveHabit(id: habit.id, title: "Walk outside", symbol: "leaf", settings: settings, on: tuesday)
        XCTAssertEqual(state.habits[0].settings, settings)
        XCTAssertTrue(state.libraryHabits(.today, on: tuesday, calendar: calendar).isEmpty)
    }

    func testSavedStandaloneHabitSurvivesStorageRoundTrip() throws {
        var state = AppState()
        let id = try state.saveHabit(title: "Read", symbol: "book", settings: .newHabitDefaults, on: tuesday)
        let restored = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.libraryHabits(.all, on: tuesday, calendar: calendar).map(\.id), [id])
        XCTAssertTrue(restored.routines.isEmpty)
    }

    func testInvalidAndMissingHabitEditsDoNotMutateState() throws {
        var state = AppState()
        XCTAssertThrowsError(try state.saveHabit(title: " ", symbol: "book", settings: .newHabitDefaults, on: tuesday))
        XCTAssertThrowsError(try state.saveHabit(id: UUID(), title: "Read", symbol: "book", settings: .newHabitDefaults, on: tuesday))
        XCTAssertTrue(state.habits.isEmpty)
    }

    func testStandaloneAndRoutineCompletionUseOneDailyRecord() throws {
        var state = AppState()
        let id = try state.saveHabit(title: "Read", symbol: "book", settings: .newHabitDefaults, on: tuesday)
        let draft = RoutineDraft(title: "Morning", steps: [RoutineDraftStep(source: .existing(id))])
        state = try draft.applying(to: state, on: tuesday)
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        AppReducer.reduce(state: &state, action: .toggleHabit(habitID: id, day: tuesday, at: now))
        AppReducer.reduce(state: &state, action: .startRoutine(routineID: draft.id, day: tuesday, at: now))
        AppReducer.reduce(state: &state, action: .advanceRoutine(at: now.addingTimeInterval(1)))
        XCTAssertEqual(state.status(for: id, on: tuesday), .completed)
        XCTAssertEqual(state.days[tuesday]?.entries.count, 1)
        XCTAssertEqual(state.habits.count, 1)
    }
}
