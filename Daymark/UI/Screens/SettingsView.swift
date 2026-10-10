import SwiftUI
import ClerkKitUI

@MainActor
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @AppStorage("daymark.day-start-hour") private var dayStartHour = 5
    @AppStorage("daymark.week-start") private var weekStart = 2
    @AppStorage("daymark.appearance") private var appearance = "System"
    @AppStorage("daymark.profile-name") private var profileName = ""
    @AppStorage("daymark.default-carry-forward") private var carryForward = true
    @AppStorage("daymark.default-rest-days") private var restDays = true
    @AppStorage("daymark.haptics") private var haptics = true
    @State private var destination: SettingsDestination?
    @State private var draftName = ""
    @State private var showsAccount = false
    @State private var confirmsSignOut = false
    @State private var reviewsSyncConflict = false
    @State private var accountTheme = BloomwardAccountTheme.make()

    var body: some View {
        GeometryReader { layout in
            let scale = min(layout.size.width / 432, 1.2)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    landscapeHeader(width: layout.size.width, topInset: layout.safeAreaInsets.top)

                    profile(scale: scale)
                        .padding(.horizontal, 20)
                        .padding(.top, -28)

                    VStack(alignment: .leading, spacing: 24) {
                    section("Account", detail: account.userID == nil ? "Your habits stay on this iPhone." : "Your progress, wherever you go.", scale: scale) {
                        if account.userID != nil {
                            Button { showsAccount = true } label: {
                                row("Manage account", value: account.email, symbol: "person.crop.circle", tint: IllustratedStyle.sage, scale: scale)
                            }.buttonStyle(.plain)
                            divider
                            if let sync = model.cloudSync {
                                Button {
                                    if sync.conflicts.isEmpty { Task { await sync.syncNow() } }
                                    else { reviewsSyncConflict = true }
                                } label: {
                                    row("Cloud sync", value: sync.isSyncing ? "Syncing…" : (sync.needsAttention ? "Review" : "Sync now"),
                                        symbol: sync.needsAttention ? "icloud.slash" : "icloud", tint: IllustratedStyle.mist, scale: scale)
                                }.buttonStyle(.plain).disabled(sync.isSyncing)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sync.status)
                                    if let lastSync = sync.lastSyncedAt {
                                        Text("Last synced \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                    }
                                }.font(.caption).foregroundStyle(IllustratedStyle.muted).padding(.vertical, 8)
                                divider
                            }
                            Button { confirmsSignOut = true } label: {
                                row(account.isBusy ? "Signing out…" : "Sign out", symbol: "rectangle.portrait.and.arrow.right", tint: IllustratedStyle.mist, scale: scale)
                            }.buttonStyle(.plain).disabled(account.isBusy)
                        } else {
                            Button { account.isLoginPresented = true } label: {
                                row("Sign in or create account", value: "Local mode", symbol: "person.crop.circle", tint: IllustratedStyle.sage, scale: scale)
                            }.buttonStyle(.plain)
                        }
                        Text(account.userID == nil
                             ? "Local mode stays on this iPhone. Sign in to sync account habits; guest habits are kept separate."
                             : "Habits, routines, progress, and your profile preferences sync automatically. Active timers, appearance, and haptics stay on this iPhone.")
                            .font(.caption).foregroundStyle(IllustratedStyle.muted).padding(.vertical, 8)
                        if let error = account.errorMessage {
                            Text(error).font(.caption).foregroundStyle(IllustratedStyle.ink).padding(.bottom, 8)
                        }
                    }
                    section("Preferences", detail: "A calmer, brighter experience.", scale: scale) {
                        Button { destination = .notifications } label: {
                            row("Notifications", value: model.firstHabitReminderMinute == nil ? "Off" : "On this iPhone", symbol: "bell.fill", tint: IllustratedStyle.lavender, scale: scale)
                        }.buttonStyle(.plain)
                        divider
                        Menu {
                            Picker("Appearance", selection: $appearance) {
                                Text("System").tag("System")
                                Text("Light").tag("Light")
                                Text("Dark").tag("Dark")
                            }
                        } label: {
                            row("Appearance", value: appearance, symbol: "sun.max.fill", tint: IllustratedStyle.sand, scale: scale)
                        }
                        .accessibilityLabel("Appearance").accessibilityValue(appearance)
                        divider
                        Menu {
                            Picker("Start of day", selection: $dayStartHour) {
                                ForEach([0, 4, 5, 6, 7], id: \.self) { hour in Text(hourLabel(hour)).tag(hour) }
                            }
                        } label: {
                            row("Start of day", value: hourLabel(dayStartHour), symbol: "clock", tint: IllustratedStyle.sage, scale: scale)
                        }
                        .accessibilityLabel("Start of day").accessibilityValue(hourLabel(dayStartHour))
                        .onChange(of: dayStartHour) { _, _ in model.refreshDay() }
                        divider
                        Menu {
                            Picker("Week starts", selection: $weekStart) {
                                Text("Monday").tag(2)
                                Text("Sunday").tag(1)
                            }
                        } label: {
                            row("Week starts", value: weekStart == 1 ? "Sunday" : "Monday", symbol: "calendar", tint: IllustratedStyle.blush, scale: scale)
                        }
                        .accessibilityLabel("Week starts").accessibilityValue(weekStart == 1 ? "Sunday" : "Monday")
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        section("Habit settings", detail: "Small choices. A bigger you.", scale: scale) {
                            toggleRow("Carry unfinished habits forward", symbol: "chevron.forward.2", value: $carryForward, scale: scale)
                            divider
                            toggleRow("Allow intentional rest days", symbol: "leaf.fill", value: $restDays, scale: scale)
                        }
                        Text("Defaults for new habits. Carry-forward is a saved preference; automation isn't enabled yet.")
                            .font(.footnote)
                            .foregroundStyle(IllustratedStyle.muted)
                            .padding(.horizontal, 12 * scale)
                    }

                    section("Support", detail: "We're here whenever you need us.", scale: scale) {
                        Button { destination = .help } label: {
                            row("Help & feedback", symbol: "questionmark", tint: IllustratedStyle.mist, scale: scale)
                        }.buttonStyle(.plain)
                        divider
                        Button { destination = .privacy } label: {
                            row("Privacy & data", symbol: "shield.lefthalf.filled", tint: IllustratedStyle.sage, scale: scale)
                        }.buttonStyle(.plain)
                        divider
                        Button { destination = .about } label: {
                            row("About", value: "Version \(version)", symbol: "info", tint: IllustratedStyle.lavender, scale: scale)
                        }.buttonStyle(.plain)
                    }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .background(alignment: .bottomTrailing) {
                        IllustratedFoliage()
                            .frame(width: 60 * scale, height: 112 * scale)
                            .opacity(0.35)
                            .offset(x: 15 * scale, y: 20 * scale)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.bottom, 22)
            }
            .scrollIndicators(.hidden)
            .background { IllustratedScreenBackdrop() }
            .ignoresSafeArea(edges: .top)
        }
        .foregroundStyle(IllustratedStyle.ink)
        .tint(IllustratedStyle.green)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $destination) { detail($0) }
        .sheet(isPresented: $showsAccount) {
            if let clerk = account.clerk {
                UserProfileView()
                    .environment(clerk)
                    .environment(\.clerkTheme, accountTheme)
            }
        }
        .confirmationDialog("Sign out of Bloomward?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await model.cloudSync?.syncNow(); await account.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll try to sync first. Any unsynced changes stay on this iPhone for this account. You will return to local guest mode.")
        }
        .confirmationDialog("Review changes from two devices", isPresented: $reviewsSyncConflict, titleVisibility: .visible) {
            Button("Use this iPhone for conflicting items") { model.cloudSync?.resolve(.thisDevice) }
            Button("Use cloud for conflicting items") { model.cloudSync?.resolve(.cloud) }
            Button("Decide later", role: .cancel) {}
        } message: {
            Text("Both devices changed: \(model.cloudSync?.conflicts.prefix(5).joined(separator: ", ") ?? ""). Choose which version of those items to keep. Other changes will be combined. Nothing is overwritten until you choose.")
        }
    }

    private func landscapeHeader(width: CGFloat, topInset: CGFloat) -> some View {
        IllustratedScreenHeader(title: "Settings", subtitle: "Make the app feel like yours.",
                                quote: "Built around\nyour rhythm.", topInset: topInset)
    }

    private func profile(scale: CGFloat) -> some View {
        IllustratedCard {
            HStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    Circle().fill(IllustratedStyle.sage).frame(width: 70, height: 70)
                        .overlay {
                            if let first = profileName.first {
                                Text(String(first).uppercased())
                                    .font(.system(size: 36, weight: .semibold, design: .serif))
                            } else { Image(systemName: "person").font(.title) }
                        }
                    Image(systemName: "leaf.fill").font(.caption)
                        .frame(width: 25, height: 25).background(.white, in: Circle())
                }
                .foregroundStyle(IllustratedStyle.green).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(profileName.isEmpty ? "Your space" : profileName)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                    Text(profileName.isEmpty ? "Make it personal" : "Your personal space")
                        .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                    Button {
                        draftName = profileName
                        destination = .profile
                    } label: {
                        Label(profileName.isEmpty ? "Add name" : "Edit profile", systemImage: "chevron.right")
                            .font(.subheadline.weight(.medium)).foregroundStyle(IllustratedStyle.green)
                            .frame(minHeight: 44)
                    }.buttonStyle(.plain)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func row(_ title: String, value: String? = nil, symbol: String, tint: Color, scale: CGFloat) -> some View {
        HStack(spacing: 12) {
            icon(symbol, tint: tint, scale: scale)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Text(title).font(.body).fixedSize()
                    Spacer(minLength: 0)
                    if let value { Text(value).font(.subheadline).foregroundStyle(IllustratedStyle.muted).fixedSize() }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body)
                    if let value { Text(value).font(.subheadline).foregroundStyle(IllustratedStyle.muted) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(IllustratedStyle.muted)
        }
        .padding(.vertical, 10).frame(minHeight: 64).contentShape(Rectangle())
    }

    private func toggleRow(_ title: String, symbol: String, value: Binding<Bool>, scale: CGFloat) -> some View {
        HStack(spacing: 12) {
            icon(symbol, tint: IllustratedStyle.sage, scale: scale)
            Toggle(title, isOn: value).font(.body).tint(IllustratedStyle.green)
        }
        .padding(.vertical, 10).frame(minHeight: 64)
    }

    private func icon(_ symbol: String, tint: Color, scale: CGFloat) -> some View {
        Image(systemName: symbol).font(.title2).foregroundStyle(iconColor(symbol))
            .frame(width: 44, height: 44).background(tint, in: Circle()).accessibilityHidden(true)
    }

    private func iconColor(_ symbol: String) -> Color {
        switch symbol {
        case "sun.max.fill": return .orange.opacity(0.8)
        case "bell.fill", "info": return Color(red: 0.40, green: 0.45, blue: 0.60)
        case "calendar": return Color(red: 0.64, green: 0.43, blue: 0.44)
        case "questionmark": return Color(red: 0.28, green: 0.48, blue: 0.65)
        default: return IllustratedStyle.green.opacity(0.85)
        }
    }

    private var divider: some View {
        Divider().opacity(0.3).padding(.leading, 54)
    }

    private func section<Content: View>(_ title: String, detail: String, scale: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            IllustratedSectionHeading(title: title, detail: detail).padding(.horizontal, 4)
            IllustratedCard {
                VStack(alignment: .leading, spacing: 0) { content() }
            }
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }

    private func detail(_ item: SettingsDestination) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(item.rawValue).font(.system(size: 28, weight: .semibold, design: .serif))
                switch item {
                case .profile:
                    Text("What would you like to be called? When signed in, your name syncs with your account.")
                        .foregroundStyle(IllustratedStyle.muted)
                    TextField("Your name (optional)", text: $draftName)
                        .textContentType(.givenName).textInputAutocapitalization(.words)
                        .padding(16).background(IllustratedStyle.sage.opacity(0.4), in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityLabel("Your name")
                    Button("Save name") {
                        profileName = String(draftName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                        destination = nil
                    }.buttonStyle(.borderedProminent)
                    Button("Cancel") { destination = nil }.buttonStyle(.bordered)
                case .notifications:
                    Text("Your first-habit reminder")
                    if model.state.habits.contains(where: { $0.id == model.firstRun.habitIDs.first }) {
                        Toggle("Reminder on this iPhone", isOn: Binding(get: { model.firstHabitReminderMinute != nil }, set: { enabled in
                            if !enabled { model.firstHabitReminderMinute = nil }
                            else { Task {
                                guard !account.isUITesting else { return }
                                if await HabitReminders.shared.requestPermission() { model.firstHabitReminderMinute = model.firstRun.reminderMinute }
                                else { model.reminderNotice = "Allow notifications for Bloomward in iPhone Settings to receive reminders." }
                            } }
                        }))
                        if model.firstHabitReminderMinute != nil {
                            DatePicker("Time", selection: Binding(get: {
                                Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double((model.firstHabitReminderMinute ?? 540) * 60))
                            }, set: {
                                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                                model.firstHabitReminderMinute = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
                            }), displayedComponents: .hourAndMinute)
                        }
                    }
                    Text("First-use reminders repeat on that habit's selected days while this local profile or account is active on this iPhone. Pausing or archiving the habit stops them. Notifications also need permission in iPhone Settings. Advanced reminder styles in the habit editor are still in development.")
                        .foregroundStyle(IllustratedStyle.muted)
                    if let notice = model.reminderNotice { Text(notice).font(.caption) }
                    Toggle("Haptic feedback", isOn: $haptics)
                    Text("Haptics provide an in-app tap when you log progress. They aren't reminders.")
                        .font(.caption).foregroundStyle(IllustratedStyle.muted)
                case .help:
                    Text("Start small").font(.headline)
                    Text("Use Add Habit to choose a name, schedule, and options. Tap a habit's name to edit it, or its circle to log today.")
                    Text("Make room to adjust").font(.headline)
                    Text("Touch and hold a habit to use a minimum version, skip, or take a rest day. Paused habits live in the Paused filter.")
                    Text("Feedback delivery isn't connected yet. No message is sent from this screen.")
                        .font(.caption).foregroundStyle(IllustratedStyle.muted)
                case .privacy:
                    Text("Local mode stores your habits, history, and optional name on this iPhone. No account is required.")
                    Text("If you sign in, Clerk manages your account and credentials. Apple handles Apple sign-in. Local habits are separated by account; guest habits are not automatically transferred. Manage your account, security, or account deletion in the Account section.")
                    Text("When signed in, your habits, routines, progress, and profile preferences are also stored in your account's Cloudflare database over an encrypted connection. They are restored when you sign in on another iPhone. This is not end-to-end encrypted. Guest habits never upload automatically. Active timers, appearance, and haptics stay on the device. Unsynced changes and local-mode data can be lost if you remove the app.")
                        .foregroundStyle(IllustratedStyle.muted)
                case .about:
                    Text("Bloomward").font(.system(size: 24, weight: .semibold, design: .serif))
                    Text("Small routines. A brighter you.")
                    Text("Version \(version)").foregroundStyle(IllustratedStyle.muted)
                    Text("An early native iOS build. Habit logging, routines, and local insights work offline. First-use reminders are optional. Advanced reminders and carry-forward automation are still in development.")
                }
                if item != .profile {
                    Button("Done") { destination = nil }.buttonStyle(.borderedProminent)
                }
            }
            .font(.system(size: 15))
            .padding(26)
        }
        .foregroundStyle(IllustratedStyle.ink)
        .tint(IllustratedStyle.green)
        .presentationBackground(IllustratedStyle.paper)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private enum SettingsDestination: String, Identifiable {
    case profile = "Your profile", notifications = "Notifications", help = "Help & feedback", privacy = "Privacy & data", about = "About Bloomward"
    var id: Self { self }
}

#Preview {
    NavigationStack { SettingsView().environment(AppModel.preview).environment(AccountModel(isUITesting: true)) }
}
