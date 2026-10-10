import Foundation
import XCTest
@testable import RoutineCore

final class InsightsTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }
    private func record(_ state: inout AppState, habit: Habit, day: Int, status: DailyHabitStatus, hour: Int = 9) {
        state.setStatus(status, for: habit.id, on: LocalDay(date: date(day), calendar: calendar), at: date(day, hour: hour))
    }
    private func snapshot(_ state: AppState, day: Int, hour: Int = 12, period: InsightPeriod = .thisWeek) -> InsightsSnapshot {
        InsightsAnalyzer.snapshot(state: state, now: date(day, hour: hour), calendar: calendar, period: period)
    }

    func testEmptyHistoryDoesNotInventScores() {
        let data = snapshot(AppState(habits: [Habit(title: "Read")]), day: 16)
        XCTAssertEqual(data.days.count, 7)
        XCTAssertEqual(calendar.component(.weekday, from: data.days[0].date), 2)
        XCTAssertTrue(data.days.allSatisfy { $0.completion == nil })
        XCTAssertNil(data.consistency)
        XCTAssertNil(data.dailyAverage)
        XCTAssertNil(data.recoveryScore)
        XCTAssertNil(data.previousWeekDifference)
        XCTAssertNil(data.timePattern)
        XCTAssertEqual(data.currentStreak, 0)
    }

    func testFreshStateHasNoDemoContentOrProgress() throws {
        let fresh = AppState()
        XCTAssertTrue(fresh.habits.isEmpty)
        XCTAssertTrue(fresh.routines.isEmpty)
        XCTAssertTrue(fresh.days.isEmpty)
        XCTAssertTrue(fresh.routineHistory.isEmpty)
        XCTAssertNil(fresh.activeRoutine)
        let restored = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(fresh))
        XCTAssertEqual(restored, fresh)
        let insights = snapshot(restored, day: 20)
        XCTAssertNil(insights.consistency)
        XCTAssertNil(insights.recoveryScore)
        XCTAssertEqual(insights.currentStreak, 0)
        XCTAssertEqual(insights.longestStreak, 0)
        XCTAssertTrue(insights.days.allSatisfy { $0.completion == nil })
    }

    func testWeekStartPreferenceChangesCalendarRange() {
        let monday = InsightsAnalyzer.snapshot(state: AppState(), now: date(20), calendar: calendar, weekStartsOn: 2, period: .thisWeek)
        let sunday = InsightsAnalyzer.snapshot(state: AppState(), now: date(20), calendar: calendar, weekStartsOn: 1, period: .thisWeek)
        XCTAssertEqual(monday.days.first?.day, LocalDay(year: 2026, month: 9, day: 14))
        XCTAssertEqual(sunday.days.first?.day, LocalDay(year: 2026, month: 9, day: 20))
        XCTAssertEqual(sunday.days.last?.day, LocalDay(year: 2026, month: 9, day: 26))
    }

    func testNewAccountExcludesUntrackedAndFutureDays() {
        let one = Habit(title: "Read"), two = Habit(title: "Water")
        var state = AppState(habits: [one, two])
        record(&state, habit: one, day: 16, status: .completed)
        let data = snapshot(state, day: 16)
        XCTAssertEqual(data.days.compactMap(\.completion), [0.5])
        XCTAssertEqual(data.consistency, 0.5)
        XCTAssertEqual(data.dailyAverage, 0.5)
        XCTAssertEqual(data.currentStreak, 1)
    }

    func testDailyAverageIncludesGapsButConsistencyUsesLoggedDays() {
        let one = Habit(title: "Read"), two = Habit(title: "Water")
        var state = AppState(habits: [one, two])
        record(&state, habit: one, day: 14, status: .completed)
        record(&state, habit: two, day: 14, status: .completed)
        record(&state, habit: one, day: 16, status: .minimum)
        let data = snapshot(state, day: 17)
        XCTAssertEqual(data.consistency, 0.75)
        XCTAssertEqual(data.dailyAverage, 0.375)
        XCTAssertEqual(data.adjustmentCount, 1)
        XCTAssertEqual(data.currentStreak, 1, "An unfinished today preserves yesterday's streak")
        XCTAssertEqual(data.longestStreak, 1)
    }

    func testRecoveryRequiresThreeClosedReturnOpportunities() throws {
        let habit = Habit(title: "Read")
        var state = AppState(habits: [habit])
        for day in [8, 10, 12] { record(&state, habit: habit, day: day, status: .rest) }
        for day in [9, 11] { record(&state, habit: habit, day: day, status: .completed) }
        XCTAssertNil(snapshot(state, day: 13).recoveryScore, "The current day remains open")
        let data = snapshot(state, day: 14)
        XCTAssertEqual(data.recoveryOpportunities, 3)
        XCTAssertEqual(data.recoveryReturns, 2)
        XCTAssertEqual(try XCTUnwrap(data.recoveryScore), 20.0 / 3.0, accuracy: 0.0001)
    }

    func testLastWeekAndMatchedWeekComparison() throws {
        let one = Habit(title: "Read"), two = Habit(title: "Water")
        var state = AppState(habits: [one, two])
        for day in 7...13 { record(&state, habit: one, day: day, status: .completed) }
        for day in 14...16 {
            record(&state, habit: one, day: day, status: .completed)
            record(&state, habit: two, day: day, status: .completed)
        }
        let current = snapshot(state, day: 16)
        XCTAssertEqual(try XCTUnwrap(current.previousWeekDifference), 0.5, accuracy: 0.0001)
        let previous = snapshot(state, day: 16, period: .lastWeek)
        XCTAssertEqual(previous.days.first?.day, LocalDay(year: 2026, month: 9, day: 7))
        XCTAssertEqual(previous.dailyAverage, 0.5)
        XCTAssertEqual(current.currentStreak, 10)
        XCTAssertEqual(current.longestStreak, 10)
    }

    func testDayBoundaryAndArchivedHistoryStreaks() {
        let habit = Habit(title: "Read")
        var state = AppState(habits: [habit])
        record(&state, habit: habit, day: 14, status: .completed)
        let beforeDayStart = snapshot(state, day: 15, hour: 2)
        XCTAssertEqual(beforeDayStart.days.compactMap(\.completion), [1])
        XCTAssertEqual(beforeDayStart.currentStreak, 1)
        state.habits[0].isArchived = true
        let archived = snapshot(state, day: 15)
        XCTAssertNil(archived.dailyAverage)
        XCTAssertEqual(archived.longestStreak, 1, "Archiving a habit must not erase historical achievements")
    }

    func testTimePatternsRequireEnoughCorrectlyDatedEntries() {
        let habits = [Habit(title: "Read"), Habit(title: "Water"), Habit(title: "Walk")]
        var state = AppState(habits: habits)
        for day in 14...16 {
            for habit in habits { record(&state, habit: habit, day: day, status: .completed, hour: 9) }
        }
        let data = snapshot(state, day: 16)
        XCTAssertEqual(data.timePattern?.count, 9)
        XCTAssertEqual(data.timePattern?.isMorning, true)
        for habit in habits { state.setStatus(.completed, for: habit.id, on: LocalDay(year: 2026, month: 9, day: 16), at: date(1)) }
        XCTAssertNil(snapshot(state, day: 16).timePattern)
    }

    func testLegacyHabitsDecodeWithoutNewSettings() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","title":"Read","symbolName":"book","isArchived":false}
        """
        let habit = try JSONDecoder().decode(Habit.self, from: Data(json.utf8))
        XCTAssertNil(habit.settings)
        XCTAssertTrue(habit.isScheduled(on: LocalDay(year: 2026, month: 9, day: 20), calendar: calendar))
    }

    func testHabitSettingsValidationAndRoundTrip() throws {
        var settings = HabitSettings()
        settings.category = .mind
        settings.notes = "One quiet page"
        settings.createdOn = LocalDay(year: 2026, month: 9, day: 21)
        let habit = Habit(title: "Read", settings: settings)
        XCTAssertEqual(try JSONDecoder().decode(Habit.self, from: JSONEncoder().encode(habit)), habit)
        XCTAssertTrue(settings.isValid)
        XCTAssertFalse(habit.isScheduled(on: LocalDay(year: 2026, month: 9, day: 18), calendar: calendar))
        XCTAssertTrue(habit.isScheduled(on: LocalDay(year: 2026, month: 9, day: 21), calendar: calendar))
        XCTAssertFalse(habit.isScheduled(on: LocalDay(year: 2026, month: 9, day: 22), calendar: calendar))
        settings.weekdays = []
        XCTAssertFalse(settings.isValid)
        settings.weekdays = [2]
        settings.endMinute = settings.startMinute
        XCTAssertFalse(settings.isValid)
    }

    func testScheduledHabitsDoNotLowerOffDayCompletion() {
        let daily = Habit(title: "Water")
        let scheduled = Habit(title: "Workout", settings: HabitSettings())
        var state = AppState(habits: [daily, scheduled])
        record(&state, habit: daily, day: 20, status: .completed)
        XCTAssertEqual(snapshot(state, day: 20).dailyAverage, 1)
    }
}
