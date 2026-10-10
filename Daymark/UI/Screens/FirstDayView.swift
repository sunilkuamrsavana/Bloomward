import RoutineCore
import SwiftUI

struct FirstDayTodayView: View {
    let habit: Habit
    let topInset: CGFloat
    let browseRoutines: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    private var completed: Bool { model.status(for: habit) == .completed || model.status(for: habit) == .minimum }
    private var suggestion: FirstHabit { FirstHabit.allCases.first { $0.symbol == habit.symbolName } ?? .custom }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            IllustratedScreenHeader(title: greeting,
                subtitle: completed ? "You took your first step today." : "Your first day starts here.",
                quote: "Small steps,\nbrighter days", topInset: topInset)
            ZStack {
                Circle().fill(IllustratedStyle.paper)
                Circle().stroke(IllustratedStyle.green.opacity(0.12), lineWidth: 12).padding(12)
                Circle().trim(from: 0, to: completed ? 1 : 0)
                    .stroke(IllustratedStyle.button, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(12)
                VStack(spacing: 5) {
                    (Text(completed ? "1" : "0").font(.system(size: 45, weight: .bold, design: .serif)) + Text(" of 1").font(.title3.weight(.semibold)))
                    Text("habit done\ntoday").font(.body).foregroundStyle(IllustratedStyle.muted).multilineTextAlignment(.center)
                }
            }.frame(width: 180, height: 180).frame(maxWidth: .infinity).padding(.top, -44)
                .accessibilityElement(children: .ignore).accessibilityLabel("\(completed ? 1 : 0) of 1 habits done today")
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(completed ? "Done today" : "Now").font(.system(.title2, design: .serif, weight: .bold))
                    Spacer()
                    if !typeSize.isAccessibilitySize { Text(completed ? "One small step counts." : "Make it happen today.").font(.caption).foregroundStyle(IllustratedStyle.muted) }
                }.padding(.horizontal, 7)
                VStack(alignment: .trailing, spacing: 9) {
                    HStack(spacing: 14) {
                        if !typeSize.isAccessibilitySize { FirstRunIcon(habit: suggestion, size: 66) }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(habit.title).font(.system(.title3, design: .serif, weight: .semibold))
                            Text(habit.settings?.weekdays.count == 7 ? "Daily • One small step" : "On your selected days")
                                .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: completed ? "checkmark.circle.fill" : "circle").font(.system(size: 28, weight: .light))
                            .foregroundStyle(completed ? IllustratedStyle.green : IllustratedStyle.muted.opacity(0.6)).accessibilityHidden(true)
                    }
                    Button { model.toggle(habit) } label: {
                        Text(completed ? "Completed" : "Mark Done").font(.headline)
                            .padding(.horizontal, 24).frame(minHeight: 44)
                            .foregroundStyle(completed ? IllustratedStyle.green : .white)
                            .background(completed ? IllustratedStyle.sage : IllustratedStyle.green, in: Capsule())
                    }.buttonStyle(.plain).accessibilityLabel(completed ? "Completed, undo habit completion" : "Mark Done")
                        .accessibilityIdentifier("first-habit-complete")
                }.padding(18).background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 28))
                Button(action: browseRoutines) {
                    HStack(spacing: 13) {
                        if !typeSize.isAccessibilitySize { FirstRunIcon(habit: .custom, size: 52) }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Explore when you’re ready").font(.system(.headline, design: .serif))
                            Text("Browse routines").font(.subheadline).underline().foregroundStyle(IllustratedStyle.green)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right").font(.caption)
                    }.padding(20).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 28))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 20)
            if let notice = model.reminderNotice {
                Text(notice).font(.callout).foregroundStyle(IllustratedStyle.muted).padding(.horizontal, 24)
            }
        }
        .foregroundStyle(IllustratedStyle.ink)

    }
}

struct FirstCompletionView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var accountForm: FormMode?
    private enum FormMode: String, Identifiable { case email, signIn; var id: Self { self } }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                IllustratedScenery(alignment: .center).frame(height: 140)
                    .overlay(alignment: .bottom) { IllustratedWave().fill(IllustratedStyle.paper).frame(height: 40) }
                    .overlay(alignment: .topTrailing) {
                        Button { account.cancelLocalBackup(); dismiss() } label: {
                            Image(systemName: "xmark").font(.body.weight(.medium)).frame(width: 44, height: 44).background(.white, in: Circle())
                        }.buttonStyle(.plain).accessibilityLabel("Not now, close backup prompt").padding(14).disabled(account.isBusy)
                    }
                Image(systemName: "leaf.circle.fill").font(.system(size: 44)).foregroundStyle(IllustratedStyle.green).accessibilityHidden(true)
                Text("Your first habit\nis done").font(.system(.largeTitle, design: .serif, weight: .bold))
                    .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                Text("Saved on this iPhone").font(.headline).foregroundStyle(IllustratedStyle.green)
                Text("Create an account to back up your progress and continue on another iPhone.")
                    .font(.body).foregroundStyle(IllustratedStyle.muted).multilineTextAlignment(.center).padding(.horizontal, 25)
                VStack(spacing: 12) {
                    NativeAppleButton(action: {
                        account.requestLocalBackup(model.state)
                        Task {
                            let completed = await account.signInWithApple()
                            if completed || account.errorMessage == nil { account.endPresentation() }
                        }
                    }, isEnabled: !account.isBusy).frame(height: 52)
                    Button {
                        account.requestLocalBackup(model.state); account.beginPresentation(); accountForm = .email
                    } label: {
                        Label("Continue with Email", systemImage: "envelope").font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(.white, in: Capsule()).overlay(Capsule().stroke(IllustratedStyle.muted.opacity(0.3)))
                    }.buttonStyle(.plain).disabled(account.isBusy)
                    Text("After sign-in, choose whether to add these local habits to your account. Your local copy stays here.")
                        .font(.caption).foregroundStyle(IllustratedStyle.muted).multilineTextAlignment(.center)
                    if let error = account.errorMessage { Text(error).font(.caption).multilineTextAlignment(.center) }
                    Button("Not Now") { account.cancelLocalBackup(); dismiss() }.underline().frame(minHeight: 44).disabled(account.isBusy)
                    HStack(spacing: 6) {
                        Text("Already have an account?").foregroundStyle(IllustratedStyle.muted)
                        Button("Sign In") { account.requestLocalBackup(model.state); account.beginPresentation(); accountForm = .signIn }
                            .underline().frame(minHeight: 44).disabled(account.isBusy)
                    }.font(.footnote)
                }.padding(.horizontal, 26).padding(.bottom, 22)
            }
        }
        .background(IllustratedStyle.paper).foregroundStyle(IllustratedStyle.ink).tint(IllustratedStyle.green)
        .preferredColorScheme(.light).interactiveDismissDisabled(account.isBusy)
        .sheet(item: $accountForm, onDismiss: { account.endPresentation() }) { mode in AccountFlowView(signInOnly: mode == .signIn) }
        .onDisappear { if account.userID == nil { account.cancelLocalBackup() } }
    }
}

struct LocalHabitImportView: View {
    let addToAccount: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "icloud.and.arrow.up").font(.largeTitle).foregroundStyle(IllustratedStyle.green)
            Text("Bring your plan with you").font(.system(.title, weight: .semibold))
            Text("Add the tasks, routines, notes, and progress saved on this iPhone to your signed-in account? Existing account records are kept. A local copy stays on this iPhone.")
                .foregroundStyle(IllustratedStyle.muted)
            FirstRunPrimaryButton(title: "Add to My Account", enabled: !model.localDataNeedsRecovery, action: addToAccount)
            Button("Keep Separate") { dismiss() }.frame(minHeight: 44)
            if model.localDataNeedsRecovery { Text("This account's local save needs recovery first. Your guest habits remain safe.").font(.caption) }
        }.multilineTextAlignment(.center).padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(IllustratedStyle.paper)
            .foregroundStyle(IllustratedStyle.ink).presentationDetents([.medium, .large])
    }
}
