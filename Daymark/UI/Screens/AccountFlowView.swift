import AuthenticationServices
import ClerkKit
import ClerkKitUI
import SwiftUI

@MainActor
enum BloomwardAccountTheme {
    static func make() -> ClerkTheme {
        ClerkTheme(
            colors: .init(
                primary: .accentColor,
                background: Color(uiColor: .systemBackground),
                input: Color(uiColor: .secondarySystemBackground),
                foreground: .primary,
                mutedForeground: .secondary,
                inputForeground: .primary,
                ring: .accentColor,
                secondaryButtonForeground: .primary
            ),
            fonts: .init(title: .system(.title, weight: .semibold)),
            design: .init(borderRadius: 12)
        )
    }
}

/// Only one Clerk AuthView is mounted at a time. It handles password policy, codes,
/// retries, recovery, MFA and pending-session tasks using the production configuration.
struct AccountFlowView: View {
    @Environment(AccountModel.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var ready = false
    @State private var loading = false
    @State private var failure: String?
    @State private var theme = BloomwardAccountTheme.make()
    let signInOnly: Bool

    var body: some View {
        Group {
            if ready, let clerk = account.clerk {
                LoadedAccountForm(signInOnly: signInOnly)
                    .environment(clerk)
                    .environment(\.clerkTheme, theme)
            } else {
                VStack(spacing: 22) {
                    Image(systemName: "leaf.fill").font(.largeTitle).foregroundStyle(IllustratedStyle.green)
                    Text("Your Bloomward account")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                    if failure == nil { ProgressView("Connecting securely…") }
                    if let failure {
                        Text(failure).multilineTextAlignment(.center).foregroundStyle(IllustratedStyle.muted)
                        Button("Try again") { Task { await prepare() } }.buttonStyle(.borderedProminent)
                    }
                    Button("Back") { dismiss() }.frame(minHeight: 44)
                }
                .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(IllustratedStyle.paper)
            }
        }
        .tint(IllustratedStyle.green)
        .task { await prepare() }
    }

    private func prepare() async {
        guard !loading, !ready else { return }
        loading = true
        failure = nil
        defer { loading = false }
        do { try await account.prepareLogin(); ready = true }
        catch { account.report(error); failure = account.errorMessage }
    }
}

private struct LoadedAccountForm: View {
    @StateObject private var content: AccountFormContent

    init(signInOnly: Bool) {
        _content = StateObject(wrappedValue: AccountFormContent(signInOnly: signInOnly))
    }

    var body: some View { content.view }
}

@MainActor
private final class AccountFormContent: ObservableObject {
    let view: AuthView

    init(signInOnly: Bool) {
        // Clerk's identifier-persistence opt-out clears defaults during construction.
        // Construct once, outside body: repeating it alongside Settings' @AppStorage
        // creates a preference-notification/render loop on iOS 26.2.
        view = AuthView(mode: signInOnly ? .signIn : .signInOrUp)
            .persistsIdentifiers(false)
    }
}

/// Apple's own button, while Clerk performs the native authorization and token exchange.
struct NativeAppleButton: UIViewRepresentable {
    let action: () -> Void
    var isEnabled = true

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .continue, style: .black)
        button.cornerRadius = 28
        button.addTarget(context.coordinator, action: #selector(Coordinator.activate), for: .touchUpInside)
        return button
    }
    func updateUIView(_ button: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
        button.isEnabled = isEnabled
        button.alpha = isEnabled ? 1 : 0.55
    }
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func activate() { action() }
    }
}
