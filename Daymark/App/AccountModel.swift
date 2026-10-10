import AuthenticationServices
import ClerkKit
import Observation
import RoutineCore
import SwiftUI

/// Clerk owns credentials and session persistence. Habit data never enters an auth request.
@MainActor
@Observable
final class AccountModel {
    let clerk: Clerk?
    let isUITesting: Bool
    private(set) var isBusy = false
    private(set) var holdsAccountPresentation = false
    var isLoginPresented = false
    var errorMessage: String?
    private var requestedLocalBackup: AppState?
    var localImport: LocalImportRequest?

    struct LocalImportRequest: Identifiable {
        let id = UUID()
        let userID: String
        let state: AppState
    }

    func requestLocalBackup(_ state: AppState) { requestedLocalBackup = state }
    func cancelLocalBackup() { requestedLocalBackup = nil }

    init(isUITesting: Bool = false) {
        self.isUITesting = isUITesting
        if isUITesting {
            clerk = nil
        } else {
            // Publishable client key, not a secret. Never embed a Clerk secret or Apple key.
            clerk = Clerk.configure(
                publishableKey: "pk_live_Y2xlcmsuYmxvb213YXJkLmlucW94LmNvbSQ",
                options: .init(telemetryEnabled: false)
            )
        }
    }

    var userID: String? {
        guard let clerk, clerk.isAuthFlowComplete,
              let session = clerk.session, session.status == .active,
              session.expireAt > Date() else { return nil }
        return clerk.user?.id
    }

    var email: String? { userID == nil ? nil : clerk?.user?.primaryEmailAddress?.emailAddress }

    var storageScope: AccountStorageScope {
        // Don't replace a presented authentication form before its completion/dismissal.
        guard !holdsAccountPresentation, let userID else { return .guest }
        return .account(userID)
    }

    func restore() async {
        // Clerk restores its cache synchronously and performs its own initial fetch.
        // Don't put a network spinner in front of an offline-first habit tracker.
        guard let clerk, clerk.session != nil else { return }
        do {
            _ = try await clerk.refreshClient()
        } catch {
            // A cached active session may still select this device's local account data.
            // It is never used as proof of authorization for the backend.
            errorMessage = "Couldn't refresh your account. Check your connection before signing in. Habits on this iPhone remain available."
        }
    }

    func observeAccountEvents() async {
        guard let clerk else { return }
        var lastAccountID = clerk.user?.id
        for await event in clerk.auth.events {
            guard !Task.isCancelled else { return }
            if case .accountDeleted = event, let lastAccountID,
               let suite = AccountStorageScope.account(lastAccountID).defaultsSuiteName {
                // Only follows the user's confirmed deletion in Clerk's account-management UI.
                UserDefaults.standard.removePersistentDomain(forName: suite)
            }
            if let id = clerk.user?.id { lastAccountID = id }
        }
    }

    func prepareLogin() async throws {
        guard let clerk else { throw AccountError.preview }
        if clerk.environment == nil { _ = try await clerk.refreshEnvironment() }
        if clerk.client == nil { _ = try await clerk.refreshClient() }
    }

    func beginPresentation() { holdsAccountPresentation = true; errorMessage = nil }
    func endPresentation() {
        if let userID {
            isLoginPresented = false
            if let state = requestedLocalBackup { localImport = LocalImportRequest(userID: userID, state: state) }
        }
        requestedLocalBackup = nil
        holdsAccountPresentation = false
    }

    func signInWithApple() async -> Bool {
        guard !isBusy else { return false }
        beginPresentation()
        isBusy = true
        defer { isBusy = false }
        do {
            try await prepareLogin()
            guard let clerk else { return false }
            _ = try await clerk.auth.signInWithApple()
            if userID != nil { return true }
            // A pending session is not a login. Clerk's form can complete session tasks.
            errorMessage = "One more verification step is needed. Continue in the account form below."
        } catch {
            if !Self.isCancellation(error) { report(error) }
        }
        return false
    }

    func signOut() async {
        guard !isBusy, let clerk else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do { try await clerk.auth.signOut() }
        catch { report(error) }
    }

    func handleCallback(_ url: URL) async {
        // Let Clerk validate the callback; a URL alone can never authenticate the app.
        guard url.scheme == "com.inqox.bloomward", let clerk else { return }
        do { _ = try await clerk.handle(url) }
        catch { report(error) }
    }

    func report(_ error: Error) {
        if let known = error as? AccountError { errorMessage = known.localizedDescription }
        else if error is URLError { errorMessage = "Couldn't connect. Check your internet connection and try again." }
        else { errorMessage = (error as? ClerkAPIError)?.longMessage ?? "Sign-in couldn't be completed. Please try again." }
        // Deliberately don't log credentials, tokens, email addresses, or verification codes.
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if let appleError = error as? ASAuthorizationError, appleError.code == .canceled { return true }
        return error is CancellationError
    }
}

private enum AccountError: LocalizedError {
    case preview
    var errorDescription: String? { "Real sign-in is disabled in UI testing. Relaunch normally to connect your account." }
}

/// New view identity and storage per account; guest data is never silently merged or erased.
@MainActor
struct AccountScopedRoot: View {
    @StateObject private var storage: ScopedAccountStorage
    @Environment(AccountModel.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    private let scope: AccountStorageScope
    private let isUITesting: Bool

    init(scope: AccountStorageScope, isUITesting: Bool) {
        self.scope = scope
        self.isUITesting = isUITesting
        // StateObject's lazy initializer avoids rebuilding a persistence-writing AppModel
        // whenever the account's loading or presentation state changes.
        _storage = StateObject(wrappedValue: ScopedAccountStorage(scope: scope, isUITesting: isUITesting))
    }

    var body: some View {
        DaymarkRootView()
            .environment(storage.model)
            .defaultAppStorage(storage.defaults)
            .task(id: scenePhase) {
                if !isUITesting, scenePhase == .active { storage.model.refreshReminders() }
                guard !isUITesting, case .account(let id) = scope, scenePhase == .active else { return }
                if storage.model.cloudSync == nil {
                    storage.model.cloudSync = CloudSyncModel(userID: id, model: storage.model, account: account, defaults: storage.defaults)
                }
                await storage.model.cloudSync?.runWhileActive()
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                storage.model.cloudSync?.localDidChange()
            }
            .onDisappear { storage.model.cloudSync?.pause() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { storage.model.cloudSync?.pause() }
            }
            .sheet(isPresented: Binding(get: {
                guard case .account(let id) = scope else { return false }
                return account.localImport?.userID == id
            }, set: { if !$0 { account.localImport = nil } })) {
                LocalHabitImportView {
                    guard case .account(let id) = scope, let request = account.localImport, request.userID == id else { return }
                    storage.model.importLocalHabits(request.state)
                    account.localImport = nil
                }
                .environment(storage.model)
            }
    }
}

@MainActor
private final class ScopedAccountStorage: ObservableObject {
    let model: AppModel
    let defaults: UserDefaults

    init(scope: AccountStorageScope, isUITesting: Bool) {
        let defaults: UserDefaults
        if isUITesting {
            defaults = UserDefaults(suiteName: "bloomward.ui-testing.\(UUID().uuidString)")!
        } else if let suiteName = scope.defaultsSuiteName {
            // Fail closed instead of falling back to somebody else's guest storage.
            guard let accountDefaults = UserDefaults(suiteName: suiteName) else {
                preconditionFailure("Unable to create isolated account storage")
            }
            defaults = accountDefaults
        } else {
            defaults = .standard
        }
        self.defaults = defaults
        model = AppModel(storage: isUITesting ? nil : defaults)
        if case .account = scope { model.finishWelcome() }
    }
}
