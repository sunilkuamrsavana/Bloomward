import Foundation
import Observation
import RoutineCore

@MainActor
@Observable
final class CloudSyncModel {
    private(set) var status = "Waiting to sync"
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    private(set) var conflicts: [String] = []
    private(set) var needsAttention = false
    private let userID: String
    private weak var model: AppModel?
    private weak var account: AccountModel?
    private let defaults: UserDefaults
    private var checkpoint: SyncEnvelope
    private var pendingRemote: SyncEnvelope?
    private var changeTask: Task<Void, Never>?
    private var foreground = false
    private var activityGeneration = 0
    private var observedSnapshot: SyncSnapshot?
    private static let checkpointKey = "bloomward.sync.checkpoint.v1"
    private static let lastSyncKey = "bloomward.sync.last-success.v1"
    private static let preferenceKeys = ["daymark.profile-name", "daymark.day-start-hour", "daymark.week-start",
                                         "daymark.default-carry-forward", "daymark.default-rest-days"]

    init(userID: String, model: AppModel, account: AccountModel, defaults: UserDefaults) {
        self.userID = userID; self.model = model; self.account = account; self.defaults = defaults
        if let data = defaults.data(forKey: Self.checkpointKey),
           let saved = try? JSONDecoder().decode(SyncEnvelope.self, from: data) {
            checkpoint = saved
        } else { checkpoint = SyncEnvelope() }
        lastSyncedAt = defaults.object(forKey: Self.lastSyncKey) as? Date
        observedSnapshot = snapshot()
    }

    var hasPendingChanges: Bool { snapshot() != checkpoint.snapshot }

    /// The account-scoped root owns this task. Leaving the account cancels all work.
    func runWhileActive() async {
        activityGeneration += 1
        let generation = activityGeneration
        foreground = true
        defer {
            if generation == activityGeneration { foreground = false; changeTask?.cancel() }
        }
        await syncNow()
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(30)) } catch { break }
            await syncNow()
        }
    }

    func pause() { foreground = false; changeTask?.cancel() }

    func localDidChange() {
        let current = snapshot()
        guard current != observedSnapshot else { return }
        observedSnapshot = current
        guard conflicts.isEmpty else { return }
        if !isSyncing { status = "Changes saved on this iPhone. Waiting to sync." }
        guard foreground else { return }
        changeTask?.cancel()
        changeTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            await self?.syncNow()
        }
    }

    func syncNow() async {
        guard !isSyncing, conflicts.isEmpty, account?.userID == userID, !Task.isCancelled else { return }
        guard model?.localDataNeedsRecovery != true else {
            status = "The local save needs recovery. Cloud data has not been changed."
            needsAttention = true
            return
        }
        isSyncing = true; needsAttention = false; status = "Syncing…"
        defer { isSyncing = false }
        do {
            // Retry bounded CAS races, using the latest local edits every time.
            for _ in 0..<4 {
                let remote = try await request(method: "GET")
                try checkAccount()
                guard (1...3).contains(remote.snapshot?.schemaVersion ?? 1) else { throw SyncError.newerVersion }
                let local = snapshot()
                let merged = SyncMerger.merge(base: checkpoint.snapshot ?? SyncSnapshot(), local: local,
                                              remote: remote.snapshot ?? SyncSnapshot())
                if !merged.conflicts.isEmpty {
                    pendingRemote = remote; conflicts = merged.conflicts
                    status = "Changes on two devices need your review."
                    needsAttention = true
                    return
                }
                let accepted: SyncEnvelope
                if merged.snapshot == remote.snapshot { accepted = remote }
                else {
                    do { accepted = try await request(method: "PUT", snapshot: merged.snapshot, revision: remote.revision) }
                    catch SyncError.conflict { continue }
                }
                try checkAccount()
                // Edits made while the upload was in flight remain local and queued.
                let current = snapshot()
                let catchUp = SyncMerger.merge(base: local, local: current, remote: accepted.snapshot ?? SyncSnapshot())
                if !catchUp.conflicts.isEmpty {
                    pendingRemote = accepted; conflicts = catchUp.conflicts
                    status = "Changes on two devices need your review."; needsAttention = true
                    return
                }
                apply(catchUp.snapshot)
                checkpoint = accepted
                persistCheckpoint()
                observedSnapshot = snapshot()
                if snapshot() != accepted.snapshot { continue }
                lastSyncedAt = Date()
                defaults.set(lastSyncedAt, forKey: Self.lastSyncKey)
                status = "Up to date"
                return
            }
            status = "More changes are waiting. We'll retry shortly."
        } catch is CancellationError {
            status = "Changes saved on this iPhone. Waiting to sync."
        } catch {
            needsAttention = true
            status = (error as? SyncError)?.localizedDescription ?? "Couldn't connect. Changes are safe on this iPhone; we'll retry automatically."
        }
    }

    func resolve(_ choice: SyncConflictChoice) {
        guard let remote = pendingRemote, account?.userID == userID else { return }
        // Keep one local recovery copy before the explicitly chosen conflict resolution.
        defaults.set(try? JSONEncoder().encode(snapshot()), forKey: "bloomward.sync.before-conflict-resolution.v1")
        let merged = SyncMerger.merge(base: checkpoint.snapshot ?? SyncSnapshot(), local: snapshot(),
                                      remote: remote.snapshot ?? SyncSnapshot(), choice: choice)
        apply(merged.snapshot)
        checkpoint = remote; persistCheckpoint()
        pendingRemote = nil; conflicts = []; needsAttention = false
        observedSnapshot = snapshot()
        Task { await syncNow() }
    }

    private func snapshot() -> SyncSnapshot {
        var preferences: [String: String] = [:]
        for key in Self.preferenceKeys where defaults.object(forKey: key) != nil {
            if key == "daymark.default-carry-forward" || key == "daymark.default-rest-days" {
                preferences[key] = defaults.bool(forKey: key) ? "true" : "false"
            } else if key == "daymark.profile-name" { preferences[key] = defaults.string(forKey: key) }
            else { preferences[key] = String(defaults.integer(forKey: key)) }
        }
        return SyncSnapshot(state: model?.state ?? AppState(), preferences: preferences)
    }

    private func apply(_ snapshot: SyncSnapshot) {
        model?.applyCloudState(snapshot.state)
        for key in Self.preferenceKeys {
            guard let value = snapshot.preferences[key] else {
                if defaults.object(forKey: key) != nil { defaults.removeObject(forKey: key) }
                continue
            }
            if key == "daymark.profile-name" {
                if defaults.string(forKey: key) != value { defaults.set(value, forKey: key) }
            } else if key == "daymark.default-carry-forward" || key == "daymark.default-rest-days" {
                if defaults.object(forKey: key) == nil || defaults.bool(forKey: key) != (value == "true") {
                    defaults.set(value == "true", forKey: key)
                }
            } else if let number = Int(value), defaults.object(forKey: key) == nil || defaults.integer(forKey: key) != number {
                defaults.set(number, forKey: key)
            }
        }
        model?.refreshDay()
    }

    private func persistCheckpoint() { defaults.set(try? JSONEncoder().encode(checkpoint), forKey: Self.checkpointKey) }
    private func checkAccount() throws {
        try Task.checkCancellation()
        guard account?.userID == userID else { throw CancellationError() }
    }
    private func request(method: String, snapshot: SyncSnapshot? = nil, revision: Int = 0) async throws -> SyncEnvelope {
        try checkAccount()
        guard let account, let clerk = account.clerk,
              let token = try await clerk.auth.getToken() else { throw SyncError.signedOut }
        try checkAccount()
        var request = URLRequest(url: URL(string: "https://api.bloomward.inqox.com/v1/sync")!)
        request.httpMethod = method; request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let snapshot {
            struct Upload: Encodable { let baseRevision: Int; let snapshot: SyncSnapshot }
            let body = try JSONEncoder().encode(Upload(baseRevision: revision, snapshot: snapshot))
            guard body.count <= 512 * 1024 else { throw SyncError.tooLarge }
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkAccount()
        guard let response = response as? HTTPURLResponse else { throw SyncError.unavailable }
        switch response.statusCode {
        case 200: break
        case 409: throw SyncError.conflict
        case 401, 403: throw SyncError.signedOut
        case 413: throw SyncError.tooLarge
        case 422: throw SyncError.invalidData
        case 426: throw SyncError.newerVersion
        default: throw SyncError.unavailable
        }
        guard data.count <= 1024 * 1024 else { throw SyncError.invalidData }
        let result = try JSONDecoder().decode(SyncEnvelope.self, from: data)
        guard result.revision >= 0 else { throw SyncError.invalidData }
        return result
    }
}

private enum SyncError: LocalizedError {
    case conflict, signedOut, unavailable, tooLarge, invalidData, newerVersion
    var errorDescription: String? {
        switch self {
        case .conflict: return "Another device saved changes. Retrying…"
        case .signedOut: return "Please sign in again to resume sync. Your local changes are safe."
        case .unavailable: return "Cloud sync is temporarily unavailable. Your changes are safe on this iPhone; we'll retry."
        case .tooLarge: return "Your backup is larger than this version supports. Your data is safe on this iPhone."
        case .invalidData: return "This backup couldn't be synced. Your local data has not been removed."
        case .newerVersion: return "Update Bloomward to sync changes from a newer version."
        }
    }
}
