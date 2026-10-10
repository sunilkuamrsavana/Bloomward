import XCTest
@testable import RoutineCore

final class RoutineDraftTests: XCTestCase {
    private let day = LocalDay(year: 2026, month: 9, day: 22)

    func testBuildRoutineFromNewHabitsInEmptyAccount() throws {
        let draft = RoutineDraft(title: "Morning Flow", steps: [
            RoutineDraftStep(source: .new(Habit(title: "Water"))),
            RoutineDraftStep(source: .new(Habit(title: "Read")))
        ])
        let state = try draft.applying(to: AppState(), on: day)
        XCTAssertEqual(state.habits.count, 2)
        XCTAssertEqual(state.routines.count, 1)
        XCTAssertEqual(state.routines[0].steps.map(\.habitID), state.habits.map { Optional($0.id) })
        XCTAssertTrue(state.days.isEmpty)
        XCTAssertTrue(state.routineHistory.isEmpty)
        XCTAssertEqual(state.habits[0].settings?.createdOn, day)
    }

    func testReusesExistingHabitWithoutDuplicatingIt() throws {
        let habit = Habit(title: "Read")
        let original = AppState(habits: [habit])
        let draft = RoutineDraft(title: "Evening", steps: [
            RoutineDraftStep(source: .existing(habit.id)),
            RoutineDraftStep(source: .new(Habit(title: "Stretch")))
        ])
        let saved = try draft.applying(to: original, on: day)
        XCTAssertEqual(saved.habits.count, 2)
        XCTAssertEqual(saved.habits[0], habit)
        XCTAssertEqual(saved.routines[0].steps[0].habitID, habit.id)
        XCTAssertEqual(original.habits, [habit])
        XCTAssertTrue(original.routines.isEmpty)
    }

    func testStepOrderIsSavedAfterReordering() throws {
        let first = RoutineDraftStep(source: .new(Habit(title: "Water")))
        let second = RoutineDraftStep(source: .new(Habit(title: "Read")))
        var draft = RoutineDraft(title: "Morning", steps: [first, second])
        draft.steps.swapAt(0, 1)
        let result = try draft.applying(to: AppState(), on: day)
        XCTAssertEqual(result.routines[0].steps.map(\.title), ["Read", "Water"])
        XCTAssertEqual(result.routines[0].steps.map(\.id), [second.id, first.id])
    }

    func testInvalidDraftDoesNotCommitNewHabits() {
        let original = AppState()
        let draft = RoutineDraft(title: "Morning", steps: [
            RoutineDraftStep(source: .new(Habit(title: "Water"))),
            RoutineDraftStep(source: .existing(UUID()))
        ])
        XCTAssertThrowsError(try draft.applying(to: original, on: day))
        XCTAssertTrue(original.habits.isEmpty)
        XCTAssertTrue(original.routines.isEmpty)
    }

    func testRejectsDuplicateHabitAcrossSteps() {
        let habit = Habit(title: "Read")
        let draft = RoutineDraft(title: "Morning", steps: [
            RoutineDraftStep(source: .existing(habit.id)),
            RoutineDraftStep(source: .existing(habit.id))
        ])
        XCTAssertThrowsError(try draft.applying(to: AppState(habits: [habit]), on: day))
    }

    func testRejectsEmptyNameAndSteps() {
        XCTAssertThrowsError(try RoutineDraft(title: "Morning").applying(to: AppState(), on: day))
        XCTAssertThrowsError(try RoutineDraft(title: " ", steps: [
            RoutineDraftStep(source: .new(Habit(title: "Read")))
        ]).applying(to: AppState(), on: day))
    }

    func testRejectsUnavailableHabitAndInvalidNewHabit() {
        var settings = HabitSettings()
        settings.isPaused = true
        let paused = Habit(title: "Read", settings: settings)
        XCTAssertThrowsError(try RoutineDraft(title: "Morning", steps: [
            RoutineDraftStep(source: .existing(paused.id))
        ]).applying(to: AppState(habits: [paused]), on: day))
        settings.isPaused = false
        settings.weekdays = []
        XCTAssertThrowsError(try RoutineDraft(title: "Morning", steps: [
            RoutineDraftStep(source: .new(Habit(title: "Read", settings: settings)))
        ]).applying(to: AppState(), on: day))
    }

    func testSavingAgainCannotDuplicateRoutineOrHabits() throws {
        let draft = RoutineDraft(title: "Morning", steps: [RoutineDraftStep(source: .new(Habit(title: "Read")))])
        let result = try draft.applying(to: AppState(), on: day)
        XCTAssertThrowsError(try draft.applying(to: result, on: day))
        XCTAssertEqual(result.habits.count, 1)
        XCTAssertEqual(result.routines.count, 1)
    }

    func testCompletingLinkedStepLogsExistingHabitOnce() throws {
        let habit = Habit(title: "Read")
        let draft = RoutineDraft(title: "Evening", steps: [RoutineDraftStep(source: .existing(habit.id))])
        var state = try draft.applying(to: AppState(habits: [habit]), on: day)
        let time = Date()
        AppReducer.reduce(state: &state, action: .startRoutine(routineID: draft.id, day: day, at: time))
        AppReducer.reduce(state: &state, action: .advanceRoutine(at: time.addingTimeInterval(1)))
        XCTAssertEqual(state.status(for: habit.id, on: day), .completed)
        XCTAssertEqual(state.days[day]?.entries.count, 1)
    }
}
