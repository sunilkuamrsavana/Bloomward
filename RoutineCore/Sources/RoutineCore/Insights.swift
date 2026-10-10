import Foundation

public enum InsightPeriod: String, CaseIterable, Identifiable, Sendable {
    case thisWeek = "This week"
    case lastWeek = "Last week"
    public var id: Self { self }
}

public struct InsightDay: Identifiable, Sendable {
    public let date: Date
    public let day: LocalDay
    public let completion: Double?
    public let completedCount: Int
    public let loggedCount: Int
    public let adjustmentCount: Int
    public var id: LocalDay { day }
}

public struct InsightTimePattern: Sendable {
    public let isMorning: Bool
    public let count: Int
    public let total: Int
}

public struct InsightsSnapshot: Sendable {
    public let days: [InsightDay]
    public let consistency: Double?
    public let dailyAverage: Double?
    /// Percentage-point difference, not a relative percentage increase.
    public let previousWeekDifference: Double?
    public let adjustmentCount: Int
    public let completionCount: Int
    public let recoveryOpportunities: Int
    public let recoveryReturns: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let timePattern: InsightTimePattern?

    /// Behavioral return rate after a minimum, skipped, or rest day. Not a health score.
    public var recoveryScore: Double? {
        guard recoveryOpportunities >= 3 else { return nil }
        return 10 * Double(recoveryReturns) / Double(recoveryOpportunities)
    }
}

public enum InsightsAnalyzer {
    public static func snapshot(state: AppState, now: Date, calendar: Calendar, dayStartHour: Int = 5, weekStartsOn: Int = 2, period: InsightPeriod) -> InsightsSnapshot {
        var calendar = calendar
        calendar.firstWeekday = (1...7).contains(weekStartsOn) ? weekStartsOn : 2
        let shifted = calendar.date(byAdding: .hour, value: -dayStartHour, to: now) ?? now
        let todayDate = calendar.startOfDay(for: shifted)
        let today = LocalDay(date: todayDate, calendar: calendar)
        let activeHabits = state.habits.filter { !$0.isArchived }
        let ids = Set(activeHabits.map(\.id))
        let allIDs = Set(state.habits.map(\.id))
        let firstDay = state.days.keys.filter { day in
            day <= today && state.days[day]?.entries.values.contains(where: { ids.contains($0.habitID) }) == true
        }.min()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: todayDate)?.start ?? todayDate
        let start = calendar.date(byAdding: .day, value: period == .lastWeek ? -7 : 0, to: weekStart) ?? weekStart

        func entries(on day: LocalDay) -> [DailyHabitEntry] {
            (state.days[day]?.entries.values.map { $0 } ?? []).filter { ids.contains($0.habitID) }
        }
        func positive(_ entry: DailyHabitEntry) -> Bool { entry.status == .completed || entry.status == .minimum }
        func adjusted(_ entry: DailyHabitEntry) -> Bool { [.minimum, .skipped, .rest].contains(entry.status) }
        func days(from start: Date) -> [InsightDay] {
            (0..<7).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                let day = LocalDay(date: date, calendar: calendar)
                let values = entries(on: day)
                let completed = values.filter(positive).count
                let isTracked = firstDay.map { day >= $0 && day <= today } ?? false
                let scheduledCount = activeHabits.filter { habit in
                    habit.isScheduled(on: day, calendar: calendar) || values.contains { $0.habitID == habit.id && $0.status != .pending }
                }.count
                let ratio: Double? = isTracked && scheduledCount > 0 ? Double(completed) / Double(scheduledCount) : nil
                return InsightDay(date: date, day: day, completion: ratio, completedCount: completed, loggedCount: values.filter { $0.status != .pending }.count, adjustmentCount: values.filter(adjusted).count)
            }
        }
        func average(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }
        let current = days(from: start)
        let previous = days(from: calendar.date(byAdding: .day, value: -7, to: start) ?? start)
        let eligible = current.filter { $0.completion != nil }
        // Compare the same elapsed weekdays when this week is still in progress.
        let comparable = zip(current, previous).filter { $0.0.completion != nil && $0.1.completion != nil }
        let difference: Double? = comparable.count >= 3
            ? average(comparable.map { ($0.0.completion ?? 0) - ($0.1.completion ?? 0) })
            : nil

        let end = min(current.last?.date ?? todayDate, todayDate)
        var opportunities = 0
        var returns = 0
        for offset in -27...(-1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: end),
                  let next = calendar.date(byAdding: .day, value: 1, to: date) else { continue }
            let day = LocalDay(date: date, calendar: calendar)
            let nextDay = LocalDay(date: next, calendar: calendar)
            // An unfinished current day is not counted as a failed return opportunity.
            guard nextDay < today, entries(on: day).contains(where: adjusted) else { continue }
            opportunities += 1
            if entries(on: nextDay).contains(where: positive) { returns += 1 }
        }

        // Never infer time-of-day patterns from legacy timestamps that do not match their recorded day.
        let timedEntries = eligible.flatMap { metric in
            entries(on: metric.day).filter { entry in
                guard positive(entry), entry.updatedAt <= now,
                      let loggedDate = calendar.date(byAdding: .hour, value: -dayStartHour, to: entry.updatedAt) else { return false }
                return LocalDay(date: loggedDate, calendar: calendar) == metric.day
            }
        }
        let timedDays = Set(timedEntries.map { entry in
            LocalDay(date: calendar.date(byAdding: .hour, value: -dayStartHour, to: entry.updatedAt) ?? entry.updatedAt, calendar: calendar)
        })
        let morningCount = timedEntries.filter { (5..<12).contains(calendar.component(.hour, from: $0.updatedAt)) }.count
        let timePattern: InsightTimePattern? = timedEntries.count >= 7 && timedDays.count >= 3
            ? InsightTimePattern(isMorning: morningCount * 2 >= timedEntries.count, count: morningCount * 2 >= timedEntries.count ? morningCount : timedEntries.count - morningCount, total: timedEntries.count)
            : nil

        let positiveDays = Set(state.days.compactMap { day, daily -> LocalDay? in
            guard day <= today, daily.entries.values.contains(where: { allIDs.contains($0.habitID) && positive($0) }) else { return nil }
            return day
        })
        let sorted = positiveDays.sorted()
        var longest = 0
        var run = 0
        var prior: LocalDay?
        for day in sorted {
            let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
            let previousDay = date.flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }.map { LocalDay(date: $0, calendar: calendar) }
            run = previousDay == prior ? run + 1 : 1
            longest = max(longest, run)
            prior = day
        }
        var cursor = todayDate
        if !positiveDays.contains(today) { cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        var streak = 0
        while positiveDays.contains(LocalDay(date: cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return InsightsSnapshot(
            days: current,
            consistency: average(eligible.filter { $0.loggedCount > 0 }.compactMap(\.completion)),
            dailyAverage: average(eligible.compactMap(\.completion)),
            previousWeekDifference: difference,
            adjustmentCount: eligible.map(\.adjustmentCount).reduce(0, +),
            completionCount: eligible.map(\.completedCount).reduce(0, +),
            recoveryOpportunities: opportunities,
            recoveryReturns: returns,
            currentStreak: streak,
            longestStreak: longest,
            timePattern: timePattern
        )
    }
}
