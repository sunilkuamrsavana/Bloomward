import XCTest
@testable import RoutineCore

final class WelcomeFlowTests: XCTestCase {
    func testFreshInstallShowsWelcomeWithoutCreatingData() {
        let state = AppState()
        XCTAssertTrue(WelcomeFlow.shouldShow(hasEnteredApp: false, state: state))
        XCTAssertEqual(state, AppState())
    }

    func testExploringEmptyAppDoesNotShowWelcomeAgain() {
        XCTAssertFalse(WelcomeFlow.shouldShow(hasEnteredApp: true, state: AppState()))
    }

    func testExistingHabitsBypassWelcomeIncludingArchivedHabits() {
        var habit = Habit(title: "My habit")
        XCTAssertFalse(WelcomeFlow.shouldShow(hasEnteredApp: false, state: AppState(habits: [habit])))
        habit.isArchived = true
        XCTAssertFalse(WelcomeFlow.shouldShow(hasEnteredApp: false, state: AppState(habits: [habit])))
    }

    func testExistingHistoryBypassesWelcome() {
        let day = LocalDay(year: 2026, month: 9, day: 21)
        let state = AppState(days: [day: DailyState(day: day)])
        XCTAssertFalse(WelcomeFlow.shouldShow(hasEnteredApp: false, state: state))
    }
}
