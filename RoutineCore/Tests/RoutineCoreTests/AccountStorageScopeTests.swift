import XCTest
@testable import RoutineCore

final class AccountStorageScopeTests: XCTestCase {
    func testGuestKeepsOriginalStorage() {
        XCTAssertNil(AccountStorageScope.guest.defaultsSuiteName)
    }

    func testUsersNeverShareTheSameStorageScope() {
        XCTAssertNotEqual(AccountStorageScope.account("user_a").defaultsSuiteName,
                          AccountStorageScope.account("user_b").defaultsSuiteName)
        XCTAssertNotNil(AccountStorageScope.account("user_a").defaultsSuiteName)
        XCTAssertEqual(AccountStorageScope.account("user_a").defaultsSuiteName,
                       AccountStorageScope.account("user_a").defaultsSuiteName)
    }

    func testScopeDoesNotCollapseDistinctUnicodeOrDelimiterIdentifiers() {
        let ids = ["a/b", "a_b", "a+b", "a-b", "", "guest", "用户"]
        XCTAssertEqual(Set(ids.compactMap { AccountStorageScope.account($0).defaultsSuiteName }).count, ids.count)
    }

    func testAccountDefaultsRemainIsolatedAndSurviveReopening() throws {
        let unique = UUID().uuidString
        let firstName = try XCTUnwrap(AccountStorageScope.account("test-\(unique)-a").defaultsSuiteName)
        let secondName = try XCTUnwrap(AccountStorageScope.account("test-\(unique)-b").defaultsSuiteName)
        let first = try XCTUnwrap(UserDefaults(suiteName: firstName))
        let second = try XCTUnwrap(UserDefaults(suiteName: secondName))
        defer {
            // These are unique test-only suites, never user account storage.
            first.removePersistentDomain(forName: firstName)
            second.removePersistentDomain(forName: secondName)
        }
        first.set("first-account-habits", forKey: "daymark.app-state.v1")
        XCTAssertNil(second.string(forKey: "daymark.app-state.v1"))
        second.set("second-account-habits", forKey: "daymark.app-state.v1")
        let reopened = try XCTUnwrap(UserDefaults(suiteName: firstName))
        XCTAssertEqual(reopened.string(forKey: "daymark.app-state.v1"), "first-account-habits")
        XCTAssertEqual(second.string(forKey: "daymark.app-state.v1"), "second-account-habits")
    }
}
