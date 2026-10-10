import RoutineCore
import SwiftUI

struct FirstRunPrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) { Text(title); Image(systemName: "arrow.right") }
                .font(.title3.weight(.semibold)).foregroundStyle(.white)
                .padding(.vertical, 16).padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(IllustratedStyle.button, in: Capsule()).opacity(enabled ? 1 : 0.5)
        }.buttonStyle(.plain).disabled(!enabled)
    }
}

struct FirstRunIcon: View {
    var habit: FirstHabit = .breathe
    var size: CGFloat = 70
    private var tint: Color {
        switch habit {
        case .water: Color(red: 0.29, green: 0.57, blue: 0.76)
        case .read: Color(red: 0.57, green: 0.46, blue: 0.32)
        case .breathe: Color(red: 0.42, green: 0.49, blue: 0.65)
        case .walk, .custom: IllustratedStyle.green
        }
    }
    private var pastel: Color {
        switch habit {
        case .water: IllustratedStyle.mist
        case .read: IllustratedStyle.sand
        case .breathe: IllustratedStyle.lavender
        case .walk, .custom: IllustratedStyle.sage
        }
    }
    var body: some View {
        Image(systemName: habit.symbol).font(.system(size: size * 0.42))
            .foregroundStyle(tint.gradient).frame(width: size, height: size)
            .background(pastel.opacity(0.8), in: Circle()).accessibilityHidden(true)
    }
}

@MainActor
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 34.0
    @State private var showsRepeat = false
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        GeometryReader { layout in
            let fullHeight = layout.size.height + layout.safeAreaInsets.top + layout.safeAreaInsets.bottom
            let artHeight = min(fullHeight * 0.265, 250)
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Color.clear.frame(height: max(100, artHeight - layout.safeAreaInsets.top)).id("top")
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title).font(.system(size: titleSize, weight: .bold, design: .serif))
                                .tracking(-0.6).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                            if let subtitle { Text(subtitle).font(.body).foregroundStyle(IllustratedStyle.muted).fixedSize(horizontal: false, vertical: true) }
                        }.padding(.horizontal, 12)
                        switch model.firstRun.step {
                        case .welcome, .start: startChoices
                        case .habit: habitChoices
                        case .setup: setup
                        }
                        if let saveError { Text(saveError).font(.callout) }
                        FirstRunPrimaryButton(title: actionTitle, enabled: canContinue && !isSaving, action: continueFlow)
                            .padding(.horizontal, 12).padding(.top, 8)
                        if model.firstRun.step == .habit {
                            secondaryButton("Create My Own") { model.firstRun.habit = .custom; model.firstRun.goal = 1; model.firstRun.step = .setup }
                        } else if model.firstRun.step == .start {
                            secondaryButton("Maybe Later") { model.finishWelcome() }
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 18).padding(.bottom, 18).frame(maxWidth: 560).frame(maxWidth: .infinity)
                }
                .onChange(of: model.firstRun.step) { _, _ in scroll.scrollTo("top", anchor: .top) }
                .scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
                .background {
                    Image("LoginLandscape").resizable().frame(width: layout.size.width, height: fullHeight)
                        .ignoresSafeArea().accessibilityHidden(true)
                }
                .overlay(alignment: .topLeading) {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left").font(.title3.weight(.medium))
                            .frame(width: 44, height: 44).background(.white.opacity(0.94), in: Circle())
                    }.buttonStyle(.plain).accessibilityLabel("Back").disabled(isSaving).padding(.leading, 18).padding(.top, 4)
                }
            }
        }
        .background(IllustratedStyle.paper).foregroundStyle(IllustratedStyle.ink)
        .tint(IllustratedStyle.green).preferredColorScheme(.light)
        .sheet(isPresented: $showsRepeat) { repeatPicker }
    }
    private var title: String {
        switch model.firstRun.step {
        case .welcome, .start: "How would you like\nto begin?"
        case .habit: "Choose your\nfirst habit"
        case .setup: model.firstRun.choice == .routine ? "A gentle start" : "Set up your habit"
        }
    }
    private var subtitle: String? {
        switch model.firstRun.step {
        case .habit: "Start small. You can always add more."
        case .setup: model.firstRun.choice == .routine ? "Three small steps, about 7 minutes. Add them only if they feel right for you." : "A few details to help you stay consistent."
        default: nil
        }
    }
    private var actionTitle: String {
        isSaving ? "Saving…" : model.firstRun.step == .setup ? (model.firstRun.choice == .routine ? "Add Routine" : "Add Habit") : "Continue"
    }
    private var canContinue: Bool {
        switch model.firstRun.step {
        case .welcome, .start: model.firstRun.choice != nil
        case .habit: model.firstRun.habit != nil
        case .setup: model.firstRun.plan(on: model.today) != nil
        }
    }
    private var startChoices: some View {
        VStack(spacing: 12) {
            choiceCard("Start with one habit", subtitle: "Choose one small action for today.", selected: model.firstRun.choice == .habit) {
                FirstRunIcon(habit: .custom, size: 76)
            } action: { model.firstRun.choice = .habit }
            choiceCard("Try a gentle routine", subtitle: "Follow a few steps together.", selected: model.firstRun.choice == .routine) {
                Image("MorningRoutineArt").resizable().scaledToFill().frame(width: 76, height: 76).clipShape(Circle()).accessibilityHidden(true)
            } action: { model.firstRun.choice = .routine }
        }.padding(.top, 5)
    }
    private var habitChoices: some View {
        VStack(spacing: 10) {
            ForEach([FirstHabit.water, .read, .walk, .breathe], id: \.self) { habit in
                choiceCard(habit.title, subtitle: nil, selected: model.firstRun.habit == habit) {
                    FirstRunIcon(habit: habit, size: 54)
                } action: { model.firstRun.habit = habit; model.firstRun.goal = habit.initialGoal }
            }
        }
    }
    private func choiceCard<Icon: View>(_ title: String, subtitle: String?, selected: Bool,
                                       @ViewBuilder icon: () -> Icon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                if !typeSize.isAccessibilitySize { icon() }
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(subtitle == nil ? .headline : .title3, design: .serif, weight: .semibold))
                    if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(IllustratedStyle.muted) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 26, weight: .light))
                    .foregroundStyle(selected ? IllustratedStyle.green : IllustratedStyle.muted.opacity(0.6)).accessibilityHidden(true)
            }
            .padding(subtitle == nil ? 12 : 18).frame(maxWidth: .infinity, minHeight: subtitle == nil ? 78 : 112)
            .background(selected ? IllustratedStyle.sage.opacity(0.38) : .white.opacity(0.9), in: RoundedRectangle(cornerRadius: 27))
            .overlay(RoundedRectangle(cornerRadius: 27).stroke(selected ? IllustratedStyle.green.opacity(0.65) : .clear, lineWidth: 1.3))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var setup: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            if model.firstRun.choice == .routine {
                ForEach([FirstHabit.breathe, .water, .read], id: \.self) { habit in
                    HStack(spacing: 14) {
                        FirstRunIcon(habit: habit, size: 52)
                        Text(habit.title).font(.system(.headline, design: .serif))
                        Spacer()
                        Text(habit == .read ? "5 min" : "1 min").font(.caption).foregroundStyle(IllustratedStyle.muted)
                    }.padding(.vertical, 8)
                }
            } else {
                HStack(spacing: 14) {
                    if !typeSize.isAccessibilitySize { FirstRunIcon(habit: model.firstRun.habit ?? .custom, size: 82) }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("HABIT").font(.caption).foregroundStyle(IllustratedStyle.muted)
                        if model.firstRun.habit == .custom {
                            TextField("Habit name", text: $model.firstRun.customName, axis: .vertical)
                                .font(.system(.title2, design: .serif, weight: .semibold)).accessibilityIdentifier("first-habit-name")
                            Text("Up to 60 characters").font(.caption).foregroundStyle(IllustratedStyle.muted)
                        } else {
                            Text(model.firstRun.habitTitle).font(.system(.title2, design: .serif, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                            Text("A little moment for you.").font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.bottom, 14)
                Divider()
                setupRow("Goal", subtitle: "How much per day?", symbol: "scope") {
                    if model.firstRun.habit == .custom { Text("Once").font(.subheadline) }
                    else {
                        Menu {
                            ForEach(model.firstRun.habit == .water ? [1, 2, 4, 6, 8] : [1, 2, 5, 10, 15, 20], id: \.self) { goal in
                                Button("\(goal) \(model.firstRun.habit == .water ? (goal == 1 ? "glass" : "glasses") : "min")") { model.firstRun.goal = goal }
                            }
                        } label: { valuePill(model.firstRun.goalLabel) }.accessibilityLabel("Goal, \(model.firstRun.goalLabel)")
                    }
                }
            }
            Divider()
            setupRow("Repeat", subtitle: "How often?", symbol: "calendar") {
                Button { showsRepeat = true } label: { valuePill(repeatLabel) }.buttonStyle(.plain)
            }
            if model.firstRun.choice == .habit {
                Divider()
                setupRow("Reminder", subtitle: "A gentle nudge.", symbol: "bell.fill") {
                    Toggle("Reminder", isOn: $model.firstRun.reminderEnabled).labelsHidden()
                }
                if model.firstRun.reminderEnabled {
                    DatePicker("Remind me at", selection: reminderDate, displayedComponents: .hourAndMinute).padding(.bottom, 10)
                    Text("After Add Habit, iOS will ask permission. Your habit still works without notifications.")
                        .font(.caption).foregroundStyle(IllustratedStyle.muted).padding(.bottom, 14)
                }
            }
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill").foregroundStyle(IllustratedStyle.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.firstRun.weekdays.contains(Calendar.current.component(.weekday, from: model.currentDayDate)) ? "Starts today" : "Starts on your selected days").font(.subheadline.weight(.medium))
                    Text("You can always change this later.").font(.caption).foregroundStyle(IllustratedStyle.muted)
                }
                Spacer(minLength: 0)
            }.padding(14).background(IllustratedStyle.sage.opacity(0.45), in: RoundedRectangle(cornerRadius: 20))
        }.padding(16).background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28))
    }
    private func setupRow<Control: View>(_ title: String, subtitle: String, symbol: String, @ViewBuilder control: () -> Control) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { rowLabel(title, subtitle: subtitle, symbol: symbol); Spacer(minLength: 8); control() }
            VStack(alignment: .leading, spacing: 12) { rowLabel(title, subtitle: subtitle, symbol: symbol); control() }
        }.padding(.vertical, 13)
    }
    private func rowLabel(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: symbol).font(.title3).foregroundStyle(IllustratedStyle.green).frame(width: 44, height: 44)
                    .background(IllustratedStyle.sage.opacity(0.7), in: Circle()).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(IllustratedStyle.muted) }
                .fixedSize(horizontal: true, vertical: false)
        }
    }
    private func valuePill(_ value: String) -> some View {
        HStack(spacing: 10) { Text(value); Image(systemName: "chevron.right").font(.caption) }
            .font(.subheadline).padding(.horizontal, 14).frame(minHeight: 44).background(IllustratedStyle.mist.opacity(0.6), in: Capsule())
    }
    private var repeatLabel: String { model.firstRun.weekdays.count == 7 ? "Every day" : "\(model.firstRun.weekdays.count) days / week" }
    private var reminderDate: Binding<Date> {
        Binding(get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(model.firstRun.reminderMinute * 60)) }, set: {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
            model.firstRun.reminderMinute = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        })
    }
    private var repeatPicker: some View {
        NavigationStack {
            List {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                    Toggle(Calendar.current.weekdaySymbols[day - 1], isOn: Binding(get: { model.firstRun.weekdays.contains(day) }, set: { on in
                        if on { model.firstRun.weekdays.insert(day) }
                        else if model.firstRun.weekdays.count > 1 { model.firstRun.weekdays.remove(day) }
                    }))
                }
                Text("Choose at least one day. You won't be marked behind on the other days.").font(.footnote)
            }.navigationTitle("Repeat").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsRepeat = false } } }
        }.presentationDetents([.medium, .large])
    }
    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).underline().font(.subheadline.weight(.medium)).buttonStyle(.plain)
            .foregroundStyle(IllustratedStyle.muted).frame(maxWidth: .infinity, minHeight: 44)
    }
    private func goBack() {
        saveError = nil
        switch model.firstRun.step {
        case .welcome, .start: model.firstRun.step = .welcome
        case .habit: model.firstRun.step = .start
        case .setup: model.firstRun.step = model.firstRun.choice == .routine ? .start : .habit
        }
    }
    private func continueFlow() {
        switch model.firstRun.step {
        case .welcome, .start: model.firstRun.step = model.firstRun.choice == .routine ? .setup : .habit
        case .habit: model.firstRun.step = .setup
        case .setup:
            guard !isSaving else { return }
            isSaving = true
            Task { @MainActor in
                if model.firstRun.reminderEnabled && model.firstRun.choice == .habit {
                    if account.isUITesting { model.reminderNotice = "Notification permission isn't requested in this isolated preview." }
                    else if await HabitReminders.shared.requestPermission() { model.firstHabitReminderMinute = model.firstRun.reminderMinute }
                    else { model.reminderNotice = "Your habit is saved without a reminder. You can allow notifications in iPhone Settings later." }
                }
                if !model.addFirstPlan() { saveError = "Your habit couldn't be saved. Check its name and selected days." }
                isSaving = false
            }
        }
    }
}
