import Foundation
import XCTest
@testable import RoutineCore

final class PlannerTests: XCTestCase {
    private let day = LocalDay(year: 2026, month: 10, day: 10)
    func testOneOffOnlyAppearsOnItsDate() throws {
        var state = AppState(); try state.savePlanTask(PlanTask(title: "Call", startsOn: day))
        XCTAssertEqual(state.plan(on: day).count, 1)
        XCTAssertTrue(state.plan(on: day.adding(days: 1)).isEmpty)
    }
    func testRepeatStartsOnSelectedDateAndUsesWeekdays() {
        let task = PlanTask(title: "Work", startsOn: day, weekdays: [2])
        XCTAssertFalse(task.includes(day)); XCTAssertTrue(task.includes(day.adding(days: 2)))
        XCTAssertFalse(task.includes(day.adding(days: -5)))
    }
    func testRepeatCompletionDoesNotCompleteTomorrow() throws {
        var state = AppState(planTasks: [PlanTask(title: "Read", startsOn: day, weekdays: Set(1...7))])
        state.capturePlan(on: day)
        var record = state.plan(on: day)[0]; record.status = .completed
        try state.saveOccurrence(record)
        XCTAssertEqual(state.plan(on: day)[0].status, .completed)
        XCTAssertEqual(state.plan(on: day.adding(days: 1))[0].status, .pending)
    }
    func testCaptureIsIdempotentAndProtectsPastChecklist() {
        var state = AppState(planTasks: [PlanTask(title: "Gym", startsOn: day, weekdays: Set(1...7), steps: [PlanStep(title: "Squat")])])
        state.capturePlan(on: day); state.capturePlan(on: day)
        XCTAssertEqual(state.planOccurrences.count, 1)
        state.planTasks[0].title = "New gym"; state.planTasks[0].steps = [PlanStep(title: "Run")]
        XCTAssertEqual(state.plan(on: day)[0].title, "Gym")
        XCTAssertEqual(state.plan(on: day)[0].steps[0].title, "Squat")
        XCTAssertEqual(state.plan(on: day.adding(days: 1))[0].title, "New gym")
    }
    func testRemoveDoesNotRegenerateRecurringTask() throws {
        var state = AppState(planTasks: [PlanTask(title: "Read", startsOn: day, weekdays: Set(1...7))])
        var record = state.plan(on: day)[0]; record.isRemoved = true
        try state.saveOccurrence(record); state.capturePlan(on: day)
        XCTAssertTrue(state.plan(on: day).isEmpty)
        XCTAssertEqual(state.plan(on: day, includingRemoved: true).count, 1)
        record.isRemoved = false; try state.saveOccurrence(record)
        XCTAssertEqual(state.plan(on: day).count, 1)
    }
    func testMoveKeepsOriginalRecordAndDoesNotOverwriteTarget() throws {
        let task = PlanTask(title: "Read", startsOn: day, weekdays: Set(1...7))
        var state = AppState(planTasks: [task]); state.capturePlan(on: day)
        try state.moveOccurrence(state.plan(on: day)[0], to: day.adding(days: 1))
        XCTAssertEqual(state.plan(on: day)[0].status, .moved)
        XCTAssertEqual(state.plan(on: day)[0].movedTo, day.adding(days: 1))
        XCTAssertEqual(state.plan(on: day.adding(days: 1)).count, 2)
    }
    func testInvalidMoveIsAtomic() {
        let task = PlanTask(title: "Missing", startsOn: day)
        var state = AppState(); let original = state
        XCTAssertThrowsError(try state.moveOccurrence(PlanOccurrence(task: task, day: day), to: day.adding(days: 1)))
        XCTAssertEqual(state, original)
    }
    func testSameDateMoveRejected() {
        let task = PlanTask(title: "Task", startsOn: day)
        var state = AppState(planTasks: [task])
        XCTAssertThrowsError(try state.moveOccurrence(PlanOccurrence(task: task, day: day), to: day))
        XCTAssertTrue(state.planOccurrences.isEmpty)
    }
    func testMigrationKeepsIDsStatusesAndIsIdempotent() {
        let habit = Habit(title: "Workout")
        var state = AppState(habits: [habit]); state.setStatus(.minimum, for: habit.id, on: day.adding(days: -2), at: Date())
        let legacy = state.days
        state.migratePlanner(on: day)
        let first = state; state.migratePlanner(on: day)
        XCTAssertEqual(state, first); XCTAssertEqual(state.days, legacy)
        XCTAssertEqual(state.planTasks[0].id, habit.id)
        XCTAssertEqual(state.plan(on: day.adding(days: -2))[0].status, .partial)
    }
    func testLegacyLocalJSONStillDecodes() throws {
        let legacy = Data("{\"habits\":[],\"routines\":[],\"days\":[],\"routineHistory\":[]}".utf8)
        let state = try JSONDecoder().decode(AppState.self, from: legacy)
        XCTAssertTrue(state.planTasks.isEmpty); XCTAssertTrue(state.dayNotes.isEmpty)
    }
    func testLegacyCloudJSONStillDecodes() throws {
        let legacy = Data("{\"schemaVersion\":2,\"habits\":[],\"routines\":[],\"days\":[],\"routineHistory\":[],\"preferences\":{}}".utf8)
        let snapshot = try JSONDecoder().decode(SyncSnapshot.self, from: legacy)
        XCTAssertEqual(snapshot.schemaVersion, 2); XCTAssertTrue(snapshot.dayNotes.isEmpty)
    }
    func testMultipleNotesBelongToOneDate() throws {
        var state = AppState()
        try state.saveNote(DayNote(day: day, body: "First"), expected: nil)
        try state.saveNote(DayNote(day: day, body: "Second"), expected: nil)
        XCTAssertEqual(state.dayNotes.count, 2)
        XCTAssertTrue(state.dayNotes.allSatisfy { $0.day == day })
    }
    func testEmptyNoteDoesNotLeaveGhostPage() throws {
        var state = AppState(); try state.saveNote(DayNote(day: day, title: "  ", body: "\n"), expected: nil)
        XCTAssertTrue(state.dayNotes.isEmpty)
    }
    func testNoteAutosaveUsesExpectedVersion() throws {
        var state = AppState(); var note = DayNote(day: day, body: "First")
        try state.saveNote(note, expected: nil)
        let previous = note; note.body = "Edited"
        try state.saveNote(note, expected: previous)
        XCTAssertThrowsError(try state.saveNote(previous, expected: previous))
        XCTAssertEqual(state.dayNotes[0].body, "Edited")
    }
    func testNoteTrashIsRestorable() throws {
        var state = AppState(); var note = DayNote(day: day, body: "Keep")
        try state.saveNote(note, expected: nil); let saved = note
        note.isArchived = true; try state.saveNote(note, expected: saved)
        let trashed = note; note.isArchived = false; try state.saveNote(note, expected: trashed)
        XCTAssertEqual(state.dayNotes[0].body, "Keep"); XCTAssertFalse(state.dayNotes[0].isArchived)
    }
    func testValidationRejectsEmptyRepeatAndBadTimes() {
        XCTAssertFalse(PlanTask(title: "  ", startsOn: day).isValid)
        XCTAssertFalse(PlanTask(title: "Task", startsOn: day, minute: 1440).isValid)
        XCTAssertFalse(PlanTask(title: "Task", startsOn: day, weekdays: []).isValid)
        XCTAssertFalse(PlanTask(title: "Task", startsOn: day, steps: [PlanStep(title: "")]).isValid)
    }
    func testTimeOrderingKeepsUntimedTasksAfterTimedOnes() {
        let a = PlanTask(title: "Anytime", startsOn: day), b = PlanTask(title: "Early", startsOn: day, minute: 60)
        let state = AppState(planTasks: [a,b])
        XCTAssertEqual(state.plan(on: day).map(\.title), ["Early", "Anytime"])
    }
    func testPlannerWireRoundTrip() throws {
        var state = AppState(planTasks: [PlanTask(title: "Task", startsOn: day)])
        state.capturePlan(on: day); try state.saveNote(DayNote(day: day, body: "Text"), expected: nil)
        let sync = SyncSnapshot(state: state)
        let restored = try JSONDecoder().decode(SyncSnapshot.self, from: JSONEncoder().encode(sync))
        XCTAssertEqual(restored.state, state); XCTAssertEqual(sync.schemaVersion, 3)
    }
    func testDifferentNotesCombineAcrossDevices() {
        let l = AppState(dayNotes: [DayNote(day: day, body: "Left")])
        let r = AppState(dayNotes: [DayNote(day: day, body: "Right")])
        let merged = SyncMerger.merge(base: SyncSnapshot(), local: SyncSnapshot(state: l), remote: SyncSnapshot(state: r))
        XCTAssertTrue(merged.conflicts.isEmpty); XCTAssertEqual(merged.snapshot.dayNotes.count, 2)
    }
    func testConcurrentNoteEditsRequireReview() {
        let note = DayNote(day: day, body: "Original")
        let base = SyncSnapshot(state: AppState(dayNotes: [note]))
        var l = base, r = base; l.dayNotes[0].body = "Left"; r.dayNotes[0].body = "Right"
        XCTAssertFalse(SyncMerger.merge(base: base, local: l, remote: r).conflicts.isEmpty)
        XCTAssertEqual(SyncMerger.merge(base: base, local: l, remote: r, choice: .cloud).snapshot.dayNotes[0].body, "Right")
    }
    func testSavedPlannerBypassesOnboarding() {
        XCTAssertFalse(WelcomeFlow.shouldShow(hasEnteredApp: false, state: AppState(dayNotes: [DayNote(day: day, body: "Saved")])))
    }
    func testRepeatEndPreservesOldDayAndStopsFuture() {
        let task = PlanTask(title: "Read", startsOn: day, endsOn: day.adding(days: 2), weekdays: Set(1...7))
        XCTAssertTrue(task.includes(day)); XCTAssertTrue(task.includes(day.adding(days: 2)))
        XCTAssertFalse(task.includes(day.adding(days: 3)))
    }
    func testRepeatingRoutineUsesDaySpecificStepsAndKeepsSnapshots() {
        let saturday = RoutineStep(title: "Walk", schedule: RoutineSchedule(weekdays: [7]))
        let sunday = RoutineStep(title: "Rest", schedule: RoutineSchedule(weekdays: [1]))
        let routine = Routine(title: "Weekend", steps: [saturday, sunday])
        let task = PlanTask(title: "Weekend", startsOn: day, weekdays: [7,1], routineID: routine.id)
        var state = AppState(routines: [routine], planTasks: [task])
        state.capturePlan(on: day)
        XCTAssertEqual(state.plan(on: day)[0].steps.map(\.title), ["Walk"])
        XCTAssertEqual(state.plan(on: day.adding(days: 1))[0].steps.map(\.title), ["Rest"])
        state.routines[0].steps[0].title = "Long walk"
        XCTAssertEqual(state.plan(on: day)[0].steps.map(\.title), ["Walk"])
        XCTAssertEqual(state.plan(on: day.adding(days: 7))[0].steps.map(\.title), ["Long walk"])
    }
}
