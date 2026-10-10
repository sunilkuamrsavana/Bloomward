import Foundation

/// Existing users should never be interrupted by the new first-launch screen.
public enum WelcomeFlow {
    public static func shouldShow(hasEnteredApp: Bool, state: AppState) -> Bool {
        !hasEnteredApp && state.habits.isEmpty && state.routines.isEmpty
            && state.planTasks.isEmpty && state.planOccurrences.isEmpty && state.dayNotes.isEmpty
            && state.days.isEmpty && state.routineHistory.isEmpty && state.activeRoutine == nil
    }
}
