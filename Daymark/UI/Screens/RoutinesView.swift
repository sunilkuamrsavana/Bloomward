import Foundation
import RoutineCore
import SwiftUI

@MainActor
struct RoutinesView: View {
    @Environment(AppModel.self) private var model
    @State private var filter = RoutineFilter.all
    @State private var isSearching = false
    @State private var query = ""
    @State private var activeRoutineNotice = false
    @State private var showsBuilder = false

    var body: some View {
        GeometryReader { layout in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    IllustratedLibraryHeader(title: "Routines", subtitle: "Small steps, in your own rhythm.",
                        topInset: layout.safeAreaInsets.top)
                    VStack(alignment: .leading, spacing: 12) {
                        IllustratedFilterBar(items: RoutineFilter.allCases, selection: $filter) { $0.rawValue }
                        HStack {
                            IllustratedSectionHeading(title: "Your routines")
                            if !model.activeRoutines.isEmpty {
                                Button {
                                    isSearching.toggle()
                                    if !isSearching { query = "" }
                                } label: {
                                    Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                                        .frame(width: 44, height: 44).background(.white.opacity(0.9), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isSearching ? "Close search" : "Search routines")
                            }
                        }
                        if isSearching {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                TextField("Search routines", text: $query)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                            }
                            .padding(16).background(.white.opacity(0.9), in: Capsule())
                        }
                        if filteredRoutines.isEmpty { emptyState }
                        else {
                            VStack(spacing: 10) {
                                ForEach(filteredRoutines) { routine in
                                    IllustratedRoutineCard(routine: routine, habits: model.activeHabits,
                                        isCurrent: model.activeRoutine?.id == routine.id,
                                        isAvailable: !routine.executionSteps(on: model.today).isEmpty) {
                                        if model.activeRoutine?.id == routine.id { model.resumeRoutine() }
                                        else if model.activeRoutine != nil { activeRoutineNotice = true }
                                        else { model.begin(routine) }
                                    }
                                }
                            }
                        }
                        if model.activeRoutines.isEmpty {
                            Text("A routine can contain simple steps and smaller routines. Habits are optional.")
                                .font(.footnote).foregroundStyle(IllustratedStyle.muted)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 24)
                }
            }
            .scrollIndicators(.hidden).ignoresSafeArea(edges: .top)
        }
        .background { IllustratedScreenBackdrop() }
        .foregroundStyle(IllustratedStyle.ink).tint(IllustratedStyle.green)
        .modifier(IllustratedLibraryActions(addLabel: "Add routine") {
            showsBuilder = true
        })
        .fullScreenCover(isPresented: $showsBuilder) {
            RoutineBuilderView().environment(model)
        }
        .onChange(of: model.activeRoutines.map(\.id)) { old, new in
            if !Set(new).subtracting(old).isEmpty {
                filter = .all
                query = ""
            }
        }
        .alert("A routine is already in progress", isPresented: $activeRoutineNotice) {
            Button("Continue current routine") { model.resumeRoutine() }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Finish your current routine before starting another. Your progress is saved.")
        }
    }

    private var emptyState: some View {
        IllustratedCard {
            VStack(spacing: 16) {
                Image(systemName: "sun.max")
                    .font(.system(size: 32, weight: .light)).foregroundStyle(IllustratedStyle.green)
                    .frame(width: 74, height: 74).background(IllustratedStyle.sand, in: Circle())
                    .accessibilityHidden(true)
                Text(model.activeRoutines.isEmpty ? "Your rhythm starts here" : "A little breathing room")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                Text(model.activeRoutines.isEmpty
                     ? "Start with a few steps. Add smaller routines whenever you need them."
                     : query.isEmpty ? "No routines in this view. Try All to see your library." : "No matching routines. Try another name.")
                    .font(.body).foregroundStyle(IllustratedStyle.muted)
                if model.activeRoutines.isEmpty {
                    Button {
                        showsBuilder = true
                    } label: {
                        Text("Create your first routine")
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(IllustratedPillButtonStyle())
                    .accessibilityIdentifier("routines.createFirst")
                } else if filter != .all {
                    Button("See all routines") { filter = .all }.buttonStyle(IllustratedPillButtonStyle())
                }
            }
            .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }

    private var filteredRoutines: [Routine] {
        model.activeRoutines.filter { routine in
            let matches: Bool
            switch filter {
            case .all: matches = true
            case .inProgress: matches = model.activeRoutine?.id == routine.id
            case .today:
                matches = !routine.executionSteps(on: model.today).isEmpty || model.activeRoutine?.id == routine.id ||
                    model.state.routineHistory.contains { $0.routineID == routine.id && $0.day == model.today }
            }
            return matches && (query.isEmpty || routine.title.localizedCaseInsensitiveContains(query))
        }
    }
}

private enum RoutineFilter: String, CaseIterable, Identifiable {
    case all = "All", today = "Today", inProgress = "In progress"
    var id: Self { self }
}

struct IllustratedRoutineCard: View {
    let routine: Routine
    let habits: [Habit]
    let isCurrent: Bool
    var completedSteps: Int? = nil
    var isAvailable = true
    let onStart: () -> Void
    @State private var showsSteps = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(AppModel.self) private var model

    private var stepCount: Int {
        if isCurrent, let run = model.state.activeRoutine, run.routineID == routine.id { return run.outcomes.count }
        return routine.leafSteps.count
    }

    private var artwork: String {
        routine.title.localizedCaseInsensitiveContains("evening") ? "EveningRoutineArt"
        : routine.title.localizedCaseInsensitiveContains("morning") ? "MorningRoutineArt" : "DeskRoutineArt"
    }
    private func habit(for step: RoutineStep) -> Habit? { habits.first { $0.id == step.habitID } }
    private var stepNames: String { routine.steps.map { habit(for: $0)?.title ?? $0.title }.joined(separator: " · ") }

    var body: some View {
        let arrangement = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
        arrangement {
            Button { showsSteps = true } label: {
                HStack(spacing: 12) {
                    if !typeSize.isAccessibilitySize {
                        Image(artwork).resizable().scaledToFill().frame(width: 52, height: 62)
                            .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.title)
                            .font(.system(.headline, design: .serif)).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        Text(completedSteps.map { "\($0) of \(stepCount) steps finished" }
                             ?? "\(stepCount) \(stepCount == 1 ? "step" : "steps") · \(isCurrent ? "In progress" : routine.schedule.summary)")
                            .font(.caption).foregroundStyle(IllustratedStyle.muted)
                        Text(stepNames).font(.caption).foregroundStyle(IllustratedStyle.green)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View \(routine.title)")
            .accessibilityValue("\(stepCount) \(stepCount == 1 ? "step" : "steps"): \(stepNames)")
            Button(action: onStart) {
                Text(isCurrent ? "Continue" : isAvailable ? "Start" : "Not today").font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white).padding(.horizontal, 14).frame(minHeight: 44)
                    .background(IllustratedStyle.button, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isCurrent && !isAvailable)
            .opacity(!isCurrent && !isAvailable ? 0.55 : 1)
            .accessibilityLabel("\(isCurrent ? "Continue" : isAvailable ? "Start" : "Not scheduled today") \(routine.title)")
        }
        .padding(14).background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 24))
        .sheet(isPresented: $showsSteps) {
            RoutineContentsView(routineID: routine.id)
        }
    }
}

@MainActor
private struct RoutineContentsView: View {
    let routineID: Routine.ID
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showsEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let routine = model.state.routine(id: routineID) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(routine.title).font(.system(.largeTitle, design: .serif, weight: .bold))
                        Label(routine.schedule.summary, systemImage: "calendar")
                            .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                        Text("Follow the steps in order. Sub-routines keep related steps together.")
                            .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                        ForEach(routine.steps) { step in RoutineOutlineItem(step: step) }
                    }.padding(22)
                }
            }
            .background { IllustratedScreenBackdrop() }.foregroundStyle(IllustratedStyle.ink)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Edit") { showsEditor = true } }
            }
            .fullScreenCover(isPresented: $showsEditor) {
                if let routine = model.state.routine(id: routineID) {
                    RoutineBuilderView(routine: routine).environment(model)
                }
            }
        }
        .tint(IllustratedStyle.green)
        .presentationDragIndicator(.visible)
    }
}

private struct RoutineOutlineItem: View {
    let step: RoutineStep
    var body: some View {
        AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: step.children == nil ? step.illustratedSymbol : "square.stack")
                        .foregroundStyle(IllustratedStyle.green).frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title).font(.headline)
                        Text(step.schedule.map { Optional($0).summary } ?? "With routine")
                            .font(.caption).foregroundStyle(IllustratedStyle.muted)
                        if step.habitID != nil {
                            Text("Also tracks your habit").font(.caption).foregroundStyle(IllustratedStyle.green)
                        }
                        if let notes = step.notes, !notes.isEmpty { Text(notes).font(.subheadline) }
                    }
                    Spacer(minLength: 0)
                }
                if let children = step.children {
                    ForEach(children) { child in RoutineOutlineItem(step: child) }
                        .padding(.leading, 12)
                }
            }
            .padding(14).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 22))
        )
    }
}

@MainActor
struct RoutineBuilderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RoutineDraft
    private let original: RoutineDraft
    private let isEditing: Bool
    @State private var confirmsDiscard = false
    @State private var validationMessage: String?

    init(routine: Routine? = nil) {
        let draft = routine.map(RoutineDraft.init(routine:)) ?? RoutineDraft()
        _draft = State(initialValue: draft)
        original = draft
        isEditing = routine != nil
    }

    private var canSave: Bool {
        let name = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 60 && !draft.steps.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "Your routine" : "New routine")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                        Text("Small steps. Your own rhythm.")
                            .foregroundStyle(IllustratedStyle.muted)
                    }
                    IllustratedCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Routine name").font(.caption).foregroundStyle(IllustratedStyle.muted)
                            TextField("e.g. Morning Flow", text: $draft.title)
                                .font(.title3).accessibilityLabel("Routine name")
                        }
                    }
                    RoutineScheduleEditor(schedule: $draft.schedule, isRoot: true)
                    IllustratedSectionHeading(title: "Your steps", detail: "In the order that suits you.")
                    RoutineItemsEditor(items: $draft.steps, depth: 0,
                                       usedHabitIDs: Set(draft.steps.flatMap(\.habitIDs)))
                    if let validationMessage {
                        Text(validationMessage).font(.callout).foregroundStyle(.red)
                            .accessibilityLabel("Could not save. \(validationMessage)")
                    }
                    if isEditing && model.activeRoutine?.id == draft.id {
                        Text("Your current run keeps its original steps. Changes apply the next time you start.")
                            .font(.footnote).foregroundStyle(IllustratedStyle.muted)
                    }
                }.padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { IllustratedScreenBackdrop() }
            .safeAreaInset(edge: .bottom) {
                IllustratedActionFooter(title: isEditing ? "Save Changes" : "Save Routine",
                                        symbol: "checkmark", enabled: canSave) {
                    do { try model.createRoutine(draft, updating: isEditing); dismiss() }
                    catch { validationMessage = error.localizedDescription }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if draft == original { dismiss() } else { confirmsDiscard = true }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .foregroundStyle(IllustratedStyle.ink).tint(IllustratedStyle.green)
        .interactiveDismissDisabled()
        .confirmationDialog("Discard your changes?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) { }
        } message: { Text("Your saved routines and habits won't change.") }
    }
}

/// The same editor is used at each level. Nested items stay in the parent draft until Save.
@MainActor
private struct RoutineItemsEditor: View {
    @Binding var items: [RoutineDraftStep]
    let depth: Int
    let usedHabitIDs: Set<Habit.ID>
    @Environment(AppModel.self) private var model
    @State private var editingItem: RoutineDraftStep?
    @State private var showsHabitPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                Text("Add an action, or group a few actions into a sub-routine. No habit setup needed.")
                    .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 22))
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 10) {
                    Text("\(index + 1)").font(.subheadline.weight(.medium))
                        .foregroundStyle(IllustratedStyle.green).frame(width: 30, height: 36)
                    Button { editingItem = item } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title(in: model.activeHabits)).font(.headline)
                            Text(item.children.map { "\($0.count) \($0.count == 1 ? "step" : "items") · " } ?? (item.habitIDs.isEmpty ? "" : "Tracks habit · "))
                                .font(.caption).foregroundStyle(IllustratedStyle.muted)
                                + Text(item.schedule.map { Optional($0).summary } ?? "With routine")
                                .font(.caption).foregroundStyle(IllustratedStyle.muted)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                    Menu {
                        Button("Edit", systemImage: "pencil") { editingItem = item }
                        Button("Move up", systemImage: "arrow.up") { items.swapAt(index, index - 1) }.disabled(index == 0)
                        Button("Move down", systemImage: "arrow.down") { items.swapAt(index, index + 1) }.disabled(index == items.count - 1)
                        Button("Remove", systemImage: "minus.circle", role: .destructive) { items.removeAll { $0.id == item.id } }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    }.accessibilityLabel("Options for \(item.title(in: model.activeHabits))")
                }
                .padding(10).background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { addActions }
                VStack(alignment: .leading, spacing: 10) { addActions }
            }.padding(.top, 4)
            Button {
                showsHabitPicker = true
            } label: {
                Label("Use an existing habit", systemImage: "leaf")
                    .font(.subheadline).frame(minHeight: 44)
            }
            .buttonStyle(.plain).foregroundStyle(IllustratedStyle.green)
            .accessibilityHint("Optional. Completing this step also checks off that habit.")
        }
        .sheet(item: $editingItem) { item in
            RoutineItemEditor(item: item, depth: depth, usedHabitIDs: usedHabitIDs) { saved in
                if let index = items.firstIndex(where: { $0.id == saved.id }) { items[index] = saved }
                else { items.append(saved) }
            }.environment(model)
        }
        .sheet(isPresented: $showsHabitPicker) {
            RoutineHabitPicker(alreadySelected: usedHabitIDs.union(items.flatMap(\.habitIDs))) { habits in
                items.append(contentsOf: habits.map { RoutineDraftStep(source: .existing($0.id)) })
            }.environment(model)
        }
    }

    @ViewBuilder private var addActions: some View {
        Button { editingItem = RoutineDraftStep(source: .action("")) } label: {
            Label("Add step", systemImage: "plus").font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16).frame(minHeight: 46)
                .background(IllustratedStyle.sage, in: Capsule())
        }.buttonStyle(.plain).accessibilityIdentifier("routine.addStep")
        if depth < 4 {
            Button { editingItem = RoutineDraftStep(source: .group("", [])) } label: {
                Label("Add sub-routine", systemImage: "square.stack").font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16).frame(minHeight: 46)
                    .background(.white.opacity(0.92), in: Capsule())
                    .overlay(Capsule().stroke(IllustratedStyle.green.opacity(0.2), lineWidth: 1))
            }.buttonStyle(.plain).accessibilityIdentifier("routine.addGroup")
        }
    }
}

@MainActor
private struct RoutineItemEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var item: RoutineDraftStep
    @State private var confirmsDiscard = false
    private let original: RoutineDraftStep
    let depth: Int
    let usedHabitIDs: Set<Habit.ID>
    let onSave: (RoutineDraftStep) -> Void

    init(item: RoutineDraftStep, depth: Int, usedHabitIDs: Set<Habit.ID>, onSave: @escaping (RoutineDraftStep) -> Void) {
        _item = State(initialValue: item)
        original = item
        self.depth = depth
        self.usedHabitIDs = usedHabitIDs
        self.onSave = onSave
    }
    private var isGroup: Bool { item.children != nil }
    private var title: Binding<String> {
        Binding(get: { item.title(in: model.activeHabits) }, set: { title in
            if let children = item.children { item.source = .group(title, children) }
            else if item.habitIDs.isEmpty { item.source = .action(title) }
        })
    }
    private var children: Binding<[RoutineDraftStep]> {
        Binding(get: { item.children ?? [] }, set: { item.children = $0 })
    }
    private var valid: Bool {
        let name = title.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 60 && (!isGroup || !children.wrappedValue.isEmpty)
            && item.schedule?.isValid != false && (item.notes?.count ?? 0) <= 2000
    }

    var body: some View {
        AnyView(
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        IllustratedCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(isGroup ? "Sub-routine name" : "Step name")
                                    .font(.caption).foregroundStyle(IllustratedStyle.muted)
                                TextField(isGroup ? "e.g. Skincare" : "What would you like to do?", text: title)
                                    .font(.title3).disabled(!item.habitIDs.isEmpty && !isGroup)
                                    .accessibilityLabel(isGroup ? "Sub-routine name" : "Step name")
                                if !isGroup && !item.habitIDs.isEmpty {
                                    Text("Completing this step also checks off your existing habit. Rename the habit in your Habits library.")
                                        .font(.footnote).foregroundStyle(IllustratedStyle.muted)
                                }
                            }
                        }
                        RoutineScheduleEditor(schedule: $item.schedule, isRoot: false)
                        if isGroup {
                            IllustratedSectionHeading(title: "Inside this routine")
                            RoutineItemsEditor(items: children, depth: depth + 1,
                                               usedHabitIDs: usedHabitIDs.union(item.habitIDs))
                        } else {
                            IllustratedCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Toggle("Add a timer", isOn: Binding(get: { item.estimatedDurationSeconds != nil },
                                                                      set: { item.estimatedDurationSeconds = $0 ? 300 : nil }))
                                    if item.estimatedDurationSeconds != nil {
                                        Stepper("\((item.estimatedDurationSeconds ?? 300) / 60) minutes",
                                                value: Binding(get: { (item.estimatedDurationSeconds ?? 300) / 60 },
                                                               set: { item.estimatedDurationSeconds = $0 * 60 }), in: 1...1440)
                                    }
                                }
                            }
                        }
                        IllustratedCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes · Optional").font(.caption).foregroundStyle(IllustratedStyle.muted)
                                TextField("Any details that help you", text: Binding(get: { item.notes ?? "" }, set: { item.notes = $0 }),
                                          axis: .vertical).lineLimit(3...6).accessibilityLabel("Step notes")
                            }
                        }
                    }.padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                .background { IllustratedScreenBackdrop() }
                .navigationTitle(isGroup ? "Sub-routine" : "Step").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            if item == original { dismiss() } else { confirmsDiscard = true }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onSave(item); dismiss() }.disabled(!valid)
                    }
                }
            }
            .foregroundStyle(IllustratedStyle.ink).tint(IllustratedStyle.green)
            .interactiveDismissDisabled()
            .confirmationDialog("Discard changes to this item?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
        )
    }
}

private struct RoutineScheduleEditor: View {
    @Binding var schedule: RoutineSchedule?
    let isRoot: Bool
    private var days: Binding<Set<Int>> {
        Binding(get: { schedule?.weekdays ?? Set(1...7) }, set: { schedule?.weekdays = $0 })
    }
    private var time: Binding<Date> {
        Binding(get: {
            let minute = schedule?.startMinute ?? 540
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        }, set: {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
            schedule?.startMinute = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        })
    }
    var body: some View {
        IllustratedCard {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isRoot ? "Choose days" : "Choose different days", isOn: Binding(
                        get: { schedule != nil }, set: { schedule = $0 ? RoutineSchedule() : nil }))
                    if schedule != nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 3) {
                                ForEach(1...7, id: \.self) { weekday in
                                    Button {
                                        if days.wrappedValue.contains(weekday) { days.wrappedValue.remove(weekday) }
                                        else { days.wrappedValue.insert(weekday) }
                                    } label: {
                                        Text(Calendar.current.shortWeekdaySymbols[weekday - 1])
                                            .font(.caption.weight(.medium)).frame(minWidth: 44, minHeight: 44)
                                            .foregroundStyle(days.wrappedValue.contains(weekday) ? .white : IllustratedStyle.ink)
                                            .background(days.wrappedValue.contains(weekday) ? IllustratedStyle.green : IllustratedStyle.mist, in: Circle())
                                    }.buttonStyle(.plain)
                                    .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                                    .accessibilityAddTraits(days.wrappedValue.contains(weekday) ? .isSelected : [])
                                }
                            }
                        }
                        if days.wrappedValue.isEmpty { Text("Choose at least one day.").font(.footnote).foregroundStyle(.red) }
                        Toggle("Add a time", isOn: Binding(get: { schedule?.startMinute != nil },
                                                          set: { schedule?.startMinute = $0 ? 540 : nil }))
                        if schedule?.startMinute != nil {
                            DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                        }
                    }
                    Text(isRoot ? "Without a schedule, start this routine whenever you like. Times are planning cues, not reminders."
                         : "By default this follows its parent. Selected days apply only when the parent also runs. A time is a planning cue, not a reminder.")
                        .font(.footnote).foregroundStyle(IllustratedStyle.muted)
                }.padding(.top, 12)
            } label: {
                HStack {
                    Label("When", systemImage: "calendar")
                    Spacer()
                    Text(schedule.map { Optional($0).summary } ?? (isRoot ? "Anytime" : "With routine"))
                        .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                }
            }
        }
    }
}

private extension Optional where Wrapped == RoutineSchedule {
    var summary: String {
        guard let schedule = self else { return "Anytime" }
        let dayText = schedule.weekdays.count == 7 ? "Every day" : schedule.weekdays.sorted()
            .map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
        guard let minute = schedule.startMinute,
              let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) else { return dayText }
        return "\(dayText) · \(date.formatted(.dateTime.hour().minute()))"
    }
}

@MainActor
private struct RoutineHabitPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let alreadySelected: Set<Habit.ID>
    let onAdd: ([Habit]) -> Void
    @State private var selected: [Habit.ID] = []
    private var available: [Habit] {
        model.activeHabits.filter { $0.settings?.isPaused != true && !alreadySelected.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose habits").font(.system(.title2, design: .serif, weight: .semibold))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("Close habit picker")
            }.padding(.horizontal, 20).padding(.top, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reuse your habits without creating copies.")
                        .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                    if available.isEmpty {
                        IllustratedCard {
                            Text("No other active habits to reuse. You can add a regular step without creating a habit.")
                                .font(.body).foregroundStyle(IllustratedStyle.muted)
                        }
                    }
                    ForEach(available) { habit in
                        Button {
                            if selected.contains(habit.id) { selected.removeAll { $0 == habit.id } }
                            else { selected.append(habit.id) }
                        } label: {
                            IllustratedCard {
                                HStack(spacing: 12) {
                                    Image(systemName: habit.symbolName)
                                        .foregroundStyle(IllustratedStyle.green).frame(width: 28)
                                    Text(habit.title).font(.body).frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: selected.contains(habit.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2).foregroundStyle(IllustratedStyle.green)
                                }
                            }
                        }.buttonStyle(.plain)
                        .accessibilityAddTraits(selected.contains(habit.id) ? .isSelected : [])
                    }
                }.padding(20)
            }
            IllustratedActionFooter(title: selected.isEmpty ? "Add Habits" : "Add \(selected.count) \(selected.count == 1 ? "Habit" : "Habits")",
                                    symbol: "plus", enabled: !selected.isEmpty) {
                onAdd(selected.compactMap { id in available.first { $0.id == id } })
                dismiss()
            }
        }
        .background { IllustratedScreenBackdrop() }.foregroundStyle(IllustratedStyle.ink)
        .presentationDragIndicator(.visible)
    }
}

extension RoutineStep {
    var illustratedSymbol: String {
        let name = title.lowercased()
        if name.contains("meditat") || name.contains("breath") { return "leaf.fill" }
        if name.contains("stretch") || name.contains("move") { return "figure.flexibility" }
        if name.contains("water") { return "drop.fill" }
        if name.contains("read") { return "book" }
        if name.contains("desk") { return "sparkles" }
        if name.contains("phone") { return "moon.fill" }
        return "checklist"
    }

    var illustratedSubtitle: String {
        let name = title.lowercased()
        if name.contains("meditat") || name.contains("breath") { return "Reset your mind" }
        if name.contains("stretch") || name.contains("move") { return "Loosen up" }
        if name.contains("water") { return "Hydrate your body" }
        if name.contains("read") { return "A little space to learn" }
        if name.contains("desk") { return "Make room for focus" }
        if name.contains("phone") { return "Let the day settle" }
        return "One small step forward"
    }
}

#Preview { RoutinesView().environment(AppModel.preview) }
