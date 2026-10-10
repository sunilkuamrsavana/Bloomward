import RoutineCore
import SwiftUI

@MainActor
struct HabitsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var filter = HabitLibraryFilter.all
    @State private var editor: HabitEditorDraft?

    var body: some View {
        GeometryReader { layout in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    IllustratedLibraryHeader(title: "Habits", subtitle: "Your habits, with or without a routine.",
                                            topInset: layout.safeAreaInsets.top)
                    if !model.activeHabits.isEmpty {
                        progressCard
                            .padding(.horizontal, 20)
                            .padding(.top, -10)
                    }
                    IllustratedFilterBar(items: HabitLibraryFilter.allCases, selection: $filter) { $0.rawValue }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                    if filteredHabits.isEmpty {
                        emptyState
                    } else {
                        if filter == .paused {
                            group("Paused habits", detail: "Here when you're ready.", habits: filteredHabits)
                        } else {
                            ForEach(HabitTimeGroup.allCases) { time in
                                let habits = filteredHabits.filter { timeGroup($0) == time }
                                if !habits.isEmpty {
                                    group(time.rawValue, detail: time.detail, habits: habits)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
        }
        .background { IllustratedScreenBackdrop() }
        .foregroundStyle(IllustratedStyle.ink)
        .tint(IllustratedStyle.green)
        .modifier(IllustratedLibraryActions(addLabel: "Add habit") {
            editor = HabitEditorDraft(habit: nil)
        })
        .onChange(of: model.lastSavedHabitID) { _, _ in filter = .all }
        .onChange(of: model.activeHabits.map(\.id)) { old, new in
            if !Set(new).subtracting(old).isEmpty { filter = .all }
        }
        .fullScreenCover(item: $editor) { draft in
            NewHabitView(habit: draft.habit).environment(model)
        }
    }

    private var progressCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(IllustratedStyle.green.opacity(0.12), lineWidth: 5)
                Circle().trim(from: 0, to: model.completionRatio)
                    .stroke(IllustratedStyle.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "leaf.fill").font(.subheadline).foregroundStyle(IllustratedStyle.green)
            }.frame(width: 38, height: 38).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.todayHabits.isEmpty ? "Nothing scheduled today" : "\(model.completedTodayCount) of \(model.todayHabits.count) done today")
                    .font(.subheadline.weight(.semibold))
                Text("\(model.activeHabits.count) \(model.activeHabits.count == 1 ? "habit" : "habits") in your library")
                    .font(.caption).foregroundStyle(IllustratedStyle.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14).background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
    }

    private func group(_ title: String, detail: String, habits: [Habit]) -> some View {
        VStack(spacing: 12) {
            IllustratedSectionHeading(title: title, detail: detail)
                .padding(.horizontal, 4)
            ForEach(habits) { habit in habitRow(habit) }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func habitRow(_ habit: Habit) -> some View {
        let status = model.status(for: habit)
        let done = status == .completed || status == .minimum
        let paused = habit.settings?.isPaused == true
        let routines = model.state.routines(containing: habit.id)
        return HStack(spacing: 8) {
            Button { model.toggle(habit) } label: {
                Image(systemName: paused ? "pause.circle" : done ? "checkmark.circle.fill" : status == .rest ? "moon.circle" : status == .skipped ? "minus.circle" : "circle")
                    .font(.system(size: 27, weight: .light))
                    .foregroundStyle(done ? IllustratedStyle.green : IllustratedStyle.muted.opacity(0.6))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(paused)
            .accessibilityLabel(done ? "Undo completion of \(habit.title)" : "Log \(habit.title)")
            .accessibilityValue(paused ? "Paused" : statusLabel(status))
            Button { editor = HabitEditorDraft(habit: habit) } label: {
                HStack(spacing: 12) {
                    if !typeSize.isAccessibilitySize {
                    Image(systemName: habit.symbolName)
                        .font(.system(size: 23))
                        .foregroundStyle(habit.symbolName == "drop.fill" ? Color(red: 0.30, green: 0.56, blue: 0.73) : IllustratedStyle.green)
                        .frame(width: 42, height: 42)
                        .background(categoryTint(habit), in: Circle())
                        .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(habit.title).font(.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(paused ? "Paused" : status == .pending ? scheduleLabel(habit) : statusLabel(status))
                            .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        if !routines.isEmpty {
                            Label(routines.count == 1 ? "In \(routines[0].title)" : "In \(routines.count) routines", systemImage: "link")
                                .font(.footnote).foregroundStyle(IllustratedStyle.green)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .regular)).foregroundStyle(IllustratedStyle.muted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(habit.title)")
            .accessibilityValue(routines.isEmpty ? "Standalone habit" : "Linked to \(routines.map(\.title).joined(separator: ", "))")
        }
        .padding(.leading, 8).padding(.trailing, 18)
        .padding(.vertical, 12)
        .frame(minHeight: 76)
        .background(.white.opacity(0.91), in: RoundedRectangle(cornerRadius: 28))
        .contextMenu {
            Button("Edit habit", systemImage: "pencil") { editor = HabitEditorDraft(habit: habit) }
            Button("Use minimum version", systemImage: "leaf") { model.recover(habit, with: .minimum) }
                .disabled(paused || done)
            Button("Skip intentionally", systemImage: "forward") { model.recover(habit, with: .skip) }
                .disabled(paused || done)
            Button("Take a rest day", systemImage: "moon") { model.recover(habit, with: .rest) }
                .disabled(paused || done || habit.settings?.allowsRest == false)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: filter == .paused ? "pause.circle" : "leaf")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(IllustratedStyle.green)
                .frame(width: 70, height: 70)
                .background(IllustratedStyle.sage, in: Circle())
                .accessibilityHidden(true)
            Text(model.activeHabits.isEmpty ? "One small habit,\njust for you." : filter == .paused ? "Nothing on pause" : "A little breathing room")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(model.activeHabits.isEmpty ? "Choose something that matters to you.\nYour habits will appear here, at your pace." : filter == .paused ? "Habits you pause for vacation will be here." : "Nothing is scheduled for today.\nYou can find your other habits in All.")
                .font(.body).foregroundStyle(IllustratedStyle.muted)
                .multilineTextAlignment(.center)
            if model.activeHabits.isEmpty {
                Button {
                    editor = HabitEditorDraft(habit: nil)
                } label: {
                    Text("Create your first habit")
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(IllustratedPillButtonStyle())
                .accessibilityIdentifier("habits.createFirst")
            } else if filter != .all {
                Button("See all habits") { filter = .all }.buttonStyle(.bordered)
            }
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var filteredHabits: [Habit] {
        model.libraryHabits(filter).reversed()
    }

    private func timeGroup(_ habit: Habit) -> HabitTimeGroup {
        guard let settings = habit.settings, settings.timeWindowEnabled else { return .anytime }
        if settings.startMinute < 12 * 60 { return .morning }
        if settings.startMinute >= 18 * 60 { return .evening }
        return .anytime
    }

    private func scheduleLabel(_ habit: Habit) -> String {
        guard let settings = habit.settings else { return "Every day · Any time" }
        let weekdays = Calendar.current.shortWeekdaySymbols
        let days = settings.weekdays.count == 7 ? "Every day" :
            settings.weekdays.sorted().filter { (1...7).contains($0) }
                .map { weekdays[$0 - 1] }.joined(separator: ", ")
        guard settings.timeWindowEnabled else { return days + " · Any time" }
        let date = Calendar.current.date(bySettingHour: settings.startMinute / 60, minute: settings.startMinute % 60, second: 0, of: Date()) ?? Date()
        return days + " · " + date.formatted(.dateTime.hour().minute())
    }

    private func statusLabel(_ status: DailyHabitStatus) -> String {
        switch status {
        case .pending: "Not yet logged"
        case .completed: "Completed today"
        case .minimum: "Minimum version done"
        case .skipped: "Skipped intentionally"
        case .rest: "Intentional rest day"
        }
    }

    private func categoryTint(_ habit: Habit) -> Color {
        switch habit.settings?.category ?? .custom {
        case .health: IllustratedStyle.mist
        case .mind: IllustratedStyle.lavender
        case .productivity: IllustratedStyle.sand
        case .lifestyle: IllustratedStyle.blush
        case .custom: IllustratedStyle.sage
        }
    }
}

private struct HabitEditorDraft: Identifiable {
    let id = UUID()
    let habit: Habit?
}

private enum HabitTimeGroup: String, CaseIterable, Identifiable {
    case morning = "Morning", anytime = "Anytime", evening = "Evening"
    var id: Self { self }
    var detail: String {
        switch self {
        case .morning: "Set the tone for a brighter day."
        case .anytime: "Build better moments, anytime."
        case .evening: "A calmer you tomorrow."
        }
    }
}

#Preview {
    NavigationStack { HabitsView().environment(AppModel.preview) }
}

@MainActor
struct NewHabitView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var name: String
    @State private var symbol: String
    @State private var settings: HabitSettings
    @State private var showsIcons = false
    @State private var timeEditor: HabitTimeEditor?
    @State private var validationMessage: String?
    @FocusState private var nameFocused: Bool
    @AppStorage("daymark.default-carry-forward") private var defaultCarryForward = true
    @AppStorage("daymark.default-rest-days") private var defaultRestDays = true
    @State private var appliedDefaults = false
    private let habitID: Habit.ID?
    private let onSave: ((Habit) -> Void)?

    init(habit: Habit? = nil, onSave: ((Habit) -> Void)? = nil) {
        habitID = habit?.id
        self.onSave = onSave
        _name = State(initialValue: habit?.title ?? "")
        _symbol = State(initialValue: habit?.symbolName ?? "leaf.fill")
        _settings = State(initialValue: habit?.settings ?? .newHabitDefaults)
    }

    var body: some View {
        GeometryReader { layout in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        IllustratedScreenHeader(title: habitID == nil ? "New Habit" : "Edit Habit",
                                          subtitle: "Small steps. A brighter you.",
                                          quote: "A healthier you\ntomorrow",
                                          topInset: layout.safeAreaInsets.top,
                                          back: { dismiss() })
                        VStack(alignment: .leading, spacing: 28) {
                            habitSection
                            scheduleSection
                            optionsSection
                            reminderSection
                            notesSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, -8)
                        .padding(.bottom, 28)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .ignoresSafeArea(edges: .top)
                VStack(spacing: 0) {
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.callout).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24).padding(.top, 10)
                            .accessibilityIdentifier("habit-validation")
                    }
                    IllustratedActionFooter(title: onSave != nil ? "Add to Routine" : habitID == nil ? "Save Habit" : "Save Changes",
                                      symbol: "arrow.right", enabled: canSave, action: save)
                }
                .background(IllustratedStyle.paper.opacity(0.97))
            }
        }
        .background { IllustratedScreenBackdrop() }
        .foregroundStyle(IllustratedStyle.ink)
        .tint(IllustratedStyle.green)
        .sheet(isPresented: $showsIcons) { iconPicker }
        .sheet(item: $timeEditor) { editor in timePicker(editor) }
        .onChange(of: name) { _, value in
            validationMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).count > 60
                ? "Keep your habit name to 60 characters or fewer." : nil
        }
        .onAppear {
            guard !appliedDefaults else { return }
            appliedDefaults = true
            if habitID == nil {
                settings.carryForward = defaultCarryForward
                settings.allowsRest = defaultRestDays
            }
        }
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 60 && !settings.weekdays.isEmpty
            && (!settings.timeWindowEnabled || settings.startMinute < settings.endMinute)
    }

    private var habitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            IllustratedSectionHeading(title: "Habit")
            IllustratedCard {
                HStack(spacing: 16) {
                    Button { showsIcons = true } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 29))
                            .foregroundStyle(Color(red: 0.25, green: 0.40, blue: 0.51))
                            .frame(width: 64, height: 64)
                            .background(IllustratedStyle.mist, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose habit icon")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Habit name").font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                        TextField("e.g. Workout", text: $name)
                            .font(.title3.weight(.semibold))
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit { nameFocused = false }
                            .accessibilityLabel("Habit name")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            // Horizontal scrolling keeps every category readable and tappable on small phones.
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(HabitCategory.allCases) { category in
                        Button { settings.category = category } label: {
                            Text(category.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(settings.category == category ? .white : IllustratedStyle.muted)
                                .padding(.horizontal, 17)
                                .padding(.vertical, 12)
                                .frame(minHeight: 44)
                                .background(settings.category == category ? IllustratedStyle.green : .white.opacity(0.8), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(settings.category == category ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            IllustratedSectionHeading(title: "Schedule", detail: "Make it fit your life.")
            IllustratedCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        formIcon("calendar", tint: IllustratedStyle.sage)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How often?").font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                            Menu {
                                Button("Every day") { settings.weekdays = Set(1...7) }
                                Button("Weekdays") { settings.weekdays = Set(2...6) }
                                Button("Three times a week") { settings.weekdays = [2, 4, 6] }
                                Button("Weekends") { settings.weekdays = [1, 7] }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(settings.weekdays.count == 7 ? "Every day" : "\(settings.weekdays.count) days a week")
                                        .fixedSize(horizontal: false, vertical: true)
                                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                                }
                                .font(.body.weight(.medium)).frame(minHeight: 44, alignment: .leading)
                            }
                            .accessibilityLabel("Repeat schedule")
                        }
                        Spacer(minLength: 0)
                    }
                    ViewThatFits(in: .horizontal) {
                        weekdayButtons
                        ScrollView(.horizontal) { weekdayButtons }.scrollIndicators(.hidden)
                    }
                    if settings.weekdays.isEmpty {
                        Text("Choose at least one day.").font(.callout).foregroundStyle(.red)
                    }
                    Divider().opacity(0.45)
                    Toggle(isOn: $settings.timeWindowEnabled) {
                        Label {
                            Text("Time window").font(.body.weight(.medium))
                        } icon: {
                            Image(systemName: "clock").foregroundStyle(IllustratedStyle.green)
                        }
                    }
                    if settings.timeWindowEnabled {
                        Button { timeEditor = .window } label: {
                            HStack(spacing: 12) {
                                Text("\(timeLabel(settings.startMinute)) – \(timeLabel(settings.endMinute))")
                                    .font(.body.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.subheadline)
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit time window")
                        .accessibilityValue("\(timeLabel(settings.startMinute)) to \(timeLabel(settings.endMinute))")
                    }
                    Text("Optional. Choose a window that fits your day.")
                        .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var weekdayButtons: some View {
        HStack(spacing: 0) {
            ForEach(1...7, id: \.self) { day in
                Button {
                    if settings.weekdays.contains(day) { settings.weekdays.remove(day) }
                    else { settings.weekdays.insert(day) }
                } label: {
                    Text(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][day - 1])
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(settings.weekdays.contains(day) ? .white : IllustratedStyle.muted)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(settings.weekdays.contains(day) ? IllustratedStyle.green : IllustratedStyle.lavender.opacity(0.45), in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][day - 1])
                .accessibilityAddTraits(settings.weekdays.contains(day) ? .isSelected : [])
            }
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            IllustratedSectionHeading(title: "Options", detail: "A little flexibility.")
            IllustratedCard {
                VStack(spacing: 16) {
                    optionRow("Carry unfinished habits forward", detail: "Saved preference · automation coming later",
                              symbol: "chevron.forward.2", tint: IllustratedStyle.sage, value: $settings.carryForward)
                    Divider().opacity(0.4)
                    optionRow("Allow intentional rest days", detail: "Make room for a day of rest.",
                              symbol: "leaf.fill", tint: IllustratedStyle.sage, value: $settings.allowsRest)
                    Divider().opacity(0.4)
                    optionRow("Pause during vacation", detail: "Temporarily pause this habit.",
                              symbol: "airplane", tint: IllustratedStyle.lavender, value: $settings.isPaused)
                    Divider().opacity(0.4)
                    VStack(alignment: .leading, spacing: 6) {
                        Button { timeEditor = .endOfDay } label: {
                            HStack(spacing: 14) {
                                if !typeSize.isAccessibilitySize {
                                    formIcon("sun.max.fill", tint: IllustratedStyle.sand)
                                }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Custom end-of-day").font(.body.weight(.medium))
                                    Text(settings.endOfDayMinute.map(timeLabel) ?? "Default")
                                        .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.subheadline)
                            }
                            .frame(minHeight: 44)
                        }.buttonStyle(.plain)
                        Text("Saved preference. Custom day rollover isn't active yet.")
                            .font(.footnote).foregroundStyle(IllustratedStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func optionRow(_ title: String, detail: String, symbol: String, tint: Color, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize { formIcon(symbol, tint: tint) }
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.body.weight(.medium))
                    Text(detail).font(.footnote).foregroundStyle(IllustratedStyle.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityLabel(title)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            IllustratedSectionHeading(title: "Reminders", detail: "Your preferred nudge.")
            IllustratedCard {
                VStack(alignment: .leading, spacing: 14) {
                    let arrangement = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 10))
                        : AnyLayout(HStackLayout(spacing: 8))
                    arrangement {
                        ForEach(HabitReminderStyle.allCases) { style in
                            Button { settings.reminderStyle = style } label: {
                                VStack(spacing: 6) {
                                    Text(style.rawValue).font(.subheadline.weight(.medium))
                                    Text(style == .gentle ? "One nudge" : style == .persistent ? "A few nudges" : "Until done")
                                        .font(.caption).foregroundStyle(IllustratedStyle.muted)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 4).padding(.vertical, 14)
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(style == .gentle ? IllustratedStyle.lavender.opacity(0.5) : style == .persistent ? IllustratedStyle.sage : IllustratedStyle.blush.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20).stroke(settings.reminderStyle == style ? IllustratedStyle.green : .clear, lineWidth: 1.5)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(style.rawValue) reminder preference")
                            .accessibilityAddTraits(settings.reminderStyle == style ? .isSelected : [])
                        }
                    }
                    Text("These styles are saved preferences, not active alerts. Manage your first habit's reminder in Settings → Notifications.")
                        .font(.footnote).foregroundStyle(IllustratedStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            IllustratedSectionHeading(title: "Notes", detail: "Optional")
            IllustratedCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "pencil").font(.body).foregroundStyle(IllustratedStyle.muted)
                        .padding(.top, 3)
                    TextField("e.g. Gym, home workout, yoga class…", text: $settings.notes, axis: .vertical)
                        .font(.body).lineLimit(3...6)
                        .accessibilityLabel("Habit notes")
                }
                .frame(minHeight: 82, alignment: .top)
            }
        }
    }

    private func formIcon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 22))
            .foregroundStyle(symbol == "sun.max.fill" ? Color.orange.opacity(0.8) : IllustratedStyle.green)
            .frame(width: 44, height: 44)
            .background(tint.opacity(0.8), in: Circle())
            .accessibilityHidden(true)
    }

    private var iconPicker: some View {
        VStack(spacing: 18) {
            Text("Choose an icon").font(.system(size: 25, weight: .semibold, design: .serif))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                ForEach(["dumbbell.fill", "drop.fill", "book", "leaf.fill", "sun.max.fill", "moon.fill", "figure.walk", "heart.fill", "fork.knife", "pencil", "laptopcomputer", "calendar"], id: \.self) { item in
                    Button {
                        symbol = item
                        showsIcons = false
                    } label: {
                        Image(systemName: item).font(.title2).frame(width: 55, height: 55)
                            .background(IllustratedStyle.sage.opacity(0.65), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
                }
            }
            Button("Cancel") { showsIcons = false }.buttonStyle(.bordered)
        }
        .padding(24).presentationDetents([.medium])
    }

    private func timePicker(_ editor: HabitTimeEditor) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(editor == .window ? "Your time window" : "Your end-of-day")
                .font(.system(size: 25, weight: .semibold, design: .serif))
            if editor == .window {
                DatePicker("From", selection: minuteBinding($settings.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: minuteBinding($settings.endMinute), displayedComponents: .hourAndMinute)
                if settings.startMinute >= settings.endMinute {
                    Text("Choose an end time after the start time.").foregroundStyle(.red).font(.caption)
                }
            } else {
                Toggle("Use a custom end-of-day", isOn: Binding(get: { settings.endOfDayMinute != nil }, set: { settings.endOfDayMinute = $0 ? 1380 : nil }))
                if settings.endOfDayMinute != nil {
                    DatePicker("End time", selection: minuteBinding(Binding(get: { settings.endOfDayMinute ?? 1380 }, set: { settings.endOfDayMinute = $0 })), displayedComponents: .hourAndMinute)
                }
                Text("Saved as a preference. Custom day rollover is not active yet.").font(.caption).foregroundStyle(.secondary)
            }
            Button("Done") { timeEditor = nil }
                .buttonStyle(.borderedProminent)
                .disabled(editor == .window && settings.startMinute >= settings.endMinute)
        }
        .padding(26).presentationDetents([.medium])
    }

    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date()
        }, set: { value in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
            minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        })
    }

    private func timeLabel(_ minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Give your habit a name first."
            nameFocused = true
            return
        }
        guard !settings.weekdays.isEmpty else { validationMessage = "Choose at least one day."; return }
        if let onSave {
            guard canSave, settings.isValid else {
                validationMessage = "Use a name under 61 characters and a valid time window."
                return
            }
            let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
            onSave(Habit(title: title, symbolName: symbol,
                         minimumTitle: "A small version of \(title.lowercased())", settings: settings))
            dismiss()
            return
        }
        guard model.saveHabit(id: habitID, title: name, symbol: symbol, settings: settings) else {
            validationMessage = "Use a name under 61 characters and a valid time window."
            return
        }
        dismiss()
    }
}

private enum HabitTimeEditor: String, Identifiable {
    case window, endOfDay
    var id: Self { self }
}
