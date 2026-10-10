import Foundation

public enum AppAction: Equatable, Sendable {
    case toggleHabit(habitID: Habit.ID, day: LocalDay, at: Date)
    case startRoutine(routineID: Routine.ID, day: LocalDay, at: Date)
    case advanceRoutine(at: Date)
    case skipRoutineStep(at: Date)
    case pauseRoutine(at: Date)
    case resumeRoutine(at: Date)
    case completeRoutine(at: Date)
    case recoverHabit(habitID: Habit.ID, day: LocalDay, choice: RecoveryChoice, at: Date)
}

public enum ReductionResult: Equatable, Sendable {
    case applied
    case ignored(IgnoredActionReason)
}

public enum IgnoredActionReason: Equatable, Sendable {
    case habitNotFound
    case habitArchived
    case habitAlreadyCompleted
    case routineNotFound
    case routineArchived
    case routineHasNoSteps
    case routineAlreadyActive
    case routineAlreadyPaused
    case routineNotPaused
    case routinePaused
    case routineSessionInvalid
    case invalidTimestamp
    case noActiveRoutine
}

public enum AppReducer {
    @discardableResult
    public static func reduce(
        state: inout AppState,
        action: AppAction
    ) -> ReductionResult {
        switch action {
        case let .toggleHabit(habitID, day, date):
            return toggleHabit(habitID, on: day, at: date, state: &state)

        case let .startRoutine(routineID, day, date):
            return startRoutine(routineID, on: day, at: date, state: &state)

        case let .advanceRoutine(date):
            return resolveCurrentStep(as: .completed, at: date, state: &state)

        case let .skipRoutineStep(date):
            return resolveCurrentStep(as: .skipped, at: date, state: &state)

        case let .pauseRoutine(date):
            return pauseRoutine(at: date, state: &state)

        case let .resumeRoutine(date):
            return resumeRoutine(at: date, state: &state)

        case let .completeRoutine(date):
            return completeRoutine(at: date, state: &state)

        case let .recoverHabit(habitID, day, choice, date):
            return recoverHabit(
                habitID,
                on: day,
                choice: choice,
                at: date,
                state: &state
            )
        }
    }

    private static func toggleHabit(
        _ habitID: Habit.ID,
        on day: LocalDay,
        at date: Date,
        state: inout AppState
    ) -> ReductionResult {
        guard let habit = state.habit(id: habitID) else {
            return .ignored(.habitNotFound)
        }
        guard !habit.isArchived else {
            return .ignored(.habitArchived)
        }

        let newStatus: DailyHabitStatus = state.status(for: habitID, on: day) == .completed
            ? .pending
            : .completed
        state.setStatus(newStatus, for: habitID, on: day, at: date)
        return .applied
    }

    private static func startRoutine(
        _ routineID: Routine.ID,
        on day: LocalDay,
        at date: Date,
        state: inout AppState
    ) -> ReductionResult {
        guard state.activeRoutine == nil else {
            return .ignored(.routineAlreadyActive)
        }
        guard let routine = state.routine(id: routineID) else {
            return .ignored(.routineNotFound)
        }
        guard !routine.isArchived else {
            return .ignored(.routineArchived)
        }
        let plan = routine.executionSteps(on: day)
        guard !plan.isEmpty else {
            return .ignored(.routineHasNoSteps)
        }

        state.activeRoutine = ActiveRoutine(
            routineID: routine.id,
            day: day,
            startedAt: date,
            outcomes: Array(repeating: .pending, count: plan.count),
            plan: plan
        )
        return .applied
    }

    private static func resolveCurrentStep(
        as outcome: RoutineStepOutcome,
        at date: Date,
        state: inout AppState
    ) -> ReductionResult {
        guard var activeRoutine = state.activeRoutine else {
            return .ignored(.noActiveRoutine)
        }
        guard let routine = state.routine(id: activeRoutine.routineID) else {
            return .ignored(.routineNotFound)
        }
        let steps = activeRoutine.executionSteps(in: routine).map(\.step)
        guard steps.count == activeRoutine.outcomes.count else {
            return .ignored(.routineSessionInvalid)
        }
        guard activeRoutine.pausedAt == nil else {
            return .ignored(.routinePaused)
        }
        guard date >= activeRoutine.currentStepStartedAt else {
            return .ignored(.invalidTimestamp)
        }

        let index = activeRoutine.currentStepIndex
        guard steps.indices.contains(index), activeRoutine.outcomes.indices.contains(index) else {
            return .ignored(.routineSessionInvalid)
        }

        activeRoutine.outcomes[index] = outcome
        updateLinkedHabit(
            for: steps[index],
            outcome: outcome,
            day: activeRoutine.day,
            at: date,
            state: &state
        )

        if let nextIndex = activeRoutine.outcomes.indices.first(where: {
            $0 > index && activeRoutine.outcomes[$0] == .pending
        }) {
            activeRoutine.currentStepIndex = nextIndex
            activeRoutine.currentStepStartedAt = date
            activeRoutine.pausedAt = nil
            state.activeRoutine = activeRoutine
        } else {
            finish(activeRoutine, at: date, state: &state)
        }

        return .applied
    }

    private static func pauseRoutine(
        at date: Date,
        state: inout AppState
    ) -> ReductionResult {
        guard var activeRoutine = state.activeRoutine else {
            return .ignored(.noActiveRoutine)
        }
        guard activeRoutine.pausedAt == nil else {
            return .ignored(.routineAlreadyPaused)
        }
        guard date >= activeRoutine.currentStepStartedAt else {
            return .ignored(.invalidTimestamp)
        }

        activeRoutine.pausedAt = date
        state.activeRoutine = activeRoutine
        return .applied
    }

    private static func resumeRoutine(
        at date: Date,
        state: inout AppState
    ) -> ReductionResult {
        guard var activeRoutine = state.activeRoutine else {
            return .ignored(.noActiveRoutine)
        }
        guard let pausedAt = activeRoutine.pausedAt else {
            return .ignored(.routineNotPaused)
        }
        guard date >= pausedAt else {
            return .ignored(.invalidTimestamp)
        }

        let pausedDuration = date.timeIntervalSince(pausedAt)
        activeRoutine.currentStepStartedAt = activeRoutine.currentStepStartedAt.addingTimeInterval(pausedDuration)
        activeRoutine.pausedAt = nil
        state.activeRoutine = activeRoutine
        return .applied
    }

    private static func completeRoutine(
        at date: Date,
        state: inout AppState
    ) -> ReductionResult {
        guard var activeRoutine = state.activeRoutine else {
            return .ignored(.noActiveRoutine)
        }
        guard let routine = state.routine(id: activeRoutine.routineID) else {
            return .ignored(.routineNotFound)
        }
        let steps = activeRoutine.executionSteps(in: routine).map(\.step)
        guard steps.count == activeRoutine.outcomes.count else {
            return .ignored(.routineSessionInvalid)
        }
        guard activeRoutine.pausedAt == nil else {
            return .ignored(.routinePaused)
        }
        guard date >= activeRoutine.currentStepStartedAt else {
            return .ignored(.invalidTimestamp)
        }

        for index in activeRoutine.outcomes.indices where activeRoutine.outcomes[index] == .pending {
            activeRoutine.outcomes[index] = .completed
            updateLinkedHabit(
                for: steps[index],
                outcome: .completed,
                day: activeRoutine.day,
                at: date,
                state: &state
            )
        }

        finish(activeRoutine, at: date, state: &state)
        return .applied
    }

    private static func recoverHabit(
        _ habitID: Habit.ID,
        on day: LocalDay,
        choice: RecoveryChoice,
        at date: Date,
        state: inout AppState
    ) -> ReductionResult {
        guard let habit = state.habit(id: habitID) else {
            return .ignored(.habitNotFound)
        }
        guard !habit.isArchived else {
            return .ignored(.habitArchived)
        }
        guard state.status(for: habitID, on: day) != .completed else {
            return .ignored(.habitAlreadyCompleted)
        }

        let status: DailyHabitStatus
        switch choice {
        case .minimum:
            status = .minimum
        case .skip:
            status = .skipped
        case .rest:
            status = .rest
        }

        state.setStatus(status, for: habitID, on: day, at: date)
        return .applied
    }

    private static func updateLinkedHabit(
        for step: RoutineStep,
        outcome: RoutineStepOutcome,
        day: LocalDay,
        at date: Date,
        state: inout AppState
    ) {
        guard
            let habitID = step.habitID,
            let habit = state.habit(id: habitID),
            !habit.isArchived
        else {
            return
        }

        switch outcome {
        case .completed:
            state.setStatus(.completed, for: habitID, on: day, at: date)
        case .skipped:
            if state.status(for: habitID, on: day) == .pending {
                state.setStatus(.skipped, for: habitID, on: day, at: date)
            }
        case .pending:
            break
        }
    }

    private static func finish(
        _ activeRoutine: ActiveRoutine,
        at date: Date,
        state: inout AppState
    ) {
        let result: RoutineRunResult
        let completedCount = activeRoutine.outcomes.lazy.filter { $0 == .completed }.count

        if completedCount == activeRoutine.outcomes.count {
            result = .completed
        } else if completedCount == 0 {
            result = .skipped
        } else {
            result = .partial
        }

        state.routineHistory.append(
            RoutineRun(
                routineID: activeRoutine.routineID,
                day: activeRoutine.day,
                startedAt: activeRoutine.startedAt,
                endedAt: date,
                outcomes: activeRoutine.outcomes,
                result: result
            )
        )
        state.activeRoutine = nil
    }
}
