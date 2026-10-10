import SwiftUI

/// Reference-led account entry, backed by Clerk's native authentication flow.
struct LoginView: View {
    let continueLocally: () -> Void
    @Environment(AccountModel.self) private var account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var information: AccountInformation?

    var body: some View {
        GeometryReader { layout in
            let width = layout.size.width
            let height = layout.size.height
            let scale = min(width / 427, 1.2)
            let flexible = dynamicTypeSize.isAccessibilitySize || width > height

            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: flexible ? min(height * 0.3, 220) : height * 0.286)
                    Text("Keep your plan\nand progress safe")
                        .font(flexible ? .system(.largeTitle, design: .serif, weight: .bold) : .system(size: 36 * scale, weight: .bold, design: .serif))
                        .foregroundStyle(IllustratedStyle.ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-3 * scale)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .frame(height: flexible ? nil : height * 0.089)
                        .padding(.horizontal, 25 * scale)
                        .accessibilityAddTraits(.isHeader)

                    Text("Sync your routine, restore your\nprogress, and keep going on any iPhone.")
                        .font(flexible ? .body : .system(size: 15.5 * scale))
                        .foregroundStyle(IllustratedStyle.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3 * scale)
                        .frame(height: flexible ? nil : height * 0.075)
                        .padding(.horizontal, 25 * scale)

                    HStack {
                        benefit("cloud.fill", tint: Color(red: 0.48, green: 0.70, blue: 0.87), background: IllustratedStyle.mist, scale: scale)
                        Spacer(minLength: 12)
                        benefit("checkmark.shield.fill", tint: Color(red: 0.34, green: 0.56, blue: 0.43), background: IllustratedStyle.sage, scale: scale)
                        Spacer(minLength: 12)
                        benefit("leaf.fill", tint: Color(red: 0.35, green: 0.57, blue: 0.46), background: IllustratedStyle.sage, scale: scale)
                    }
                    .padding(.horizontal, 59 * scale)
                    .frame(height: flexible ? 110 : height * 0.1)
                    .accessibilityHidden(true)

                    Text(account.isBusy ? "Connecting securely…" : "Account progress syncs. Local mode stays on this iPhone.")
                        .font(flexible ? .caption : .system(size: 10 * scale))
                        .foregroundStyle(IllustratedStyle.muted)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: max(26, height * 0.036))
                        .padding(.horizontal, 24)

                    VStack(spacing: 12 * scale) {
                        NativeAppleButton(action: {
                            Task {
                                let completed = await account.signInWithApple()
                                if completed || account.errorMessage == nil { account.endPresentation() }
                            }
                        }, isEnabled: !account.isBusy)
                        .frame(height: max(48, 52 * scale))
                        providerButton("Continue with Email", symbol: "envelope", dark: false, scale: scale) {
                            account.beginPresentation()
                            information = .email
                        }
                        .disabled(account.isBusy)
                        if let error = account.errorMessage {
                            Text(error).font(.caption).foregroundStyle(IllustratedStyle.ink)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("account-error")
                        }
                    }
                    .padding(.horizontal, 23 * scale)

                    Button {
                        account.endPresentation()
                        continueLocally()
                    } label: {
                        Text("Continue on This iPhone")
                            .font(flexible ? .headline : .system(size: 17 * scale, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18 * scale)
                    .disabled(account.isBusy)
                    .accessibilityHint("Use Bloomward without an account. Your habits stay on this device.")

                    HStack(spacing: 12 * scale) {
                        Rectangle().fill(IllustratedStyle.muted.opacity(0.3)).frame(height: 0.7)
                        Text("Already have an account?")
                            .font(flexible ? .caption : .system(size: 12 * scale))
                            .foregroundStyle(IllustratedStyle.muted)
                            .fixedSize(horizontal: !flexible, vertical: true)
                        Rectangle().fill(IllustratedStyle.muted.opacity(0.3)).frame(height: 0.7)
                    }
                    .padding(.horizontal, 59 * scale)
                    .padding(.top, 24 * scale)
                    Button("Sign In") {
                        account.beginPresentation()
                        information = .signIn
                    }
                        .font(flexible ? .headline : .system(size: 17 * scale, weight: .semibold))
                        .frame(minWidth: 80, minHeight: 44)
                        .buttonStyle(.plain)
                        .disabled(account.isBusy)

                    Spacer(minLength: 12)
                    VStack(spacing: 0) {
                        Text("Local mode works without an account.")
                            .foregroundStyle(IllustratedStyle.muted)
                        HStack(spacing: 7) {
                            Button("Terms") { information = .terms }.underline()
                            Text("and").foregroundStyle(IllustratedStyle.muted)
                            Button("Privacy Policy") { information = .privacy }.underline()
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                    }
                    .font(flexible ? .caption : .system(size: 10.5 * scale))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 35 * scale)
                    .padding(.bottom, max(20, layout.safeAreaInsets.bottom + 8))
                }
                .frame(minHeight: height)
                .background(alignment: .top) {
                    Image("LoginLandscape")
                        .resizable()
                        .frame(width: width, height: height)
                        .accessibilityHidden(true)
                    if flexible {
                        IllustratedStyle.paper.opacity(0.96)
                            .padding(.top, min(height * 0.3, 220))
                    }
                }
                .overlay(alignment: .topLeading) {
                    Button { account.endPresentation(); dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20 * scale, weight: .medium))
                            .foregroundStyle(IllustratedStyle.ink)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.9), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(account.isBusy)
                    .accessibilityLabel("Back")
                    .padding(.leading, 18 * scale)
                    .padding(.top, max(46 * scale, layout.safeAreaInsets.top + 6))
                }
                .overlay(alignment: .topTrailing) {
                    Text("A\nbrighter\ntomorrow\nwith you")
                        .font(.custom("SnellRoundhand", size: 17 * scale))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 0.43, green: 0.56, blue: 0.53))
                        .rotationEffect(.degrees(-12))
                        .padding(.trailing, 18 * scale)
                        .padding(.top, height * 0.067)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
            .scrollIndicators(.hidden)
            .background(IllustratedStyle.paper)
        }
        .ignoresSafeArea()
        .foregroundStyle(IllustratedStyle.green)
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(account.isBusy)
        .sheet(item: $information, onDismiss: { account.endPresentation() }) { item in
            switch item {
            case .email, .signIn:
                AccountFlowView(signInOnly: item == .signIn)
            case .terms, .privacy:
                AccountInformationSheet(item: item)
            }
        }
    }

    private func benefit(_ symbol: String, tint: Color, background: Color, scale: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 43 * scale, weight: .regular))
            .foregroundStyle(LinearGradient(colors: [tint.opacity(0.82), tint], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 86 * scale, height: 86 * scale)
            .background(background.opacity(0.7), in: Circle())
    }

    private func providerButton(_ title: String, symbol: String, dark: Bool, scale: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14 * scale) {
                Image(systemName: symbol).font(.system(size: 25 * scale, weight: .medium))
                Text(title).font(.system(size: 19 * scale, weight: .semibold))
            }
            .foregroundStyle(dark ? .white : IllustratedStyle.ink)
            .frame(maxWidth: .infinity, minHeight: max(48, 52 * scale))
            .background(dark ? Color(white: 0.045) : .white.opacity(0.82), in: Capsule())
            .overlay(Capsule().stroke(dark ? .clear : IllustratedStyle.muted.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens secure account sign-up and sign-in.")
    }
}

private enum AccountInformation: String, Identifiable {
    case email, signIn, terms, privacy
    var id: Self { self }

    var title: String {
        switch self {
        case .email: "Continue with Email"
        case .signIn: "Sign In"
        case .terms: "Terms"
        case .privacy: "Privacy & local data"
        }
    }

    var message: String {
        switch self {
        case .email, .signIn: "Sign in securely with Clerk."
        case .terms:
            "Published Bloomward terms haven't been provided for this development build. This information screen does not record acceptance of an agreement. Final terms are required before public release."
        case .privacy:
            "In local mode, habits and progress stay on this iPhone. If you sign in, Clerk manages authentication and Apple handles Apple sign-in. Account habits, routines, progress, and profile preferences sync to Cloudflare over an encrypted connection; this is not end-to-end encrypted. Credentials are never stored with habits. Each account has separate data, and guest habits never upload automatically. Unsynced changes may be lost if you remove the app. This is development-build information, not a published privacy policy."
        }
    }
}

private struct AccountInformationSheet: View {
    let item: AccountInformation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(item.title)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(item.message).font(.body).foregroundStyle(IllustratedStyle.muted)
                Button("Back") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
            }
            .padding(28)
        }
        .foregroundStyle(IllustratedStyle.ink)
        .tint(IllustratedStyle.green)
        .presentationBackground(IllustratedStyle.paper)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    LoginView(continueLocally: {}).environment(AccountModel(isUITesting: true))
}
