import XCTest
@testable import RoutineCore

final class CloudSyncTests: XCTestCase {
    private let day = LocalDay(year: 2026, month: 9, day: 21)
    private let water = Habit(title: "Water")
    private let read = Habit(title: "Read")

    func testEmptyNewDeviceRestoresCloudAndDoesNotEraseIt() {
        let cloud = SyncSnapshot(state: AppState(habits: [water, read]), preferences: ["daymark.profile-name": "Person"])
        let result = SyncMerger.merge(base: SyncSnapshot(), local: SyncSnapshot(), remote: cloud)
        XCTAssertEqual(result.snapshot, cloud)
        XCTAssertTrue(result.conflicts.isEmpty)
    }
    func testIndependentOfflineAdditionsCombine() {
        let result = SyncMerger.merge(base: SyncSnapshot(), local: SyncSnapshot(state: AppState(habits: [water])),
                                      remote: SyncSnapshot(state: AppState(habits: [read])))
        XCTAssertEqual(Set(result.snapshot.habits.map(\.id)), Set([water.id, read.id]))
        XCTAssertTrue(result.conflicts.isEmpty)
    }
    func testConcurrentHabitEditsRequireReview() {
        let base = SyncSnapshot(state: AppState(habits: [water]))
        var local = base, remote = base
        local.habits[0].title = "Water here"; remote.habits[0].title = "Water elsewhere"
        let conflict = SyncMerger.merge(base: base, local: local, remote: remote)
        XCTAssertEqual(conflict.conflicts.count, 1)
        XCTAssertEqual(SyncMerger.merge(base: base, local: local, remote: remote, choice: .cloud).snapshot, remote)
        XCTAssertEqual(SyncMerger.merge(base: base, local: local, remote: remote, choice: .thisDevice).snapshot, local)
    }
    func testDeletionPropagatesButDeletionVersusEditRequiresReview() {
        let base = SyncSnapshot(state: AppState(habits: [water]))
        XCTAssertTrue(SyncMerger.merge(base: base, local: base, remote: SyncSnapshot()).snapshot.habits.isEmpty)
        var edited = base; edited.habits[0].title = "Changed"
        XCTAssertFalse(SyncMerger.merge(base: base, local: edited, remote: SyncSnapshot()).conflicts.isEmpty)
    }
    func testSeparateHabitLogsOnSameDayCombine() {
        let base = AppState(habits: [water, read])
        var local = base, remote = base
        local.setStatus(.completed, for: water.id, on: day, at: Date(timeIntervalSince1970: 100))
        remote.setStatus(.rest, for: read.id, on: day, at: Date(timeIntervalSince1970: 200))
        let result = SyncMerger.merge(base: SyncSnapshot(state: base), local: SyncSnapshot(state: local), remote: SyncSnapshot(state: remote))
        XCTAssertEqual(result.snapshot.state.status(for: water.id, on: day), .completed)
        XCTAssertEqual(result.snapshot.state.status(for: read.id, on: day), .rest)
        XCTAssertTrue(result.conflicts.isEmpty)
    }
    func testDifferentOutcomesConflictButIdenticalOutcomesDoNot() {
        let base = AppState(habits: [water])
        var local = base, remote = base
        local.setStatus(.completed, for: water.id, on: day, at: Date(timeIntervalSince1970: 100))
        remote.setStatus(.rest, for: water.id, on: day, at: Date(timeIntervalSince1970: 200))
        XCTAssertFalse(SyncMerger.merge(base: SyncSnapshot(state: base), local: SyncSnapshot(state: local), remote: SyncSnapshot(state: remote)).conflicts.isEmpty)
        remote.setStatus(.completed, for: water.id, on: day, at: Date(timeIntervalSince1970: 200))
        XCTAssertTrue(SyncMerger.merge(base: SyncSnapshot(state: base), local: SyncSnapshot(state: local), remote: SyncSnapshot(state: remote)).conflicts.isEmpty)
    }
    func testLostUploadResponseIsIdempotentOnRetry() {
        let uploaded = SyncSnapshot(state: AppState(habits: [water]))
        let result = SyncMerger.merge(base: SyncSnapshot(), local: uploaded, remote: uploaded)
        XCTAssertEqual(result.snapshot, uploaded)
        XCTAssertTrue(result.conflicts.isEmpty)
    }
    func testEditsDuringNetworkRequestAreRetained() {
        let beforeRequest = SyncSnapshot(state: AppState(habits: [water]))
        let current = SyncSnapshot(state: AppState(habits: [water, read]))
        let result = SyncMerger.merge(base: beforeRequest, local: current, remote: beforeRequest)
        XCTAssertEqual(result.snapshot, current)
    }
    func testPreferencesMergeIndividually() {
        let result = SyncMerger.merge(base: SyncSnapshot(), local: SyncSnapshot(preferences: ["daymark.profile-name": "Person"]),
                                      remote: SyncSnapshot(preferences: ["daymark.week-start": "1"]))
        XCTAssertEqual(result.snapshot.preferences.count, 2)
    }
    func testWireRoundTripIncludesHistoryButNeverActiveTimer() throws {
        var state = AppState(habits: [water])
        let routine = Routine(title: "Morning", steps: [RoutineStep(title: "Water", habitID: water.id)])
        state.routines = [routine]
        state.activeRoutine = ActiveRoutine(routineID: routine.id, day: day, startedAt: Date(), outcomes: [.pending])
        state.setStatus(.completed, for: water.id, on: day, at: Date())
        state.routineHistory = [RoutineRun(routineID: routine.id, day: day, startedAt: Date(), endedAt: Date(), outcomes: [.completed], result: .completed)]
        let snapshot = SyncSnapshot(state: state)
        let decoded = try JSONDecoder().decode(SyncSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(snapshot, decoded)
        XCTAssertNil(decoded.state.activeRoutine)
        XCTAssertEqual(decoded.state.routineHistory, state.routineHistory)
        XCTAssertEqual(decoded.state.days, state.days)
    }
}
