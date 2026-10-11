import Combine
import ClerkKitUI
import RoutineCore
import SwiftUI

private enum PlannerStyle {
    static let canvas = adaptive(
        light: UIColor(red: 0.97, green: 0.965, blue: 0.95, alpha: 1),
        dark: UIColor(red: 0.075, green: 0.085, blue: 0.08, alpha: 1)
    )
    static let surface = adaptive(
        light: .white,
        dark: UIColor(red: 0.12, green: 0.135, blue: 0.125, alpha: 1)
    )
    static let accent = adaptive(
        light: UIColor(red: 0.20, green: 0.37, blue: 0.29, alpha: 1),
        dark: UIColor(red: 0.62, green: 0.79, blue: 0.68, alpha: 1)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

private struct PlannerIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.body.weight(.medium))
            .foregroundStyle(PlannerStyle.accent)
            .frame(width: 28, height: 36)
            .accessibilityHidden(true)
    }
}

private struct PlannerEmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    var actionTitle: String? = nil
    var action: () -> Void = {}
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.tertiary).accessibilityHidden(true)
            VStack(spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            if let actionTitle {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }.buttonStyle(.borderless)
            }
        }.multilineTextAlignment(.center).padding(.vertical, 24)
            .frame(maxWidth: .infinity)
    }
}

private struct PlannerEmptyOverlay<EmptyContent: View>: ViewModifier {
    let isPresented: Bool
    @ViewBuilder var emptyContent: () -> EmptyContent

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                GeometryReader { geometry in
                    ScrollView {
                        emptyContent()
                            .padding(.horizontal, 24)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: geometry.size.height)
                    }.scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
                        .background(PlannerStyle.canvas)
                }
            }
        }
    }
}

@MainActor
struct AppShellView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("daymark.appearance") private var appearance = "System"
    @State private var selectedTab = 0
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    var body: some View {
        @Bindable var model = model
        TabView(selection: $selectedTab) {
            NavigationStack { PlannerDayView() }
                .tabItem { Label("Day", systemImage: selectedTab == 0 ? "house.fill" : "house").environment(\.symbolVariants, .none) }.tag(0)
            NavigationStack { PlannerRoutinesView() }
                .tabItem { Label("Routines", systemImage: selectedTab == 1 ? "repeat.circle.fill" : "repeat.circle").environment(\.symbolVariants, .none) }.tag(1)
            NavigationStack { PlannerNotesView() }
                .tabItem { Label("Notes", systemImage: selectedTab == 2 ? "doc.text.fill" : "doc.text").environment(\.symbolVariants, .none) }.tag(2)
            NavigationStack { PlannerProfileView() }
                .tabItem { Label("Profile", systemImage: selectedTab == 3 ? "person.crop.circle.fill" : "person.crop.circle").environment(\.symbolVariants, .none) }.tag(3)
        }
        .tint(PlannerStyle.accent)
        .preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
        .onReceive(clock) { _ in model.refreshDay() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refreshDay(); model.prepareSelectedDay() }
        }
        .fullScreenCover(isPresented: $model.isRunnerPresented) { PlannerSavedRoutineRun().environment(model) }
    }
}

private struct PlannerListLayout: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            .listRowBackground(PlannerStyle.surface)
            .listSectionSeparator(.hidden)
            .scrollContentBackground(.hidden)
            .background(PlannerStyle.canvas)
            .tint(PlannerStyle.accent)
            .toolbarBackground(PlannerStyle.canvas, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlannerFormLayout: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(PlannerStyle.surface)
            .scrollContentBackground(.hidden)
            .background(PlannerStyle.canvas)
            .tint(PlannerStyle.accent)
            .toolbarBackground(PlannerStyle.canvas, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlannerSectionTitle: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline).foregroundStyle(.primary).fixedSize()
                Spacer(minLength: 12)
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize() }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.primary)
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
        }.textCase(nil).padding(.bottom, 6)
    }
}

@MainActor
private struct PlannerDateBar: View {
    var showsWeek = false
    @Environment(AppModel.self) private var model
    @State private var choosesDate = false
    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { dateButton.fixedSize(horizontal: true, vertical: false); Spacer(minLength: 0); navigationButtons }
                VStack(alignment: .leading, spacing: 8) {
                    dateButton
                    HStack { Spacer(); navigationButtons }
                }
            }
            if showsWeek {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) { weekDays }.frame(maxWidth: .infinity)
                    ScrollView(.horizontal) { HStack(spacing: 4) { weekDays } }.scrollIndicators(.hidden)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, showsWeek ? 16 : 10)
        .background(PlannerStyle.canvas)
        .sheet(isPresented: $choosesDate) {
            NavigationStack {
                Form {
                    DatePicker("Date", selection: $model.selectedPlanDate, displayedComponents: .date).datePickerStyle(.graphical)
                    Button("Go to today") { model.selectedPlanDate = Date(); choosesDate = false }
                }.modifier(PlannerFormLayout()).navigationTitle("Choose date")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { choosesDate = false } } }
            }.presentationDetents([.medium, .large])
        }
        .onChange(of: model.selectedPlanDay) { _, _ in model.prepareSelectedDay() }
    }
    private var dateButton: some View {
        Button { choosesDate = true } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.selectedPlanDay == model.plannerToday ? "Today" : model.selectedPlanDate.formatted(.dateTime.weekday(.wide)))
                        .font(showsWeek ? .title2.weight(.semibold) : .headline).foregroundStyle(.primary)
                    Text(model.selectedPlanDate.formatted(.dateTime.month(.wide).day().year()))
                        .font(showsWeek ? .subheadline : .caption).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }.frame(minHeight: 44, alignment: .leading)
        }.buttonStyle(.plain).accessibilityHint("Choose another date")
    }
    private var navigationButtons: some View {
        HStack(spacing: 0) {
            if showsWeek && model.selectedPlanDay != model.plannerToday {
                Button("Today") { model.selectedPlanDate = Date() }
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44).padding(.horizontal, 8)
            }
            Button { model.moveSelectedDate(showsWeek ? -7 : -1) } label: {
                Image(systemName: "chevron.left").font(.subheadline.weight(.semibold)).frame(width: 44, height: 44)
            }.accessibilityLabel(showsWeek ? "Previous week" : "Previous day")
            Button { model.moveSelectedDate(showsWeek ? 7 : 1) } label: {
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).frame(width: 44, height: 44)
            }.accessibilityLabel(showsWeek ? "Next week" : "Next day")
        }.background(PlannerStyle.surface, in: RoundedRectangle(cornerRadius: 14))
    }
    private var weekDates: [Date] {
        let start = model.calendar.dateInterval(of: .weekOfYear, for: model.selectedPlanDate)?.start ?? model.selectedPlanDate
        return (0..<7).compactMap { model.calendar.date(byAdding: .day, value: $0, to: start) }
    }
    private var weekDays: some View {
        ForEach(weekDates, id: \.self) { date in
            let day = LocalDay(date: date, calendar: model.calendar)
            let selected = day == model.selectedPlanDay
            Button { model.selectedPlanDate = date } label: {
                VStack(spacing: 6) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("\(day.day)").font(.body.weight(selected ? .semibold : .regular))
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 44, minHeight: 44)
                        .foregroundStyle(selected ? PlannerStyle.canvas : Color.primary)
                        .background(selected ? PlannerStyle.accent : Color.clear, in: Circle())
                        .overlay { if day == model.plannerToday && !selected { Circle().strokeBorder(PlannerStyle.accent.opacity(0.4)) } }
                }.frame(minWidth: 44)
            }.buttonStyle(.plain).accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                .accessibilityValue(selected ? "Selected" : "")
        }
    }
}

@MainActor
private struct PlannerDayView: View {
    @Environment(AppModel.self) private var model
    @State private var addsTask = false
    @State private var addsRoutine = false
    @State private var showsAddOptions = false
    @State private var editing: PlanOccurrence?
    @State private var error: String?
    private var open: [PlanOccurrence] { model.selectedPlan.filter { [.pending, .partial].contains($0.status) } }
    private var scheduled: [PlanOccurrence] { open.filter { $0.minute != nil } }
    private var anytime: [PlanOccurrence] { open.filter { $0.minute == nil } }
    private var completed: [PlanOccurrence] { model.selectedPlan.filter { $0.status == .completed } }
    private var other: [PlanOccurrence] { model.selectedPlan.filter { [.skipped, .moved].contains($0.status) } }
    private var notes: [DayNote] { model.state.dayNotes.filter { $0.day == model.selectedPlanDay && !$0.isArchived } }
    private var showsEmptyPage: Bool {
        model.selectedPlan.isEmpty && notes.isEmpty && model.state.activeRoutine == nil && !model.localDataNeedsRecovery
    }
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist").font(.title2).foregroundStyle(PlannerStyle.accent).accessibilityHidden(true)
            VStack(spacing: 6) {
                Text("Plan this day").font(.title3.weight(.semibold))
                Text("Add a task, or use one of your routines.").font(.subheadline).foregroundStyle(.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) { emptyActions }
                VStack(spacing: 4) { emptyActions }
            }
        }.multilineTextAlignment(.center).padding(.vertical, 24)
    }
    private var emptyActions: some View {
        Group {
            Button { addsTask = true } label: { Label("Add task", systemImage: "plus").frame(minHeight: 44) }
            Button { addsRoutine = true } label: { Label("Add routine", systemImage: "repeat").frame(minHeight: 44) }
        }.font(.subheadline.weight(.medium)).buttonStyle(.borderless)
    }
    private var dayList: some View {
        List {
            if model.localDataNeedsRecovery {
                Section { Text("Your local save needs recovery. Changes are disabled to protect your records.").foregroundStyle(.red) }
            }
            if model.state.activeRoutine != nil {
                Section {
                    Button { model.resumeRoutine() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.activeRoutine?.title ?? "Saved routine").font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text("Continue where you left off").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.frame(minHeight: 44)
                    }.buttonStyle(.plain)
                }
            }
            taskSection(scheduled, title: "Scheduled")
            taskSection(anytime, title: "Any time")
            taskSection(completed, title: "Completed")
            taskSection(other, title: "Skipped & moved")
            if !notes.isEmpty {
                Section {
                    ForEach(notes) { note in
                        NavigationLink { PlannerNoteEditor(note: note) } label: {
                            HStack(spacing: 12) {
                                PlannerIcon(symbol: "doc.text")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.displayTitle).font(.body.weight(.medium))
                                    if !note.body.isEmpty { Text(note.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
                                }
                            }.frame(minHeight: 44)
                        }
                    }
                } header: { PlannerSectionTitle(title: "Notes", detail: "\(notes.count)") }
            }
        }
        .modifier(PlannerListLayout())
        .modifier(PlannerEmptyOverlay(isPresented: showsEmptyPage) { emptyState })
    }
    var body: some View {
        VStack(spacing: 0) {
            PlannerDateBar(showsWeek: true)
            Divider().padding(.horizontal, 20)
            dayList
        }
        .background(PlannerStyle.canvas).navigationTitle("Day")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsAddOptions = true } label: { Label("Add", systemImage: "plus").font(.subheadline.weight(.medium)) }
                    .accessibilityLabel("Add to this day")
            }
        }
        .confirmationDialog("Add to this day", isPresented: $showsAddOptions, titleVisibility: .visible) {
            Button("Add task") { addsTask = true }
            Button("Add routine") { addsRoutine = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $addsTask) { PlannerTaskEditor(day: model.selectedPlanDay) }
        .sheet(isPresented: $addsRoutine) { PlannerRoutinePicker() }
        .sheet(item: $editing) { PlannerTaskEditor(day: $0.day, occurrence: $0) }
        .task { model.prepareSelectedDay() }
        .alert("Could not save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
    @ViewBuilder
    private func taskSection(_ tasks: [PlanOccurrence], title: String) -> some View {
        if !tasks.isEmpty {
            Section { ForEach(tasks) { taskRow($0) } }
            header: { PlannerSectionTitle(title: title, detail: "\(tasks.count)") }
        }
    }
    private func taskRow(_ task: PlanOccurrence) -> some View {
        HStack(spacing: 12) {
            Button {
                var changed = task; changed.status = task.status == .completed ? .pending : .completed
                changed.steps = task.steps.map { PlanStep(id: $0.id, title: $0.title, isDone: changed.status == .completed, notes: $0.notes) }
                do { try model.updateOccurrence(changed) } catch { self.error = error.localizedDescription }
            } label: {
                Image(systemName: completionSymbol(task.status))
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(task.status == .pending ? Color.secondary : PlannerStyle.accent)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.borderless).disabled(task.status == .moved)
                .accessibilityLabel(task.status == .completed ? "Undo \(task.title)" : "Complete \(task.title)")
            Button { editing = task } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.body.weight(.medium))
                        .foregroundStyle(task.status == .completed ? Color.secondary : Color.primary)
                        .strikethrough(task.status == .completed)
                        .fixedSize(horizontal: false, vertical: true)
                    if let minute = task.minute { Label(plannerTime(minute), systemImage: "clock").font(.caption).foregroundStyle(.secondary) }
                    if !task.steps.isEmpty {
                        Label("\(task.steps.filter(\.isDone).count) of \(task.steps.count) steps", systemImage: "checklist")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if task.status == .partial { Text("Partly done").font(.caption).foregroundStyle(.secondary) }
                    if task.status == .skipped { Text("Skipped").font(.caption).foregroundStyle(.secondary) }
                    if let day = task.movedTo { Text(verbatim: "Moved to \(day.month)/\(day.day)/\(day.year)").font(.caption).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).accessibilityHidden(true)
        }
    }
    private func completionSymbol(_ status: PlanStatus) -> String {
        switch status {
        case .completed: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .skipped: "minus.circle"
        case .moved: "arrow.right.circle"
        case .pending: "circle"
        }
    }
}

private func plannerTime(_ minute: Int) -> String {
    (Calendar.current.date(from: DateComponents(hour: minute / 60, minute: minute % 60)) ?? Date()).formatted(date: .omitted, time: .shortened)
}

private func plannerScheduleSummary(weekdays: Set<Int>?, minute: Int?) -> String {
    let frequency: String
    if let weekdays {
        frequency = weekdays.count == 7 ? "Every day" : weekdays.isEmpty ? "Choose weekdays" :
            weekdays.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
    } else { frequency = "Once" }
    return "\(frequency) · \(minute.map(plannerTime) ?? "Any time")"
}

private struct PlannerScheduleFields: View {
    @Binding var repeats: Bool
    @Binding var weekdays: Set<Int>
    @Binding var timed: Bool
    @Binding var time: Date
    @Binding var date: Date
    var allowsDateChange = true
    var allowsRepetition = true
    private var minute: Int? {
        guard timed else { return nil }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
    var body: some View {
        if allowsRepetition {
            Picker("Frequency", selection: $repeats) {
                Text("Once").tag(false)
                Text("Repeat").tag(true)
            }.pickerStyle(.segmented)
        }
        if allowsDateChange {
            DatePicker(repeats ? "Starts on" : "Date", selection: $date, displayedComponents: .date)
        }
        if allowsRepetition && repeats {
            Button {
                weekdays = Set(1...7)
            } label: {
                HStack {
                    Text("Every day").foregroundStyle(.primary)
                    Spacer()
                    if weekdays.count == 7 { Image(systemName: "checkmark") }
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.accessibilityAddTraits(weekdays.count == 7 ? .isSelected : [])
            PlannerWeekdays(days: $weekdays)
        }
        Toggle("Set a start time", isOn: $timed)
        if timed { DatePicker("Start time", selection: $time, displayedComponents: .hourAndMinute) }
        if allowsRepetition {
            Text(plannerScheduleSummary(weekdays: repeats ? weekdays : nil, minute: minute))
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct PlannerWeekdays: View {
    @Binding var days: Set<Int>
    var body: some View {
        ForEach(1...7, id: \.self) { day in
            Button {
                if days.contains(day) { days.remove(day) } else { days.insert(day) }
            } label: {
                HStack {
                    Text(Calendar.current.weekdaySymbols[day - 1]).foregroundStyle(.primary)
                    Spacer(); if days.contains(day) { Image(systemName: "checkmark") }
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.accessibilityAddTraits(days.contains(day) ? .isSelected : [])
        }
    }
}

@MainActor
private struct PlannerTaskEditor: View {
    let day: LocalDay
    let occurrence: PlanOccurrence?
    let series: PlanTask?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var timed: Bool
    @State private var time: Date
    @State private var repeats: Bool
    @State private var weekdays: Set<Int>
    @State private var date: Date
    @State private var steps: [PlanStep]
    @State private var newStep = ""
    @State private var status: PlanStatus
    @State private var error: String?
    @State private var discards = false
    @State private var moves = false
    @State private var moveDate = Date().addingTimeInterval(86400)
    @State private var removes = false
    @State private var draftID = UUID()
    init(day: LocalDay, occurrence: PlanOccurrence? = nil, series: PlanTask? = nil) {
        self.day = day; self.occurrence = occurrence; self.series = series
        _title = State(initialValue: occurrence?.title ?? series?.title ?? "")
        _notes = State(initialValue: occurrence?.notes ?? series?.notes ?? "")
        let minute = occurrence?.minute ?? series?.minute
        _timed = State(initialValue: minute != nil)
        _time = State(initialValue: Calendar.current.date(from: DateComponents(hour: (minute ?? 540) / 60, minute: (minute ?? 540) % 60)) ?? Date())
        _repeats = State(initialValue: series?.weekdays != nil)
        _weekdays = State(initialValue: series?.weekdays ?? Set(1...7))
        _date = State(initialValue: Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)) ?? Date())
        _steps = State(initialValue: occurrence?.steps ?? series?.steps ?? [])
        _status = State(initialValue: occurrence?.status ?? .pending)
    }
    private var minute: Int? {
        guard timed else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    private var dirty: Bool {
        title != (occurrence?.title ?? series?.title ?? "") || notes != (occurrence?.notes ?? series?.notes ?? "")
            || steps != (occurrence?.steps ?? series?.steps ?? []) || status != (occurrence?.status ?? .pending)
            || minute != (occurrence?.minute ?? series?.minute) || repeats != (series?.weekdays != nil)
            || (repeats && weekdays != (series?.weekdays ?? Set(1...7))) || !newStep.isEmpty
            || (occurrence == nil && series == nil && LocalDay(date: date, calendar: model.calendar) != day)
    }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 200
            && (!repeats || !weekdays.isEmpty) && notes.count <= 20000 && occurrence?.status != .moved
            && newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task name", text: $title).accessibilityLabel("Task name")
                }
                Section {
                    PlannerScheduleFields(repeats: $repeats, weekdays: $weekdays, timed: $timed, time: $time, date: $date,
                        allowsDateChange: occurrence == nil && series == nil, allowsRepetition: occurrence == nil)
                } header: { Text("Schedule") } footer: {
                    Text(series == nil ? "A planning time, not a reminder. Each date keeps its own progress." : "Changes apply from the selected date or today, whichever is later. Saved checklists stay unchanged. Times don't send reminders.")
                }
                Section("Steps (optional)") {
                    ForEach($steps) { $step in
                        HStack {
                            if occurrence != nil {
                                Button {
                                    step.isDone.toggle()
                                    status = steps.allSatisfy(\.isDone) ? .completed : steps.contains(where: \.isDone) ? .partial : .pending
                                } label: {
                                    Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 26, weight: .light)).frame(width: 44, height: 44).contentShape(Rectangle())
                                }
                                    .buttonStyle(.borderless).accessibilityLabel("Toggle \(step.title)")
                                    .disabled(status == .moved)
                            }
                            VStack(alignment: .leading) {
                                TextField("Step", text: $step.title)
                                if let note = step.notes, !note.isEmpty { Text(note).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }.onDelete { steps.remove(atOffsets: $0) }.onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    HStack {
                        TextField("New step", text: $newStep).onSubmit { appendStep() }
                        Button("Add") { appendStep() }.disabled(newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if !newStep.isEmpty { Text("Tap Add to include this step before saving.").font(.caption).foregroundStyle(.secondary) }
                }
                Section("Notes") {
                    TextField("Task notes (optional)", text: $notes, axis: .vertical).lineLimit(3...8)
                }
                if let occurrence {
                    Section {
                        Picker("Status", selection: $status) {
                            Text("To do").tag(PlanStatus.pending); Text("Done").tag(PlanStatus.completed)
                            Text("Partly done").tag(PlanStatus.partial); Text("Skipped").tag(PlanStatus.skipped)
                            if occurrence.status == .moved { Text("Moved").tag(PlanStatus.moved) }
                        }.pickerStyle(.navigationLink).disabled(occurrence.status == .moved)
                        if occurrence.status != .moved {
                            Button("Move to another date") { moves = true }
                            Button("Remove from this day", role: .destructive) { removes = true }
                        }
                    } footer: { Text("Changes apply only to this date, not the repeating template.") }
                }
                if let series, series.weekdays != nil {
                    Section {
                        Button("Stop repeating after this date", role: .destructive) {
                            var changed = series; changed.endsOn = max(series.startsOn, model.selectedPlanDay)
                            do { try model.saveTask(changed); dismiss() } catch { self.error = error.localizedDescription }
                        }
                    } footer: { Text("Past records and already saved dates remain in your plan.") }
                }
                if let error { Section { Text(error).foregroundStyle(.red).textSelection(.enabled) } }
            }
            .modifier(PlannerFormLayout())
            .navigationTitle(occurrence != nil ? "Task details" : series != nil ? "Repeating task" : "New task").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { discards = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.fontWeight(.semibold).disabled(!canSave || model.localDataNeedsRecovery) }
                if !steps.isEmpty { ToolbarItem(placement: .bottomBar) { EditButton() } }
            }
            .confirmationDialog("Discard unsaved changes?", isPresented: $discards, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
            }
            .confirmationDialog("Remove this task from this date?", isPresented: $removes, titleVisibility: .visible) {
                Button("Remove from day", role: .destructive) {
                    guard var changed = occurrence else { return }; changed.isRemoved = true
                    do { try model.updateOccurrence(changed); dismiss() } catch { self.error = error.localizedDescription }
                }
            } message: { Text("Other dates stay unchanged. Restore it from Removed tasks in Settings.") }
            .sheet(isPresented: $moves) {
                NavigationStack {
                    Form { DatePicker("Move to", selection: $moveDate, displayedComponents: .date) }
                    .modifier(PlannerFormLayout())
                    .navigationTitle("Move task").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { moves = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Move") {
                                guard var changed = occurrence else { return }
                                changed.title = title; changed.notes = notes; changed.minute = minute; changed.steps = steps
                                do { try model.moveTask(changed, to: moveDate); moves = false; dismiss() }
                                catch { self.error = error.localizedDescription; moves = false }
                            }
                        }
                    }
                }.presentationDetents([.medium])
            }
        }.interactiveDismissDisabled(dirty)
    }
    private func appendStep() {
        let name = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 200 else { return }
        steps.append(PlanStep(title: name)); newStep = ""
    }
    private func save() {
        do {
            if var changed = occurrence {
                changed.title = title.trimmingCharacters(in: .whitespacesAndNewlines); changed.notes = notes
                changed.minute = minute; changed.steps = steps; changed.status = status
                if status == .completed { changed.steps = steps.map { PlanStep(id: $0.id, title: $0.title, isDone: true, notes: $0.notes) } }
                try model.updateOccurrence(changed)
            } else {
                let task = PlanTask(id: series?.id ?? draftID, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes, startsOn: series?.startsOn ?? LocalDay(date: date, calendar: model.calendar), endsOn: series?.endsOn, minute: minute,
                    weekdays: repeats ? weekdays : nil, steps: steps, routineID: series?.routineID)
                if series != nil && dirty { try model.editRepeatingTask(task) }
                else if series == nil { try model.saveTask(task) }
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

@MainActor
private struct PlannerRoutinesView: View {
    @Environment(AppModel.self) private var model
    @State private var creates = false
    @State private var editing: Routine?
    @State private var series: PlanTask?
    @State private var query = ""
    private var visibleRoutines: [Routine] {
        model.activeRoutines.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }
    private var repeatingTasks: [PlanTask] {
        model.state.planTasks.filter { !$0.isArchived && $0.weekdays != nil && ($0.endsOn.map { $0 >= model.plannerToday } ?? true) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }
    }
    private var emptyState: some View {
        PlannerEmptyState(symbol: "repeat", title: query.isEmpty ? "No routines yet" : "No matching routines",
            detail: query.isEmpty ? "Create a checklist to use again." : "Try a different name.",
            actionTitle: query.isEmpty ? "Create routine" : nil) { creates = true }
    }
    var body: some View {
        List {
            Section {
                ForEach(visibleRoutines) { routine in
                    Button { editing = routine } label: {
                        HStack(spacing: 12) {
                            PlannerIcon(symbol: "repeat")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routine.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                                Text(routine.leafSteps.count == 1 ? "1 step" : "\(routine.leafSteps.count) steps").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.frame(minHeight: 44)
                    }.buttonStyle(.plain)
                }
            } header: {
                if !visibleRoutines.isEmpty { PlannerSectionTitle(title: "Your routines", detail: "\(visibleRoutines.count)") }
            }.listRowBackground(visibleRoutines.isEmpty ? Color.clear : PlannerStyle.surface)
            if !repeatingTasks.isEmpty {
              Section {
                ForEach(repeatingTasks) { task in
                    Button { series = task } label: {
                        HStack(spacing: 12) {
                            PlannerIcon(symbol: "calendar.badge.clock")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                                Text(plannerScheduleSummary(weekdays: task.weekdays, minute: task.minute)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.frame(minHeight: 44)
                    }.buttonStyle(.plain)
                }
              } header: { PlannerSectionTitle(title: "Repeating plans", detail: "\(repeatingTasks.count)") }
            }
        }
        .modifier(PlannerListLayout())
        .modifier(PlannerEmptyOverlay(isPresented: visibleRoutines.isEmpty && repeatingTasks.isEmpty) { emptyState })
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search routines")
        .navigationTitle("Routines")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creates = true } label: { Image(systemName: "plus").fontWeight(.semibold) }.accessibilityLabel("Add routine")
            }
        }
        .sheet(isPresented: $creates) { PlannerRoutineEditor() }
        .sheet(item: $editing) { PlannerRoutineEditor(routine: $0) }
        .sheet(item: $series) { PlannerTaskEditor(day: model.selectedPlanDay, series: $0) }
    }
}

@MainActor
private struct PlannerRoutineEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let original: Routine?
    @State private var routine: Routine
    @State private var error: String?
    @State private var discards = false
    @State private var removes = false
    @State private var plansRoutine = false
    init(routine: Routine? = nil) { original = routine; _routine = State(initialValue: routine ?? Routine(title: "", steps: [])) }
    private var dirty: Bool { routine != (original ?? Routine(id: routine.id, title: "", steps: [])) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Routine name", text: $routine.title).accessibilityLabel("Routine name") }
                Section { PlannerRoutineItems(items: $routine.steps, depth: 0) }
                    header: { Text("Checklist") } footer: { Text("Steps belong to this routine. No habit linking or separate setup is needed.") }
                if original != nil {
                    Section {
                        Button {
                            plansRoutine = true
                        } label: { Label("Plan this routine", systemImage: "calendar.badge.plus").frame(minHeight: 44) }.disabled(dirty)
                        Button("Archive routine", role: .destructive) { removes = true }
                    } footer: { Text("Adding makes a checklist for the selected date. Template edits won't change saved daily checklists.") }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }.modifier(PlannerFormLayout()).navigationTitle(original == nil ? "New routine" : "Edit routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { discards = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try model.createRoutine(RoutineDraft(routine: routine), updating: original != nil); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.fontWeight(.semibold).disabled(routine.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || routine.steps.isEmpty)
                }
                if !routine.steps.isEmpty { ToolbarItem(placement: .bottomBar) { EditButton() } }
            }
            .confirmationDialog("Discard unsaved changes?", isPresented: $discards, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
            }
            .confirmationDialog("Archive this routine?", isPresented: $removes, titleVisibility: .visible) {
                Button("Archive", role: .destructive) { if let original { model.archiveRoutine(original); dismiss() } }
            } message: { Text("Daily checklists and progress are kept. Restore templates from Settings.") }
            .sheet(isPresented: $plansRoutine) {
                if let original {
                    PlannerAddRoutineForm(routine: original, date: model.selectedPlanDate) { dismiss() }
                }
            }
        }.interactiveDismissDisabled(dirty)
    }
}

private struct PlannerRoutineItems: View {
    @Binding var items: [RoutineStep]
    let depth: Int
    var body: some View {
        ForEach($items) { $step in
            NavigationLink {
                Form {
                    Section("Name") { TextField("Step name", text: $step.title) }
                    if step.children != nil {
                        Section("Steps") {
                            PlannerRoutineItems(items: Binding(get: { step.children ?? [] }, set: { step.children = $0 }), depth: depth + 1)
                        }
                    } else {
                        Section("Notes") { TextField("Optional notes", text: Binding(get: { step.notes ?? "" }, set: { step.notes = $0.isEmpty ? nil : $0 }), axis: .vertical) }
                    }
                    Section {
                        Toggle("Choose days for this step", isOn: Binding(get: { step.schedule != nil }, set: { step.schedule = $0 ? RoutineSchedule() : nil }))
                        if step.schedule != nil {
                            PlannerWeekdays(days: Binding(get: { step.schedule?.weekdays ?? Set(1...7) }, set: { step.schedule?.weekdays = $0 }))
                        }
                    } header: { Text("Availability") } footer: { Text("Leave off to include this step whenever the routine is planned. Choose days for different weekday checklists.") }
                }.modifier(PlannerFormLayout()).navigationTitle(step.children == nil ? "Step" : "Step group")
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title.isEmpty ? "Name this step" : step.title)
                    if let children = step.children { Text("\(children.count) steps").font(.caption).foregroundStyle(.secondary) }
                }.frame(minHeight: 44)
            }
        }.onDelete { items.remove(atOffsets: $0) }.onMove { items.move(fromOffsets: $0, toOffset: $1) }
        Button { items.append(RoutineStep(title: "")) } label: { Label("Add step", systemImage: "plus").frame(minHeight: 44) }
        if depth < 4 {
            Button { items.append(RoutineStep(title: "", children: [])) } label: { Label("Add step group", systemImage: "folder.badge.plus").frame(minHeight: 44) }
        }
    }
}

@MainActor
private struct PlannerRoutinePicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var creates = false
    @State private var selected: Routine?
    var body: some View {
        NavigationStack {
            List {
                ForEach(model.activeRoutines) { routine in
                    Button {
                        selected = routine
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(routine.title)
                        }.frame(minHeight: 44)
                    }
                }
                if !model.activeRoutines.isEmpty { Button("Create a routine") { creates = true } }
            }.modifier(PlannerListLayout()).navigationTitle("Add routine")
            .modifier(PlannerEmptyOverlay(isPresented: model.activeRoutines.isEmpty) {
                PlannerEmptyState(symbol: "repeat", title: "No routines yet", detail: "Create a checklist, then choose its schedule.",
                    actionTitle: "Create a routine") { creates = true }
            })
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(isPresented: $creates) { PlannerRoutineEditor() }
            .sheet(item: $selected) { routine in
                PlannerAddRoutineForm(routine: routine, date: model.selectedPlanDate) { dismiss() }
            }
        }
    }
}

@MainActor
private struct PlannerAddRoutineForm: View {
    let routine: Routine
    let added: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var repeats = false
    @State private var weekdays = Set(1...7)
    @State private var timed = false
    @State private var time = Calendar.current.date(from: DateComponents(hour: 9)) ?? Date()
    @State private var date: Date
    @State private var error: String?
    init(routine: Routine, date: Date, added: @escaping () -> Void) {
        self.routine = routine; self.added = added
        _date = State(initialValue: date)
    }
    private var minute: Int? {
        guard timed else { return nil }
        let components = model.calendar.dateComponents([.hour, .minute], from: time)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(routine.title).font(.headline)
                }
                Section {
                    PlannerScheduleFields(repeats: $repeats, weekdays: $weekdays, timed: $timed, time: $time, date: $date)
                } header: { Text("Schedule") } footer: {
                    Text("A planning time, not a reminder. Each date keeps its own checklist. Steps with weekday rules keep those rules.")
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.modifier(PlannerFormLayout()).navigationTitle("Plan routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        do {
                            try model.addRoutineToDay(routine, on: LocalDay(date: date, calendar: model.calendar),
                                minute: minute, weekdays: repeats ? weekdays : nil)
                            dismiss(); added()
                        }
                        catch { self.error = error.localizedDescription }
                    }.disabled(repeats && weekdays.isEmpty)
                }
            }
        }
    }
}

@MainActor
private struct PlannerNotesView: View {
    @Environment(AppModel.self) private var model
    @State private var creates = false
    @State private var query = ""
    private var notes: [DayNote] {
        model.state.dayNotes.filter { $0.day == model.selectedPlanDay && !$0.isArchived &&
            (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query)) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    private var noteList: some View {
        List {
            if !notes.isEmpty {
                Section {
                    ForEach(notes) { note in
                        NavigationLink { PlannerNoteEditor(note: note) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(note.displayTitle).font(.body.weight(.medium))
                                if !note.body.isEmpty { Text(note.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                                Label(note.updatedAt.formatted(date: .omitted, time: .shortened), systemImage: "doc.text")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                } header: { PlannerSectionTitle(title: "Day notes", detail: "\(notes.count)") }
            }
        }
        .modifier(PlannerListLayout())
        .modifier(PlannerEmptyOverlay(isPresented: notes.isEmpty) {
            PlannerEmptyState(symbol: "square.and.pencil", title: query.isEmpty ? "No notes for this day" : "No matching notes",
                detail: query.isEmpty ? "Write something you want to keep." : "Try a different search.",
                actionTitle: query.isEmpty ? "Write a note" : nil) { creates = true }
        })
    }
    var body: some View {
        VStack(spacing: 0) {
            PlannerDateBar()
            noteList
        }
        .background(PlannerStyle.canvas).navigationTitle("Notes")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search this day's notes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creates = true } label: { Image(systemName: "square.and.pencil").fontWeight(.semibold) }.accessibilityLabel("New note")
                }
        }
        .sheet(isPresented: $creates) { NavigationStack { PlannerNoteEditor(note: DayNote(day: model.selectedPlanDay)) } }
    }
}

@MainActor
private struct PlannerNoteEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var draft: DayNote
    @State private var expected: DayNote?
    @State private var error: String?
    @State private var trash = false
    @State private var initialized = false
    @State private var discards = false
    @State private var showsOptions = false
    init(note: DayNote) { _draft = State(initialValue: note) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(noteDate, systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
            TextField("Title (optional)", text: $draft.title, axis: .vertical)
                .font(.title2.weight(.semibold)).accessibilityLabel("Note title")
            Divider()
            ZStack(alignment: .topLeading) {
                if draft.body.isEmpty {
                    Text("What's on your mind?").foregroundStyle(.secondary)
                        .padding(.top, 8).padding(.leading, 5).allowsHitTesting(false).accessibilityHidden(true)
                }
                TextEditor(text: $draft.body).accessibilityLabel("Note text").scrollContentBackground(.hidden)
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red).textSelection(.enabled) }
            else {
                Label(expected == nil ? "Start writing to save this note." : model.cloudSync?.status ?? "Saved on this iPhone.",
                    systemImage: expected == nil ? "pencil" : "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(20).background(PlannerStyle.surface).tint(PlannerStyle.accent)
        .toolbarBackground(PlannerStyle.surface, for: .navigationBar)
        .navigationTitle("Note").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { save(); if error == nil { dismiss() } }.fontWeight(.semibold) }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsOptions = true } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Note options")
            }
        }
        .task { if !initialized { expected = model.state.dayNotes.first { $0.id == draft.id }; initialized = true } }
        .onChange(of: draft.title) { _, _ in save() }.onChange(of: draft.body) { _, _ in save() }
        .onChange(of: phase) { _, value in if value != .active { save() } }
        .onDisappear { if initialized && error == nil { save() } }.interactiveDismissDisabled(error != nil)
        .navigationBarBackButtonHidden(error != nil)
        .confirmationDialog("Note options", isPresented: $showsOptions, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { trash = true }
            if error != nil { Button("Close without saving", role: .destructive) { discards = true } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Move this note to Trash?", isPresented: $trash, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { draft.isArchived = true; save(); if error == nil { dismiss() } }
        } message: { Text("Restore it from Settings → Trash.") }
        .confirmationDialog("Close without saving your changes?", isPresented: $discards, titleVisibility: .visible) {
            Button("Close without saving", role: .destructive) { dismiss() }
        } message: { Text("Copy your text first if you want to keep it. The saved version remains unchanged.") }
    }
    private var noteDate: String {
        let date = Calendar.current.date(from: DateComponents(year: draft.day.year, month: draft.day.month, day: draft.day.day))
        return date?.formatted(date: .abbreviated, time: .omitted) ?? "Selected date"
    }
    private func save() {
        guard initialized else { return }
        if draft.title == expected?.title && draft.body == expected?.body && draft.isArchived == expected?.isArchived { return }
        draft.updatedAt = Date()
        do { try model.saveNote(draft, expected: expected); expected = model.state.dayNotes.first { $0.id == draft.id }; error = nil }
        catch { self.error = error.localizedDescription }
    }
}

@MainActor
private struct PlannerProfileAvatar: View {
    @Environment(AccountModel.self) private var account
    @AppStorage("daymark.profile-name") private var profileName = ""
    var size: CGFloat = 32
    private var name: String {
        let saved = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return saved.isEmpty && account.userID != nil ? (account.clerk?.user?.firstName ?? "") : saved
    }
    var body: some View {
        ZStack {
            Circle().fill(PlannerStyle.accent.opacity(0.12))
            if let initial = name.first {
                Text(String(initial).uppercased()).font(.system(size: size * 0.4, weight: .semibold))
            } else {
                Image(systemName: "person.fill").font(.system(size: size * 0.42, weight: .medium))
            }
        }
        .foregroundStyle(PlannerStyle.accent)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

@MainActor
private struct PlannerProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @AppStorage("daymark.profile-name") private var profileName = ""
    @State private var editsName = false
    @State private var draftName = ""
    @State private var managesAccount = false
    @State private var signOut = false
    @State private var conflicts = false
    @State private var accountTheme = BloomwardAccountTheme.make()
    private var displayName: String {
        let saved = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !saved.isEmpty { return saved }
        if account.userID != nil {
            let full = [account.clerk?.user?.firstName, account.clerk?.user?.lastName]
                .compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !full.isEmpty { return full }
        }
        return "Your profile"
    }
    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    PlannerProfileAvatar(size: 52)
                    Text(displayName).font(.title2.weight(.semibold))
                    Text(account.email ?? (account.userID == nil ? "Local profile" : "Signed in"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Edit name") { draftName = profileName; editsName = true }
                        .font(.subheadline).frame(minHeight: 44).buttonStyle(.borderless)
                }.frame(maxWidth: .infinity).padding(.vertical, 4)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }.listRowBackground(Color.clear)
            Section {
                if account.userID == nil {
                    Button {
                        account.requestLocalBackup(model.state); account.isLoginPresented = true
                    } label: { Label("Sign in", systemImage: "person.crop.circle") }
                } else {
                    Button { managesAccount = true } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Manage account")
                                Text("Security and account deletion").font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "person.crop.circle") }
                    }
                    Button(role: .destructive) { signOut = true } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right") }
                        .disabled(account.isBusy)
                }
            } header: { Text("Account") } footer: {
                if account.userID == nil { Text("Optional backup and sync. Local data is imported only with your permission.") }
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(account.userID == nil ? "On this iPhone" : "Cloud sync", systemImage: account.userID == nil ? "iphone" : "icloud")
                    if account.userID != nil { Text(model.cloudSync?.status ?? "Preparing cloud sync…")
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let sync = model.cloudSync, account.userID != nil {
                    Button(sync.conflicts.isEmpty ? "Sync now" : "Review sync conflict") {
                        if sync.conflicts.isEmpty { Task { await sync.syncNow() } } else { conflicts = true }
                    }.disabled(sync.isSyncing)
                }
            } header: { Text("Your data") } footer: {
                if account.userID == nil { Text("Not backed up. Deleting the app removes local data.") }
            }
            Section {
                NavigationLink { PlannerSettingsView() } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .modifier(PlannerListLayout())
        .navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
        .alert("Preferred name", isPresented: $editsName) {
            TextField("Name (optional)", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { profileName = String(draftName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)) }
        } message: { Text("Shown in Bloomward. This doesn't change your Apple or sign-in account name.") }
        .sheet(isPresented: $managesAccount) {
            if let clerk = account.clerk { UserProfileView().environment(clerk).environment(\.clerkTheme, accountTheme) }
        }
        .confirmationDialog("Sign out?", isPresented: $signOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await model.cloudSync?.syncNow(); await account.signOut() } }
        } message: { Text("Unsynced changes remain saved for this account on this iPhone. Guest data stays separate.") }
        .confirmationDialog("Choose a version for conflicting items", isPresented: $conflicts, titleVisibility: .visible) {
            Button("Use this iPhone") { model.cloudSync?.resolve(.thisDevice) }
            Button("Use cloud") { model.cloudSync?.resolve(.cloud) }
        } message: { Text(model.cloudSync?.conflicts.joined(separator: ", ") ?? "") }
    }
}

@MainActor
private struct PlannerSettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("daymark.appearance") private var appearance = "System"
    @AppStorage("daymark.haptics") private var haptics = true
    @State private var error: String?
    var body: some View {
        Form {
            Section("Preferences") {
                Picker("Appearance", selection: $appearance) {
                    Text("System").tag("System"); Text("Light").tag("Light"); Text("Dark").tag("Dark")
                }.pickerStyle(.navigationLink)
                Toggle("Haptic feedback", isOn: $haptics)
                Text("Dates follow your device's calendar day. Unfinished tasks stay on their original date until you move them.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Trash & archived items") {
                NavigationLink("Trash") {
                    List {
                        ForEach(model.state.dayNotes.filter(\.isArchived)) { note in
                            Button("Restore \(note.displayTitle)") {
                                var restored = note; restored.isArchived = false; restored.updatedAt = Date()
                                do { try model.saveNote(restored, expected: note) } catch { self.error = error.localizedDescription }
                            }
                        }
                    }.modifier(PlannerListLayout()).navigationTitle("Trash").navigationBarTitleDisplayMode(.inline)
                    .modifier(PlannerEmptyOverlay(isPresented: model.state.dayNotes.allSatisfy({ !$0.isArchived })) {
                        PlannerEmptyState(symbol: "trash", title: "Trash is empty", detail: "Notes you remove can be restored here.")
                    })
                }
                NavigationLink("Removed tasks") {
                    List {
                        ForEach(model.state.planOccurrences.filter(\.isRemoved)) { task in
                            Button("Restore \(task.title) · \(task.day.month)/\(task.day.day)") {
                                var restored = task; restored.isRemoved = false
                                do { try model.updateOccurrence(restored) } catch { self.error = error.localizedDescription }
                            }
                        }
                    }.modifier(PlannerListLayout()).navigationTitle("Removed tasks").navigationBarTitleDisplayMode(.inline)
                    .modifier(PlannerEmptyOverlay(isPresented: model.state.planOccurrences.allSatisfy({ !$0.isRemoved })) {
                        PlannerEmptyState(symbol: "checklist", title: "No removed tasks", detail: "Removed tasks can be restored here.")
                    })
                }
                NavigationLink("Archived routines") {
                    List {
                        ForEach(model.state.routines.filter(\.isArchived)) { routine in
                            Button("Restore \(routine.title)") {
                                do { try model.restorePlannerRoutine(routine) } catch { self.error = error.localizedDescription }
                            }
                        }
                    }.modifier(PlannerListLayout()).navigationTitle("Archived routines").navigationBarTitleDisplayMode(.inline)
                    .modifier(PlannerEmptyOverlay(isPresented: model.state.routines.allSatisfy({ !$0.isArchived })) {
                        PlannerEmptyState(symbol: "archivebox", title: "No archived routines", detail: "Archived checklists can be restored here.")
                    })
                }
            }
            Section("Previous records") {
                NavigationLink("Previous routine sessions") {
                    List {
                      ForEach(model.state.routineHistory.sorted { $0.endedAt > $1.endedAt }, id: \.startedAt) { run in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.state.routine(id: run.routineID)?.title ?? "Previous routine")
                            Text(run.endedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            Text("\(run.outcomes.filter { $0 == .completed }.count) of \(run.outcomes.count) steps completed").font(.caption).foregroundStyle(.secondary)
                        }
                      }
                    }.modifier(PlannerListLayout()).navigationTitle("Previous sessions").navigationBarTitleDisplayMode(.inline)
                    .modifier(PlannerEmptyOverlay(isPresented: model.state.routineHistory.isEmpty) {
                        PlannerEmptyState(symbol: "clock", title: "No previous sessions", detail: "Earlier routine sessions appear here.")
                    })
                }
            }
        }.modifier(PlannerFormLayout()).navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .alert("Could not restore", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
}

struct PlannerWelcomeView: View {
    let start: () -> Void
    let signIn: () -> Void
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Image("BloomwardLogo")
                            .resizable().scaledToFit().frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityHidden(true)
                        Text("Bloomward").font(.headline)
                    }
                    Spacer(minLength: 56)
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Your day,\nat your pace.").font(.largeTitle.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Plan what matters, build a rhythm, and keep your thoughts close.")
                            .font(.body).foregroundStyle(.secondary).lineSpacing(3)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 20) { welcomeCategories }
                            VStack(alignment: .leading, spacing: 12) { welcomeCategories }
                        }.padding(.top, 4)
                    }
                    Spacer(minLength: 64)
                    VStack(alignment: .leading, spacing: 16) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 24) { startButton; Spacer(minLength: 12); signInButton }
                            VStack(alignment: .leading, spacing: 8) { startButton; signInButton }
                        }
                        Text("No account required.\nStart on this iPhone. Sign in later to sync.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: 400, alignment: .leading).frame(minHeight: max(0, geometry.size.height - 48))
                    .padding(.horizontal, 28).padding(.vertical, 24).frame(maxWidth: .infinity)
            }.scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
        }.background(PlannerStyle.canvas).tint(PlannerStyle.accent)
    }
    private var welcomeCategories: some View {
        Group {
            Label("Tasks", systemImage: "checkmark.circle")
            Label("Routines", systemImage: "repeat")
            Label("Notes", systemImage: "doc.text")
        }.font(.subheadline).foregroundStyle(PlannerStyle.accent).fixedSize(horizontal: true, vertical: false)
    }
    private var startButton: some View {
        Button(action: start) {
            Text("Start planning").font(.body.weight(.semibold))
                .padding(.horizontal, 20).padding(.vertical, 12).frame(minHeight: 44)
                .foregroundStyle(PlannerStyle.canvas)
                .background(PlannerStyle.accent, in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }
    private var signInButton: some View {
        Button("Sign in", action: signIn).font(.subheadline.weight(.medium))
            .frame(minHeight: 44).buttonStyle(.plain).foregroundStyle(PlannerStyle.accent)
    }
}

@MainActor
struct PlannerLoginView: View {
    let continueLocally: () -> Void
    @Environment(AccountModel.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var email = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Keep your plan backed up").font(.title2.bold())
                    Text("Sign in to sync your tasks, routines, and notes. You can also keep using this iPhone without an account.").foregroundStyle(.secondary)
                }
                Section {
                    NativeAppleButton(action: {
                        Task {
                            let complete = await account.signInWithApple()
                            if complete || account.errorMessage == nil { account.endPresentation() }
                        }
                    }, isEnabled: !account.isBusy).frame(height: 50)
                    Button("Continue with email") { account.beginPresentation(); email = true }.frame(minHeight: 44)
                    if let error = account.errorMessage { Text(error).foregroundStyle(.red) }
                }
                Section {
                    Button("Continue on this iPhone") { account.endPresentation(); continueLocally() }.frame(minHeight: 44)
                    Text("Guest data and account data stay separate unless you explicitly choose to import. Local data is lost if you uninstall the app.").font(.footnote).foregroundStyle(.secondary)
                }
            }.modifier(PlannerListLayout()).navigationTitle("Account")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { account.endPresentation(); dismiss() }.disabled(account.isBusy) } }
            .sheet(isPresented: $email, onDismiss: { account.endPresentation() }) { AccountFlowView(signInOnly: false) }
        }.interactiveDismissDisabled(account.isBusy)
    }
}

@MainActor
private struct PlannerSavedRoutineRun: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        NavigationStack {
            List {
                if let step = model.currentStep {
                    Section("Current step") {
                        Text(step.title).font(.title2.weight(.semibold))
                        if let notes = step.notes { Text(notes).foregroundStyle(.secondary) }
                        if let deadline = model.currentStepDeadline {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                let remaining = max(0, Int(deadline.timeIntervalSince(context.date)))
                                Text("\(remaining / 60):\(String(format: "%02d", remaining % 60)) remaining").monospacedDigit()
                            }
                        }
                        Button("Complete step") { model.completeCurrentStep() }.buttonStyle(.borderedProminent)
                        Button("Skip step") { model.skipCurrentStep() }
                    }
                }
                Section("Saved checklist") {
                    ForEach(Array(model.runningSteps.enumerated()), id: \.element.id) { index, step in
                        let completed = model.state.activeRoutine?.outcomes.indices.contains(index) == true
                            && model.state.activeRoutine?.outcomes[index] == .completed
                        Label(step.title, systemImage: completed ? "checkmark.circle.fill" : "circle")
                    }
                }
            }.navigationTitle(model.activeRoutine?.title ?? "Saved routine").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Save & close") { model.deferRoutine() } } }
        }
    }
}
