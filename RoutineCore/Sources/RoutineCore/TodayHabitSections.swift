import Foundation

/// A habit has one place on Today. Logging it does not make the quick-log row jump around.
public struct TodayHabitSections: Sendable {
    public let quickLog: [Habit]
    public let next: [Habit]

    public init(habits: [Habit], day: LocalDay, state: AppState, minute: Int) {
        let available = habits.filter {
            $0.settings?.timeWindowEnabled != true || ($0.settings?.startMinute ?? 0) <= minute
        }
        quickLog = Array(available.prefix(4))
        let shown = Set(quickLog.map(\.id))
        next = habits.filter { !shown.contains($0.id) && state.status(for: $0.id, on: day) == .pending }
            .sorted { ($0.settings?.startMinute ?? 1440) < ($1.settings?.startMinute ?? 1440) }
    }
}
