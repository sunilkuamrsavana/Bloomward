import XCTest
@testable import RoutineCore

final class FirstRunTests: XCTestCase {
    let day = LocalDay(year: 2026, month: 9, day: 22)
    func testNoAutomaticSelectionOrData() {
        let draft = FirstRunDraft()
        XCTAssertNil(draft.choice)
        XCTAssertNil(draft.habit)
        XCTAssertNil(draft.plan(on: day))
        XCTAssertFalse(draft.reminderEnabled)
    }
    func testSelectedHabitIsPendingAndStartsToday() throws {
        var draft = FirstRunDraft(); draft.choice = .habit; draft.habit = .water
        let state = try XCTUnwrap(draft.plan(on: day))
        XCTAssertEqual(state.habits.count, 1)
        XCTAssertEqual(state.habits[0].settings?.createdOn, day)
        XCTAssertEqual(state.status(for: state.habits[0].id, on: day), .pending)
        XCTAssertTrue(state.days.isEmpty)
        XCTAssertTrue(state.routines.isEmpty)
        XCTAssertEqual(draft.plan(on: day)?.habits, state.habits)
    }
    func testCustomNameAndScheduleValidation() {
        var draft = FirstRunDraft(); draft.choice = .habit; draft.habit = .custom
        XCTAssertNil(draft.plan(on: day))
        draft.customName = "  Journal  "
        XCTAssertEqual(draft.plan(on: day)?.habits.first?.title, "Journal")
        draft.weekdays = []; XCTAssertNil(draft.plan(on: day))
        draft.weekdays = [8]; XCTAssertNil(draft.plan(on: day))
        draft.weekdays = [2]; draft.reminderMinute = 1440; XCTAssertNil(draft.plan(on: day))
    }
    func testRoutineIsOnlyCreatedByExplicitChoice() throws {
        var draft = FirstRunDraft(); draft.choice = .routine
        let plan = try XCTUnwrap(draft.plan(on: day))
        XCTAssertEqual(plan.habits.count, 3)
        XCTAssertEqual(plan.routines.first?.steps.compactMap(\.habitID), plan.habits.map(\.id))
        XCTAssertNil(plan.activeRoutine)
        XCTAssertTrue(plan.routineHistory.isEmpty)
    }
    func testDraftRoundTripPreservesChoicesAndIdentity() throws {
        var draft = FirstRunDraft(); draft.step = .setup; draft.choice = .habit
        draft.habit = .read; draft.goal = 10; draft.weekdays = [2, 4, 6]
        let restored = try JSONDecoder().decode(FirstRunDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(restored, draft)
        XCTAssertEqual(restored.habitTitle, "Read for 10 Minutes")
    }
    func testImportKeepsBothAccountsDataAndDoesNotDuplicate() {
        let local = Habit(title: "Read")
        let remote = Habit(title: "Walk")
        let guest = AppState(habits: [local])
        let account = AppState(habits: [remote])
        let merged = LocalAccountImport.merging(guest: guest, into: account)
        XCTAssertEqual(Set(merged.habits.map(\.id)), [local.id, remote.id])
        XCTAssertEqual(LocalAccountImport.merging(guest: guest, into: merged), merged)
        XCTAssertEqual(guest.habits, [local])
        XCTAssertEqual(account.habits, [remote])
    }
    func testImportNeverOverwritesAccountConflict() {
        let local = Habit(title: "Old name")
        var remote = local; remote.title = "Account name"
        let result = LocalAccountImport.merging(guest: AppState(habits: [local]), into: AppState(habits: [remote]))
        XCTAssertEqual(result.habits, [remote])
    }
    func testImportRetainsRealCompletionWithoutInventingAnotherDay() throws {
        let habit = Habit(title: "Read")
        var guest = AppState(habits: [habit])
        _ = AppReducer.reduce(state: &guest, action: .toggleHabit(habitID: habit.id, day: day, at: Date()))
        let result = LocalAccountImport.merging(guest: guest, into: AppState())
        XCTAssertEqual(result.status(for: habit.id, on: day), .completed)
        XCTAssertEqual(result.days.count, 1)
        XCTAssertTrue(result.routineHistory.isEmpty)
    }
    func testUnscheduledFirstDayStaysEmptyAndHabitHasSelectedDays() throws {
        var draft = FirstRunDraft(); draft.choice = .habit; draft.habit = .read
        draft.weekdays = [2, 4, 6]
        let plan = try XCTUnwrap(draft.plan(on: day))
        XCTAssertEqual(plan.habits[0].settings?.weekdays, [2, 4, 6])
        XCTAssertFalse(plan.habits[0].isScheduled(on: day, calendar: Calendar(identifier: .gregorian)))
        XCTAssertTrue(plan.days.isEmpty)
    }
    func testInvalidGoalAndOverlongCustomNameCannotCreateData() {
        var draft = FirstRunDraft(); draft.choice = .habit; draft.habit = .water
        draft.goal = 0; XCTAssertNil(draft.plan(on: day))
        draft.goal = 61; XCTAssertNil(draft.plan(on: day))
        draft.goal = 1; draft.habit = .custom; draft.customName = String(repeating: "a", count: 61)
        XCTAssertNil(draft.plan(on: day))
    }
}
