import SwiftUI

@main
@MainActor
struct DaymarkApp: App {
    @State private var account: AccountModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        // Keep manual UI verification separate from the user's saved habits.
        _account = State(initialValue: AccountModel(isUITesting: CommandLine.arguments.contains("--ui-testing")))
        #else
        _account = State(initialValue: AccountModel())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                AccountScopedRoot(scope: account.storageScope, isUITesting: account.isUITesting)
                    .id(account.storageScope.defaultsSuiteName ?? "guest")
            }
            .environment(account)
            .task { await account.restore() }
            .task { await account.observeAccountEvents() }
            .onOpenURL { url in Task { await account.handleCallback(url) } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, !account.holdsAccountPresentation {
                    Task { await account.restore() }
                }
            }
        }
    }
}
