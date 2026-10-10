import XCTest
@testable import RoutineCore

final class RoutineStructureTests: XCTestCase {
    let monday = LocalDay(year: 2026, month: 9, day: 21)
    let tuesday = LocalDay(year: 2026, month: 9, day: 22)
    let now = Date(timeIntervalSinceReferenceDate: 100)

    func testSimpleStepsAndSubRoutinesNeedNoHabits() throws {
        let draft = RoutineDraft(title: "Morning", steps: [
            .init(source: .action("Open curtains")),
            .init(source: .group("Skincare", [.init(source: .action("Wash")), .init(source: .action("Moisturize"))]))
        ])
        let state = try draft.applying(to: AppState(), on: monday)
        XCTAssertTrue(state.habits.isEmpty)
        XCTAssertEqual(state.routines[0].leafSteps.map(\.title), ["Open curtains", "Wash", "Moisturize"])
        XCTAssertEqual(state.routines[0].executionSteps(on: monday).last?.path, ["Skincare"])
    }

    func testScheduleInheritanceAndIntersection() {
        let routine = Routine(title: "Home", steps: [
            RoutineStep(title: "Every time"),
            RoutineStep(title: "Care", children: [
                RoutineStep(title: "Wash"),
                RoutineStep(title: "Weekly", schedule: .init(weekdays: [2]))
            ], schedule: .init(weekdays: [2, 3]))
        ], schedule: .init(weekdays: [2, 3]))
        XCTAssertEqual(routine.executionSteps(on: monday).map(\.step.title), ["Every time", "Wash", "Weekly"])
        XCTAssertEqual(routine.executionSteps(on: tuesday).map(\.step.title), ["Every time", "Wash"])
        XCTAssertTrue(routine.executionSteps(on: LocalDay(year: 2026, month: 9, day: 23)).isEmpty)
    }

    func testNoEligibleStepsDoesNotStartAnEmptyRun() {
        let routine = Routine(title: "Mondays", steps: [.init(title: "Step")], schedule: .init(weekdays: [2]))
        var state = AppState(routines: [routine])
        XCTAssertEqual(AppReducer.reduce(state: &state, action: .startRoutine(routineID: routine.id, day: tuesday, at: now)), .ignored(.routineHasNoSteps))
        XCTAssertNil(state.activeRoutine)
    }

    func testNestedRunnerFreezesEligibleStepsAndCanResumeAfterDecode() throws {
        let habit = Habit(title: "Water")
        let routine = Routine(title: "Morning", steps: [
            .init(title: "Care", children: [
                .init(title: "Wash", estimatedDurationSeconds: 120),
                .init(title: "Water", habitID: habit.id),
                .init(title: "Tuesday only", schedule: .init(weekdays: [3]))
            ])
        ])
        var state = AppState(habits: [habit], routines: [routine])
        AppReducer.reduce(state: &state, action: .startRoutine(routineID: routine.id, day: monday, at: now))
        XCTAssertEqual(state.activeRoutine?.outcomes.count, 2)
        state.routines[0].steps.removeAll()
        state = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(AppReducer.reduce(state: &state, action: .skipRoutineStep(at: now)), .applied)
        XCTAssertEqual(AppReducer.reduce(state: &state, action: .advanceRoutine(at: now)), .applied)
        XCTAssertNil(state.activeRoutine)
        XCTAssertEqual(state.status(for: habit.id, on: monday), .completed)
        XCTAssertEqual(state.routineHistory[0].outcomes, [.skipped, .completed])
    }

    func testCompleteAllOnlyLogsEligibleLinkedHabits() {
        let mondayHabit = Habit(title: "Monday"), tuesdayHabit = Habit(title: "Tuesday")
        let routine = Routine(title: "Care", steps: [.init(title: "Group", children: [
            .init(title: "Monday", habitID: mondayHabit.id),
            .init(title: "Tuesday", habitID: tuesdayHabit.id, schedule: .init(weekdays: [3]))
        ])])
        var state = AppState(habits: [mondayHabit, tuesdayHabit], routines: [routine])
        AppReducer.reduce(state: &state, action: .startRoutine(routineID: routine.id, day: monday, at: now))
        AppReducer.reduce(state: &state, action: .completeRoutine(at: now))
        XCTAssertEqual(state.status(for: mondayHabit.id, on: monday), .completed)
        XCTAssertEqual(state.status(for: tuesdayHabit.id, on: monday), .pending)
    }

    func testEditingPreservesRoutineAndStepIDsAndDoesNotCreateHabits() throws {
        let routine = Routine(title: "Old", steps: [.init(title: "Group", children: [.init(title: "Step", notes: "Note")])])
        var draft = RoutineDraft(routine: routine)
        draft.title = "New"
        let saved = try draft.applying(to: AppState(routines: [routine]), on: monday, updating: true)
        XCTAssertEqual(saved.routines.count, 1)
        XCTAssertEqual(saved.routines[0].id, routine.id)
        XCTAssertEqual(saved.routines[0].steps, routine.steps)
        XCTAssertTrue(saved.habits.isEmpty)
    }

    func testInvalidNestedDraftsAreAtomic() {
        let habit = Habit(title: "Read")
        let cases: [[RoutineDraftStep]] = [
            [.init(source: .group("Empty", []))],
            [.init(source: .group("Group", [.init(source: .action("  "))]))],
            [.init(source: .group("Group", [.init(source: .existing(habit.id))])), .init(source: .existing(habit.id))],
            [.init(source: .action("Step"), schedule: .init(weekdays: []))],
            [.init(source: .group("Monday", [.init(source: .action("Tuesday"), schedule: .init(weekdays: [3]))]), schedule: .init(weekdays: [2]))]
        ]
        let original = AppState(habits: [habit])
        for steps in cases { XCTAssertThrowsError(try RoutineDraft(title: "Test", steps: steps).applying(to: original, on: monday)) }
        XCTAssertTrue(original.routines.isEmpty)
    }

    func testRejectsDuplicateIDsAcrossBranchesAndExcessDepth() {
        let repeated = RoutineDraftStep(source: .action("Step"))
        let duplicate = RoutineDraft(title: "Test", steps: [repeated, .init(source: .group("Group", [repeated]))])
        XCTAssertThrowsError(try duplicate.applying(to: AppState(), on: monday))
        var nested = RoutineDraftStep(source: .action("Step"))
        for _ in 0..<5 { nested = .init(source: .group("Group", [nested])) }
        XCTAssertThrowsError(try RoutineDraft(title: "Deep", steps: [nested]).applying(to: AppState(), on: monday))
    }

    func testOldFlatRoutineAndActiveRunDecodeWithoutNewFields() throws {
        let routine = Routine(title: "Original", steps: [.init(title: "One"), .init(title: "Two")])
        var state = AppState(routines: [routine], activeRoutine: ActiveRoutine(routineID: routine.id, day: monday,
                             startedAt: now, outcomes: [.pending, .pending]))
        let data = try JSONEncoder().encode(state)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("children"))
        state = try JSONDecoder().decode(AppState.self, from: data)
        XCTAssertNil(state.routines[0].schedule)
        XCTAssertEqual(AppReducer.reduce(state: &state, action: .completeRoutine(at: now)), .applied)
    }

    func testNestedCloudRoundTripAndRename() throws {
        let habit = Habit(title: "Read")
        let routine = Routine(title: "Home", steps: [.init(title: "Group", children: [
            .init(title: "Read", habitID: habit.id, estimatedDurationSeconds: 600, schedule: .init(weekdays: [2]), notes: "A chapter")
        ])])
        var state = AppState(habits: [habit], routines: [routine])
        let snapshot = SyncSnapshot(state: state)
        XCTAssertEqual(try JSONDecoder().decode(SyncSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
        XCTAssertEqual(state.routines(containing: habit.id).count, 1)
        try state.saveHabit(id: habit.id, title: "Reading", symbol: "book", settings: .newHabitDefaults, on: monday)
        XCTAssertEqual(state.routines[0].leafSteps.first?.title, "Reading")
        XCTAssertEqual(state.routines[0].leafSteps.first?.notes, "A chapter")
    }

    func testQuickLogAndNextNeverDuplicateAndKeepCompletionInPlace() {
        let habits = (1...6).map { Habit(title: "Habit \($0)") }
        var state = AppState(habits: habits)
        var sections = TodayHabitSections(habits: habits, day: monday, state: state, minute: 600)
        XCTAssertEqual(sections.quickLog.count, 4)
        XCTAssertEqual(sections.next.count, 2)
        XCTAssertTrue(Set(sections.quickLog.map(\.id)).isDisjoint(with: sections.next.map(\.id)))
        AppReducer.reduce(state: &state, action: .toggleHabit(habitID: habits[0].id, day: monday, at: now))
        sections = TodayHabitSections(habits: habits, day: monday, state: state, minute: 600)
        XCTAssertEqual(sections.quickLog.map(\.id), Array(habits.prefix(4)).map(\.id))
    }

    func testQuickLogSingleAndFutureHabitPlacement() {
        let habit = Habit(title: "Anytime")
        var settings = HabitSettings.newHabitDefaults
        settings.timeWindowEnabled = true
        settings.startMinute = 960
        let later = Habit(title: "Later", settings: settings)
        let sections = TodayHabitSections(habits: [habit, later], day: monday, state: AppState(), minute: 600)
        XCTAssertEqual(sections.quickLog, [habit])
        XCTAssertEqual(sections.next, [later])
        let single = TodayHabitSections(habits: [habit], day: monday, state: AppState(), minute: 600)
        XCTAssertEqual(single.quickLog, [habit])
        XCTAssertTrue(single.next.isEmpty)
    }
}
