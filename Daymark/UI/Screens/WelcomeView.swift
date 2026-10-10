import SwiftUI

@MainActor
struct DaymarkRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @State private var entersLocallyOnDismiss = false
    @State private var showsFirstCompletion = false

    var body: some View {
        @Bindable var account = account
        Group {
            if model.hasEnteredApp {
                AppShellView()
            } else {
                PlannerWelcomeView(
                    start: { model.finishWelcome() },
                    signIn: { account.isLoginPresented = true }
                )
            }
        }
        .sheet(isPresented: $showsFirstCompletion) {
            FirstCompletionView().presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $account.isLoginPresented, onDismiss: {
            if entersLocallyOnDismiss {
                entersLocallyOnDismiss = false
                model.finishWelcome()
            }
        }) {
            PlannerLoginView {
                entersLocallyOnDismiss = true
                account.isLoginPresented = false
            }
        }
    }
}

struct WelcomeView: View {
    let getStarted: () -> Void
    let explore: () -> Void
    let signIn: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 44.0

    var body: some View {
        GeometryReader { layout in
            let fullHeight = layout.size.height + layout.safeAreaInsets.top + layout.safeAreaInsets.bottom
            let landscapeHeight = min(fullHeight * 0.48, 470)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: max(180, landscapeHeight - layout.safeAreaInsets.top))
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Small habits.\nA brighter you.")
                            .font(.system(size: headingSize, weight: .bold, design: .serif))
                            .tracking(-1.3)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("Build a gentler rhythm,\none small step at a time.")
                            .font(.title3).foregroundStyle(IllustratedStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }.padding(.horizontal, 34)
                    VStack(spacing: 14) {
                        FirstRunPrimaryButton(title: "Get Started", action: getStarted)
                            .accessibilityIdentifier("onboarding-get-started")
                        Button(action: explore) {
                            Text("Explore First").font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(.white.opacity(0.35), in: Capsule())
                                .overlay(Capsule().stroke(IllustratedStyle.green.opacity(0.22), lineWidth: 1))
                        }
                        .buttonStyle(.plain).foregroundStyle(IllustratedStyle.green)
                        .accessibilityHint("Open the app with no habits and no account required.")
                    }.padding(.horizontal, 34).padding(.top, 30)
                    ViewThatFits {
                        HStack(spacing: 5) { signInPrompt }
                        VStack(spacing: 0) { signInPrompt }
                    }
                    .font(.subheadline).frame(maxWidth: .infinity)
                    .padding(.top, 22).padding(.bottom, 22).padding(.horizontal, 18)
                }
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .frame(minHeight: layout.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .background {
                Image("WelcomeLandscape").resizable()
                    .frame(width: layout.size.width, height: fullHeight)
                    .overlay {
                        // Keep decorative foliage behind the body copy quiet, not behind letters.
                        LinearGradient(stops: [
                            .init(color: .clear, location: 0.53),
                            .init(color: IllustratedStyle.paper.opacity(0.94), location: 0.60),
                            .init(color: IllustratedStyle.paper.opacity(0.94), location: 0.69),
                            .init(color: .clear, location: 0.76)
                        ], startPoint: .top, endPoint: .bottom)
                    }
                    .ignoresSafeArea().accessibilityHidden(true)
            }
            .overlay(alignment: .topTrailing) {
                Text("Begin\ngently.")
                    .font(.custom("SnellRoundhand", size: 25))
                    .rotationEffect(.degrees(-10)).foregroundStyle(IllustratedStyle.green.opacity(0.65))
                    .padding(.top, 55).padding(.trailing, 32)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
        }
        .foregroundStyle(IllustratedStyle.ink)
        .background(IllustratedStyle.paper).preferredColorScheme(.light)
    }

    @ViewBuilder private var signInPrompt: some View {
        Text("Already have an account?").foregroundStyle(IllustratedStyle.muted)
        Button("Sign In", action: signIn).underline().fontWeight(.semibold)
            .buttonStyle(.plain).foregroundStyle(IllustratedStyle.green).frame(minHeight: 44)
    }
}
