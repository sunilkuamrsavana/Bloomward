import RoutineCore
import UserNotifications

/// This first-use reminder belongs to the active local/account scope on this iPhone.
/// Switching accounts replaces its pending requests, without touching other notifications.
@MainActor
final class HabitReminders {
    static let shared = HabitReminders()
    private let center = UNUserNotificationCenter.current()
    private let identifiers = (1...7).map { "bloomward.first-habit.\($0)" }
    private var revision = 0
    private var task: Task<Void, Never>?

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func update(habit: Habit?, minute: Int?) {
        revision += 1
        let revision = revision
        let previous = task
        previous?.cancel()
        task = Task {
            await previous?.value
            let settings = await center.notificationSettings()
            guard revision == self.revision, !Task.isCancelled else { return }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
                  let habit, let minute, (0..<1440).contains(minute) else { return }
            for weekday in (habit.settings?.weekdays ?? Set(1...7)).sorted() {
                guard revision == self.revision, !Task.isCancelled else { return }
                let content = UNMutableNotificationContent()
                content.title = "A small moment for you"
                // Don't put potentially private habit names on the lock screen.
                content.body = "Your Bloomward habit is ready when you are."
                content.sound = .default
                var date = DateComponents()
                date.weekday = weekday; date.hour = minute / 60; date.minute = minute % 60
                let request = UNNotificationRequest(identifier: "bloomward.first-habit.\(weekday)", content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))
                try? await center.add(request)
            }
        }
    }
}
