import Foundation
import Observation
import RoutineCore
import UIKit

@MainActor
@Observable
final class AppModel {
    private static let storageKey = "daymark.app-state.v1"
    private static let welcomeKey = "daymark.has-entered-app.v1"
    private static let draftKey = "bloomward.first-run-draft.v1"

    var firstRun = FirstRunDraft() {
        didSet {
            if let data = try? JSONEncoder().encode(firstRun) { storage?.set(data, forKey: Self.draftKey) }
        }
    }
    private(set) var hasOfferedBackup = false
    var reminderNotice: String?
    var firstHabitReminderMinute: Int? {
        didSet {
            if let firstHabitReminderMinute { storage?.set(firstHabitReminderMinute, forKey: "bloomward.first-habit-reminder-minute") }
            else { storage?.removeObject(forKey: "bloomward.first-habit-reminder-minute") }
            refreshReminders()
        }
    }

    var state: AppState
    var selectedPlanDate = Date()
    private(set) var lastSavedHabitID: Habit.ID?
    var cloudSync: CloudSyncModel?
    private(set) var localDataNeedsRecovery = false
    private(set) var hasEnteredApp = false
    var isRunnerPresented = false
    var routineResumeAt: Date?
    private var dayRevision = 0

    private let calendar: Calendar
    private let now: () -> Date
    private let storage: UserDefaults?

    init(
        state: AppState? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        storage: UserDefaults? = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.calendar = calendar
        self.storage = storage
        self.now = now
        self.routineResumeAt = storage?.object(forKey: "daymark.routine-resume-at") as? Date
        self.hasOfferedBackup = storage?.bool(forKey: "bloomward.offered-backup") ?? false
        self.firstHabitReminderMinute = storage?.object(forKey: "bloomward.first-habit-reminder-minute") as? Int
        if let data = storage?.data(forKey: Self.draftKey),
           let draft = try? JSONDecoder().decode(FirstRunDraft.self, from: data) { self.firstRun = draft }

        if let state {
            self.state = state
        } else if let data = storage?.data(forKey: Self.storageKey) {
            if let decoded = try? JSONDecoder().decode(AppState.self, from: data) {
                self.state = decoded
            } else {
                // Never interpret a damaged local cache as an intentional cloud deletion.
                self.state = AppState()
                self.localDataNeedsRecovery = true
                storage?.set(data, forKey: "bloomward.recovery.unreadable-state")
            }
        } else {
            // First launch contains only what the user chooses to create.
            self.state = AppState()
        }

        if Self.discardInvalidActiveRoutine(from: &self.state) {
            persist()
        }
        if self.state.activeRoutine == nil { clearRoutineSchedule() }
        selectedPlanDate = now()
        let previous = self.state
        self.state.migratePlanner(on: LocalDay(date: now(), calendar: calendar))
        if previous != self.state {
            // Keep an intact, local pre-upgrade recovery copy for this account scope.
            if storage?.data(forKey: "bloomward.before-planner.v1") == nil,
               let data = try? JSONEncoder().encode(previous) {
                storage?.set(data, forKey: "bloomward.before-planner.v1")
            }
            persist()
        }
        hasEnteredApp = !WelcomeFlow.shouldShow(
            hasEnteredApp: storage?.bool(forKey: Self.welcomeKey) ?? false,
            state: self.state
        )
    }

    func finishWelcome() {
        hasEnteredApp = true
        storage?.set(true, forKey: Self.welcomeKey)
    }

    @discardableResult
    func addFirstPlan() -> Bool {
        guard let plan = firstRun.plan(on: today), !localDataNeedsRecovery else { return false }
        // Stable draft IDs make double taps and interrupted retries idempotent.
        state = LocalAccountImport.merging(guest: plan, into: state)
        persist()
        finishWelcome()
        return true
    }

    func offerBackupOnce() {
        hasOfferedBackup = true
        storage?.set(true, forKey: "bloomward.offered-backup")
    }

    func importLocalHabits(_ local: AppState) {
        guard !localDataNeedsRecovery else { return }
        state = LocalAccountImport.merging(guest: local, into: state)
        persist()
    }

    /// Reminders are an opt-in, device-local setting, never copied between accounts.
    func refreshReminders() {
        guard storage != nil else { return }
        let habit = state.habits.first { $0.id == firstRun.habitIDs.first && !$0.isArchived && $0.settings?.isPaused != true }
        HabitReminders.shared.update(habit: habit, minute: firstHabitReminderMinute)
    }

    var today: LocalDay {
        LocalDay(date: currentDayDate, calendar: calendar)
    }

    var currentDayDate: Date {
        _ = dayRevision
        return Self.shiftedDate(
            for: now(),
            calendar: calendar,
            dayStartHour: Self.dayStartHour(in: storage)
        )
    }

    var activeHabits: [Habit] {
        state.habits.filter { !$0.isArchived }
    }

    var todayHabits: [Habit] {
        libraryHabits(.today)
    }

    var todayHabitSections: TodayHabitSections {
        let parts = calendar.dateComponents([.hour, .minute], from: now())
        return TodayHabitSections(habits: todayHabits, day: today, state: state,
                                  minute: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }

    func libraryHabits(_ filter: HabitLibraryFilter) -> [Habit] {
        state.libraryHabits(filter, on: today, calendar: calendar)
    }

    var activeRoutines: [Routine] {
        state.routines.filter { !$0.isArchived }
    }

    var todayRoutines: [Routine] {
        activeRoutines.filter { !($0.executionSteps(on: today)).isEmpty }
    }

    var runningPlan: [RoutineExecutionStep] {
        guard let run = state.activeRoutine, let routine = activeRoutine else { return [] }
        return run.executionSteps(in: routine)
    }

    var runningSteps: [RoutineStep] { runningPlan.map(\.step) }

    var currentStepContext: String? {
        guard let run = state.activeRoutine, runningPlan.indices.contains(run.currentStepIndex) else { return nil }
        let path = runningPlan[run.currentStepIndex].path
        return path.isEmpty ? nil : path.joined(separator: " › ")
    }

    var completedTodayCount: Int {
        todayHabits.reduce(into: 0) { count, habit in
            switch state.status(for: habit.id, on: today) {
            case .completed, .minimum:
                count += 1
            case .pending, .skipped, .rest:
                break
            }
        }
    }

    var completionRatio: Double {
        guard !todayHabits.isEmpty else { return 0 }
        return Double(completedTodayCount) / Double(todayHabits.count)
    }

    var activeRoutine: Routine? {
        guard let run = state.activeRoutine else { return nil }
        return state.routine(id: run.routineID)
    }

    var currentStep: RoutineStep? {
        guard
            let run = state.activeRoutine,
            runningSteps.indices.contains(run.currentStepIndex)
        else {
            return nil
        }
        return runningSteps[run.currentStepIndex]
    }

    var currentStepNumber: Int {
        (state.activeRoutine?.currentStepIndex ?? 0) + 1
    }

    var currentStepDeadline: Date? {
        guard
            let active = state.activeRoutine,
            let duration = currentStep?.estimatedDurationSeconds
        else {
            return nil
        }
        return active.currentStepStartedAt.addingTimeInterval(TimeInterval(duration))
    }

    var activeRoutineProgress: Double {
        guard
            let run = state.activeRoutine,
            !run.outcomes.isEmpty
        else {
            return 0
        }
        let resolved = run.outcomes.filter { $0 != .pending }.count
        return Double(resolved) / Double(run.outcomes.count)
    }

    var weekMetrics: [DayMetric] {
        (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: currentDayDate) else {
                return nil
            }
            let day = LocalDay(date: date, calendar: calendar)
            let dailyState = state.dailyState(for: day)
            let completed = activeHabits.filter {
                [.completed, .minimum].contains(dailyState.status(for: $0.id))
            }.count
            let adjusted = activeHabits.filter {
                [.minimum, .skipped, .rest].contains(dailyState.status(for: $0.id))
            }.count
            let ratio = activeHabits.isEmpty ? 0 : Double(completed) / Double(activeHabits.count)

            return DayMetric(
                day: day,
                label: date.formatted(.dateTime.weekday(.narrow)),
                accessibilityLabel: date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()),
                completion: ratio,
                completedCount: completed,
                adjustmentCount: adjusted,
                hasActivity: !dailyState.entries.isEmpty,
                isToday: offset == 0
            )
        }
    }

    var weeklyConsistency: Double {
        let activeDays = weekMetrics.filter(\.hasActivity)
        guard !activeDays.isEmpty else { return 0 }
        return activeDays.map(\.completion).reduce(0, +) / Double(activeDays.count)
    }

    var weeklyAdjustmentCount: Int {
        weekMetrics.map(\.adjustmentCount).reduce(0, +)
    }

    func insights(for period: InsightPeriod, weekStartsOn: Int = 2) -> InsightsSnapshot {
        _ = dayRevision
        return InsightsAnalyzer.snapshot(state: state, now: now(), calendar: calendar,
                                         dayStartHour: Self.dayStartHour(in: storage), weekStartsOn: weekStartsOn, period: period)
    }

    var routineRunsThisWeek: [RoutineRun] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: currentDayDate) else {
            return []
        }
        let dayStartHour = Self.dayStartHour(in: storage)
        return state.routineHistory.filter {
            let shiftedEnd = Self.shiftedDate(
                for: $0.endedAt,
                calendar: calendar,
                dayStartHour: dayStartHour
            )
            return interval.contains(shiftedEnd)
        }
    }

    func refreshDay() {
        dayRevision &+= 1
    }

    func status(for habit: Habit) -> DailyHabitStatus {
        state.status(for: habit.id, on: today)
    }

    func toggle(_ habit: Habit) {
        send(.toggleHabit(habitID: habit.id, day: today, at: now()))
    }

    func begin(_ routine: Routine) {
        let result = send(.startRoutine(routineID: routine.id, day: today, at: now()))
        if result == .applied {
            isRunnerPresented = true
        }
    }

    func resumeRoutine() {
        guard state.activeRoutine != nil else { return }
        clearRoutineSchedule()
        send(.resumeRoutine(at: now()), feedback: false)
        isRunnerPresented = true
    }

    func deferRoutine() {
        guard state.activeRoutine != nil else {
            isRunnerPresented = false
            return
        }
        send(.pauseRoutine(at: now()), feedback: false)
        isRunnerPresented = false
    }

    /// Saves an in-app return time. This intentionally does not promise a system notification.
    func rescheduleRoutine(to date: Date) {
        guard state.activeRoutine != nil, date > now() else { return }
        routineResumeAt = date
        storage?.set(date, forKey: "daymark.routine-resume-at")
        deferRoutine()
    }

    @discardableResult
    func createRoutine(title: String, habitIDs: [Habit.ID]) -> Bool {
        var seen = Set<Habit.ID>()
        let steps = habitIDs.filter { seen.insert($0).inserted }.map {
            RoutineDraftStep(source: .existing($0))
        }
        do {
            try createRoutine(RoutineDraft(title: title, steps: steps))
            return true
        } catch { return false }
    }

    func createRoutine(_ draft: RoutineDraft, updating: Bool = false) throws {
        guard !localDataNeedsRecovery else { throw RoutineDraftError.invalidStructure }
        state = try draft.applying(to: state, on: today, updating: updating)
        persist()
        provideSuccessFeedback()
    }

    private func clearRoutineSchedule() {
        routineResumeAt = nil
        storage?.removeObject(forKey: "daymark.routine-resume-at")
    }

    func completeCurrentStep() {
        send(.advanceRoutine(at: now()))
        dismissRunnerIfFinished()
    }

    func skipCurrentStep() {
        send(.skipRoutineStep(at: now()))
        dismissRunnerIfFinished()
    }

    func completeRoutine() {
        send(.completeRoutine(at: now()))
        dismissRunnerIfFinished()
    }

    func recover(_ habit: Habit, with choice: RecoveryChoice) {
        if choice == .rest && habit.settings?.allowsRest == false { return }
        send(.recoverHabit(habitID: habit.id, day: today, choice: choice, at: now()))
    }

    @discardableResult
    func saveHabit(id: Habit.ID? = nil, title: String, symbol: String, settings: HabitSettings) -> Bool {
        guard !localDataNeedsRecovery else { return false }
        do {
            lastSavedHabitID = try state.saveHabit(id: id, title: title, symbol: symbol, settings: settings, on: today)
        } catch { return false }
        persist()
        provideSuccessFeedback()
        return true
    }

    @discardableResult
    private func send(_ action: AppAction, feedback: Bool = true) -> ReductionResult {
        if Self.discardInvalidActiveRoutine(from: &state) {
            persist()
        }

        let result = AppReducer.reduce(state: &state, action: action)
        if result == .applied {
            persist()
            if feedback {
                provideSuccessFeedback()
            }
        }
        return result
    }

    private func dismissRunnerIfFinished() {
        if state.activeRoutine == nil {
            clearRoutineSchedule()
            isRunnerPresented = false
        }
    }

    private func persist() {
        guard
            let storage,
            let data = try? JSONEncoder().encode(state)
        else {
            return
        }
        storage.set(data, forKey: Self.storageKey)
        cloudSync?.localDidChange()
        refreshReminders()
    }

    func applyCloudState(_ incoming: AppState) {
        var restored = incoming
        // Preserve the user's on-device presentation order while merging new records.
        let habitOrder = Dictionary(uniqueKeysWithValues: state.habits.enumerated().map { ($0.element.id, $0.offset) })
        let routineOrder = Dictionary(uniqueKeysWithValues: state.routines.enumerated().map { ($0.element.id, $0.offset) })
        restored.habits.sort { (habitOrder[$0.id] ?? Int.max) < (habitOrder[$1.id] ?? Int.max) }
        restored.routines.sort { (routineOrder[$0.id] ?? Int.max) < (routineOrder[$1.id] ?? Int.max) }
        // A running timer is device-local; don't start or stop it on another iPhone.
        restored.activeRoutine = state.activeRoutine
        restored.migratePlanner(on: plannerToday)
        Self.discardInvalidActiveRoutine(from: &restored)
        guard restored != state else { return }
        state = restored
        refreshReminders()
        if let storage, let data = try? JSONEncoder().encode(state) { storage.set(data, forKey: Self.storageKey) }
        if state.activeRoutine == nil { clearRoutineSchedule(); isRunnerPresented = false }
    }

    private func provideSuccessFeedback() {
        guard storage != nil else { return }
        let hapticsEnabled = storage?.object(forKey: "daymark.haptics") as? Bool ?? true
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private static func dayStartHour(in storage: UserDefaults?) -> Int {
        guard storage?.object(forKey: "daymark.day-start-hour") != nil else {
            return 5
        }
        return storage?.integer(forKey: "daymark.day-start-hour") ?? 5
    }

    private static func shiftedDate(
        for date: Date,
        calendar: Calendar,
        dayStartHour: Int
    ) -> Date {
        calendar.date(byAdding: .hour, value: -dayStartHour, to: date) ?? date
    }

    @discardableResult
    private static func discardInvalidActiveRoutine(from state: inout AppState) -> Bool {
        guard let active = state.activeRoutine else { return false }
        guard
            let routine = state.routine(id: active.routineID),
            !routine.isArchived,
            active.executionSteps(in: routine).count == active.outcomes.count,
            active.executionSteps(in: routine).indices.contains(active.currentStepIndex),
            active.outcomes.indices.contains(active.currentStepIndex)
        else {
            state.activeRoutine = nil
            return true
        }
        return false
    }
}

struct DayMetric: Identifiable {
    let day: LocalDay
    let label: String
    let accessibilityLabel: String
    let completion: Double
    let completedCount: Int
    let adjustmentCount: Int
    let hasActivity: Bool
    let isToday: Bool

    var id: LocalDay { day }
}

extension AppModel {
    var plannerToday: LocalDay { LocalDay(date: now(), calendar: calendar) }
    var selectedPlanDay: LocalDay { LocalDay(date: selectedPlanDate, calendar: calendar) }
    var selectedPlan: [PlanOccurrence] { state.plan(on: selectedPlanDay) }

    func prepareSelectedDay() {
        guard !localDataNeedsRecovery else { return }
        let before = state
        state.migratePlanner(on: plannerToday)
        // Future days remain previews until edited, keeping future template changes flexible.
        if selectedPlanDay <= plannerToday { state.capturePlan(on: selectedPlanDay) }
        if state != before { persist() }
    }

    func moveSelectedDate(_ offset: Int) {
        selectedPlanDate = calendar.date(byAdding: .day, value: offset, to: selectedPlanDate) ?? selectedPlanDate
        prepareSelectedDay()
    }

    func saveTask(_ task: PlanTask) throws {
        guard !localDataNeedsRecovery else { throw PlannerError.missingTask }
        try state.savePlanTask(task)
        state.capturePlan(on: task.startsOn)
        persist()
    }

    func editRepeatingTask(_ task: PlanTask) throws {
        guard !localDataNeedsRecovery,
              let index = state.planTasks.firstIndex(where: { $0.id == task.id }), task.isValid else { throw PlannerError.invalidTask }
        let original = state.planTasks[index]
        let effective = max(plannerToday, selectedPlanDay)
        var replacement = task
        replacement.id = UUID(); replacement.startsOn = effective; replacement.endsOn = nil
        var candidate = state
        if effective > original.startsOn { candidate.planTasks[index].endsOn = effective.adding(days: -1) }
        else { candidate.planTasks[index].isArchived = true }
        try candidate.savePlanTask(replacement)
        // A template change is explicit. Leave the already saved day untouched,
        // beginning the replacement on its next eligible date instead of duplicating today.
        if candidate.planOccurrences.contains(where: { $0.taskID == original.id && $0.day == effective && !$0.isRemoved }) {
            replacement.startsOn = effective.adding(days: 1)
            try candidate.savePlanTask(replacement)
        }
        state = candidate
        persist()
    }

    func updateOccurrence(_ occurrence: PlanOccurrence) throws {
        guard !localDataNeedsRecovery else { throw PlannerError.missingTask }
        try state.saveOccurrence(occurrence)
        persist()
    }

    func moveTask(_ occurrence: PlanOccurrence, to date: Date) throws {
        guard !localDataNeedsRecovery else { throw PlannerError.missingTask }
        try state.moveOccurrence(occurrence, to: LocalDay(date: date, calendar: calendar))
        persist()
    }

    func saveNote(_ note: DayNote, expected: DayNote?) throws {
        guard !localDataNeedsRecovery else { throw PlannerError.noteChanged }
        try state.saveNote(note, expected: expected)
        persist()
    }

    func addRoutineToDay(_ routine: Routine, weekdays: Set<Int>? = nil) throws {
        let steps = routine.executionSteps(on: selectedPlanDay).map {
            PlanStep(id: $0.step.id, title: ($0.path + [$0.step.title]).joined(separator: " / "), notes: $0.step.notes)
        }
        guard !steps.isEmpty else { throw PlannerError.invalidTask }
        try saveTask(PlanTask(title: routine.title, startsOn: selectedPlanDay,
                             minute: routine.schedule?.startMinute, weekdays: weekdays, steps: steps, routineID: routine.id))
    }

    func archiveRoutine(_ routine: Routine) {
        guard !localDataNeedsRecovery,
              let index = state.routines.firstIndex(where: { $0.id == routine.id }) else { return }
        state.routines[index].isArchived = true
        persist()
    }
    func restorePlannerRoutine(_ routine: Routine) throws {
        guard !localDataNeedsRecovery,
              let index = state.routines.firstIndex(where: { $0.id == routine.id }) else { throw PlannerError.missingTask }
        state.routines[index].isArchived = false
        persist()
    }
}

extension AppModel {
    static var preview: AppModel {
        let date = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = LocalDay(
            date: shiftedDate(
                for: date,
                calendar: calendar,
                dayStartHour: 5
            ),
            calendar: calendar
        )
        return AppModel(
            state: SampleData.makeState(day: day),
            calendar: calendar,
            storage: nil,
            now: { date }
        )
    }
}

private enum SampleData {
    static let waterID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    static let readID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    static let workoutID = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
    static let planID = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
    static let morningID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    static let deskID = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
    static let eveningID = UUID(uuidString: "00000000-0000-0000-0000-000000000203")!

    static func makeState(day: LocalDay) -> AppState {
        let habits = [
            Habit(id: waterID, title: "Drink water", symbolName: "drop.fill", minimumTitle: "Drink one glass"),
            Habit(id: readID, title: "Read", symbolName: "book.closed.fill", minimumTitle: "Read one page"),
            Habit(id: workoutID, title: "Move your body", symbolName: "dumbbell.fill", minimumTitle: "Move for five minutes"),
            Habit(id: planID, title: "Plan tomorrow", symbolName: "calendar.badge.checkmark", minimumTitle: "Write one priority")
        ]

        let morning = Routine(
            id: morningID,
            title: "Morning Flow",
            symbolName: "sun.max.fill",
            steps: [
                RoutineStep(title: "Drink water", habitID: waterID, estimatedDurationSeconds: 60),
                RoutineStep(title: "Meditate", estimatedDurationSeconds: 240),
                RoutineStep(title: "Stretch", estimatedDurationSeconds: 180),
                RoutineStep(title: "Read", habitID: readID, estimatedDurationSeconds: 300)
            ]
        )

        let deskReset = Routine(
            id: deskID,
            title: "Desk Reset",
            symbolName: "laptopcomputer",
            steps: [
                RoutineStep(title: "Clear the desk", estimatedDurationSeconds: 120),
                RoutineStep(title: "Choose the next task", estimatedDurationSeconds: 60),
                RoutineStep(title: "Take a breath", estimatedDurationSeconds: 60)
            ]
        )

        let evening = Routine(
            id: eveningID,
            title: "Evening Wind Down",
            symbolName: "moon.stars.fill",
            steps: [
                RoutineStep(title: "Plan tomorrow", habitID: planID, estimatedDurationSeconds: 180),
                RoutineStep(title: "Put the phone away", estimatedDurationSeconds: 60),
                RoutineStep(title: "Read", habitID: readID, estimatedDurationSeconds: 600)
            ]
        )

        let completedAt = Date(timeIntervalSince1970: 1_800_000_000 - 3_600)
        let entries = [
            waterID: DailyHabitEntry(habitID: waterID, status: .completed, updatedAt: completedAt)
        ]

        return AppState(
            habits: habits,
            routines: [morning, deskReset, evening],
            days: [day: DailyState(day: day, entries: entries)]
        )
    }
}
