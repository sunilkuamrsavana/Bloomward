import Foundation
import XCTest
@testable import RoutineCore

final class AppReducerTests: XCTestCase {
    private let day = LocalDay(year: 2026, month: 9, day: 20)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let later = Date(timeIntervalSince1970: 1_800_000_060)

    func testToggleHabitCompletesThenReturnsToPending() {
        let habit = Habit(id: fixedID(1), title: "Drink water")
        var state = AppState(habits: [habit])

        XCTAssertEqual(
            AppReducer.reduce(
                state: &state,
                action: .toggleHabit(habitID: habit.id, day: day, at: start)
            ),
            .applied
        )
        XCTAssertEqual(state.status(for: habit.id, on: day), .completed)
        XCTAssertEqual(state.entry(for: habit.id, on: day)?.updatedAt, start)

        AppReducer.reduce(
            state: &state,
            action: .toggleHabit(habitID: habit.id, day: day, at: later)
        )

        XCTAssertEqual(state.status(for: habit.id, on: day), .pending)
        XCTAssertEqual(state.entry(for: habit.id, on: day)?.updatedAt, later)
    }

    func testRecoveryChoicesMapToExplicitDailyStatuses() {
        let habit = Habit(id: fixedID(2), title: "Walk", minimumTitle: "Walk for 2 minutes")
        var state = AppState(habits: [habit])

        AppReducer.reduce(
            state: &state,
            action: .recoverHabit(
                habitID: habit.id,
                day: day,
                choice: .minimum,
                at: start
            )
        )
        XCTAssertEqual(state.status(for: habit.id, on: day), .minimum)

        AppReducer.reduce(
            state: &state,
            action: .recoverHabit(
                habitID: habit.id,
                day: day,
                choice: .skip,
                at: later
            )
        )
        XCTAssertEqual(state.status(for: habit.id, on: day), .skipped)

        AppReducer.reduce(
            state: &state,
            action: .recoverHabit(
                habitID: habit.id,
                day: day,
                choice: .rest,
                at: later
            )
        )
        XCTAssertEqual(state.status(for: habit.id, on: day), .rest)
    }

    func testRecoveryDoesNotDowngradeCompletedHabit() {
        let habit = Habit(id: fixedID(3), title: "Read")
        var state = AppState(habits: [habit])
        AppReducer.reduce(
            state: &state,
            action: .toggleHabit(habitID: habit.id, day: day, at: start)
        )

        let result = AppReducer.reduce(
            state: &state,
            action: .recoverHabit(
                habitID: habit.id,
                day: day,
                choice: .rest,
                at: later
            )
        )

        XCTAssertEqual(result, .ignored(.habitAlreadyCompleted))
        XCTAssertEqual(state.status(for: habit.id, on: day), .completed)
        XCTAssertEqual(state.entry(for: habit.id, on: day)?.updatedAt, start)
    }

    func testAdvancingAndSkippingRoutineCreatesPartialRunAndUpdatesHabits() throws {
        let firstHabit = Habit(id: fixedID(10), title: "Make bed")
        let secondHabit = Habit(id: fixedID(11), title: "Journal")
        let routine = Routine(
            id: fixedID(12),
            title: "Morning",
            steps: [
                RoutineStep(id: fixedID(13), title: firstHabit.title, habitID: firstHabit.id),
                RoutineStep(id: fixedID(14), title: secondHabit.title, habitID: secondHabit.id),
            ]
        )
        var state = AppState(habits: [firstHabit, secondHabit], routines: [routine])

        XCTAssertEqual(
            AppReducer.reduce(
                state: &state,
                action: .startRoutine(routineID: routine.id, day: day, at: start)
            ),
            .applied
        )
        XCTAssertEqual(state.activeRoutine?.currentStepIndex, 0)
        XCTAssertEqual(state.activeRoutine?.outcomes, [.pending, .pending])

        AppReducer.reduce(state: &state, action: .advanceRoutine(at: later))

        XCTAssertEqual(state.activeRoutine?.currentStepIndex, 1)
        XCTAssertEqual(state.activeRoutine?.outcomes, [.completed, .pending])
        XCTAssertEqual(state.activeRoutine?.currentStepStartedAt, later)
        XCTAssertEqual(state.status(for: firstHabit.id, on: day), .completed)

        let end = Date(timeIntervalSince1970: 1_800_000_120)
        AppReducer.reduce(state: &state, action: .skipRoutineStep(at: end))

        XCTAssertNil(state.activeRoutine)
        XCTAssertEqual(state.status(for: secondHabit.id, on: day), .skipped)
        let run = try XCTUnwrap(state.routineHistory.last)
        XCTAssertEqual(run.outcomes, [.completed, .skipped])
        XCTAssertEqual(run.result, .partial)
        XCTAssertEqual(run.startedAt, start)
        XCTAssertEqual(run.endedAt, end)
    }

    func testCompleteRoutineCompletesEveryRemainingStep() throws {
        let firstHabit = Habit(id: fixedID(20), title: "Stretch")
        let secondHabit = Habit(id: fixedID(21), title: "Breathe")
        let routine = Routine(
            id: fixedID(22),
            title: "Reset",
            steps: [
                RoutineStep(id: fixedID(23), title: firstHabit.title, habitID: firstHabit.id),
                RoutineStep(id: fixedID(24), title: secondHabit.title, habitID: secondHabit.id),
            ]
        )
        var state = AppState(habits: [firstHabit, secondHabit], routines: [routine])
        AppReducer.reduce(
            state: &state,
            action: .startRoutine(routineID: routine.id, day: day, at: start)
        )

        AppReducer.reduce(state: &state, action: .completeRoutine(at: later))

        XCTAssertNil(state.activeRoutine)
        XCTAssertEqual(state.status(for: firstHabit.id, on: day), .completed)
        XCTAssertEqual(state.status(for: secondHabit.id, on: day), .completed)
        let run = try XCTUnwrap(state.routineHistory.last)
        XCTAssertEqual(run.outcomes, [.completed, .completed])
        XCTAssertEqual(run.result, .completed)
    }

    func testInvalidActionsAreNoOps() {
        let emptyRoutine = Routine(id: fixedID(30), title: "Empty", steps: [])
        var state = AppState(routines: [emptyRoutine])
        let original = state

        XCTAssertEqual(
            AppReducer.reduce(
                state: &state,
                action: .startRoutine(routineID: emptyRoutine.id, day: day, at: start)
            ),
            .ignored(.routineHasNoSteps)
        )
        XCTAssertEqual(state, original)

        XCTAssertEqual(
            AppReducer.reduce(state: &state, action: .advanceRoutine(at: later)),
            .ignored(.noActiveRoutine)
        )
        XCTAssertEqual(state, original)
    }

    func testStartingSecondRoutineWhileOneIsActiveIsIgnored() {
        let first = Routine(
            id: fixedID(40),
            title: "First",
            steps: [RoutineStep(id: fixedID(41), title: "Step")]
        )
        let second = Routine(
            id: fixedID(42),
            title: "Second",
            steps: [RoutineStep(id: fixedID(43), title: "Step")]
        )
        var state = AppState(routines: [first, second])
        AppReducer.reduce(
            state: &state,
            action: .startRoutine(routineID: first.id, day: day, at: start)
        )
        let activeBeforeAttempt = state.activeRoutine

        let result = AppReducer.reduce(
            state: &state,
            action: .startRoutine(routineID: second.id, day: day, at: later)
        )

        XCTAssertEqual(result, .ignored(.routineAlreadyActive))
        XCTAssertEqual(state.activeRoutine, activeBeforeAttempt)
    }

    func testRoutineDoesNotUpdateArchivedLinkedHabit() {
        let habit = Habit(id: fixedID(50), title: "Archived", isArchived: true)
        let routine = Routine(
            id: fixedID(51),
            title: "Morning",
            steps: [RoutineStep(id: fixedID(52), title: habit.title, habitID: habit.id)]
        )
        var state = AppState(habits: [habit], routines: [routine])

        AppReducer.reduce(
            state: &state,
            action: .startRoutine(routineID: routine.id, day: day, at: start)
        )
        AppReducer.reduce(state: &state, action: .advanceRoutine(at: later))

        XCTAssertEqual(state.status(for: habit.id, on: day), .pending)
        XCTAssertNil(state.entry(for: habit.id, on: day))
        XCTAssertEqual(state.routineHistory.last?.result, .completed)
    }

    func testPausingAndResumingPreservesRemainingStepTime() {
        let routine = Routine(
            id: fixedID(60),
            title: "Focus",
            steps: [RoutineStep(id: fixedID(61), title: "Write", estimatedDurationSeconds: 300)]
        )
        var state = AppState(routines: [routine])
        AppReducer.reduce(
            state: &state,
            action: .startRoutine(routineID: routine.id, day: day, at: start)
        )

        let pausedAt = start.addingTimeInterval(30)
        XCTAssertEqual(
            AppReducer.reduce(state: &state, action: .pauseRoutine(at: pausedAt)),
            .applied
        )
        XCTAssertEqual(state.activeRoutine?.pausedAt, pausedAt)

        let resumedAt = start.addingTimeInterval(90)
        XCTAssertEqual(
            AppReducer.reduce(state: &state, action: .resumeRoutine(at: resumedAt)),
            .applied
        )
        XCTAssertNil(state.activeRoutine?.pausedAt)
        XCTAssertEqual(
            state.activeRoutine?.currentStepStartedAt,
            start.addingTimeInterval(60)
        )
    }

    func testActiveRoutineDecodesLegacyTimingSchema() throws {
        let routineID = fixedID(70)
        let legacy = LegacyActiveRoutine(
            routineID: routineID,
            day: day,
            startedAt: start,
            currentStepIndex: 1,
            outcomes: [.completed, .pending]
        )

        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(ActiveRoutine.self, from: data)

        XCTAssertEqual(decoded.routineID, routineID)
        XCTAssertEqual(decoded.currentStepStartedAt, start)
        XCTAssertEqual(decoded.pausedAt, start)
        XCTAssertEqual(decoded.currentStepIndex, 1)
        XCTAssertEqual(decoded.outcomes, [.completed, .pending])
    }

    func testMalformedRoutineSessionIsRejectedWithoutIndexingPastSteps() {
        let routine = Routine(
            id: fixedID(80),
            title: "Short routine",
            steps: [RoutineStep(id: fixedID(81), title: "Only step")]
        )
        let malformed = ActiveRoutine(
            routineID: routine.id,
            day: day,
            startedAt: start,
            outcomes: [.pending, .pending]
        )
        var state = AppState(routines: [routine], activeRoutine: malformed)

        XCTAssertEqual(
            AppReducer.reduce(state: &state, action: .completeRoutine(at: later)),
            .ignored(.routineSessionInvalid)
        )
        XCTAssertEqual(state.activeRoutine, malformed)
        XCTAssertTrue(state.routineHistory.isEmpty)
    }

    func testPausedRoutineRejectsProgressAndInvalidClockOrder() {
        let routine = Routine(
            id: fixedID(90),
            title: "Reset",
            steps: [RoutineStep(id: fixedID(91), title: "Breathe")]
        )
        var state = AppState(routines: [routine])
        AppReducer.reduce(
            state: &state,
            action: .startRoutine(routineID: routine.id, day: day, at: start)
        )

        XCTAssertEqual(
            AppReducer.reduce(
                state: &state,
                action: .pauseRoutine(at: start.addingTimeInterval(-1))
            ),
            .ignored(.invalidTimestamp)
        )

        AppReducer.reduce(state: &state, action: .pauseRoutine(at: later))
        let pausedState = state

        XCTAssertEqual(
            AppReducer.reduce(
                state: &state,
                action: .resumeRoutine(at: later.addingTimeInterval(-1))
            ),
            .ignored(.invalidTimestamp)
        )
        XCTAssertEqual(state, pausedState)

        XCTAssertEqual(
            AppReducer.reduce(
                state: &state,
                action: .advanceRoutine(at: later.addingTimeInterval(1))
            ),
            .ignored(.routinePaused)
        )
        XCTAssertEqual(state, pausedState)
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

private struct LegacyActiveRoutine: Encodable {
    let routineID: Routine.ID
    let day: LocalDay
    let startedAt: Date
    let currentStepIndex: Int
    let outcomes: [RoutineStepOutcome]
}
