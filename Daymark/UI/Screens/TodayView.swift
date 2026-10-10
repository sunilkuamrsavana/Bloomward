import Foundation
import RoutineCore
import SwiftUI

private enum TodayPalette {
    static let canvas = Color(red: 0.965, green: 0.974, blue: 0.969)
    static let ink = Color(red: 0.035, green: 0.086, blue: 0.160)
    static let muted = Color(red: 0.405, green: 0.465, blue: 0.515)
    static let green = Color(red: 0.165, green: 0.405, blue: 0.333)
    static let greenSoft = Color(red: 0.748, green: 0.876, blue: 0.755)
    static let sageTile = Color(red: 0.885, green: 0.945, blue: 0.890)
    static let sandTile = Color(red: 0.992, green: 0.948, blue: 0.845)
    static let blueTile = Color(red: 0.875, green: 0.935, blue: 0.978)
    static let blushTile = Color(red: 0.988, green: 0.910, blue: 0.895)
    static let lavenderTile = Color(red: 0.922, green: 0.920, blue: 0.978)
}

@MainActor
struct TodayView: View {
    var browseRoutines: () -> Void = { }
    var browseHabits: () -> Void = { }
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var recoveryHabit: Habit?
    @State private var showsActiveRoutineNotice = false
    @State private var showsNewHabit = false
    @AppStorage("daymark.appearance") private var appearance = "System"

    var body: some View {
        GeometryReader { layout in
            ZStack(alignment: .top) {
                TodayPalette.canvas.ignoresSafeArea()
                IllustratedPageBackdrop()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if model.activeHabits.isEmpty && model.activeRoutines.isEmpty {
                            FirstUseTodayView(date: model.currentDayDate, width: layout.size.width, topInset: layout.safeAreaInsets.top) {
                                showsNewHabit = true
                            }
                        } else if model.activeRoutines.isEmpty, model.activeHabits.count == 1,
                                  let habit = model.todayHabits.first, habit.settings?.createdOn == model.today {
                            FirstDayTodayView(habit: habit, topInset: layout.safeAreaInsets.top, browseRoutines: browseRoutines)
                        } else {
                        MorningHero(
                            date: model.currentDayDate,
                            completed: model.completedTodayCount,
                            total: model.todayHabits.count,
                            progress: model.completionRatio,
                            width: layout.size.width,
                            topInset: layout.safeAreaInsets.top,
                            onAppearanceToggle: toggleAppearance
                        )

                        if model.activeRoutine != nil || !model.todayRoutines.isEmpty { nowSection }
                        if !model.todayHabits.isEmpty {
                            if !model.todayHabitSections.quickLog.isEmpty { quickLogSection }
                            if !upcomingHabits.isEmpty { nextSection }
                        } else {
                            quietDayCard
                        }
                        if !model.activeRoutines.isEmpty { laterSection }
                        }
                    }
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
            }
        }
        .foregroundStyle(TodayPalette.ink)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showsNewHabit) {
            NewHabitView().environment(model)
        }
        .sheet(item: $recoveryHabit) { habit in
            RecoverySheet(habit: habit)
                .environment(model)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("A routine is already in progress", isPresented: $showsActiveRoutineNotice) {
            Button("Continue current routine") { model.resumeRoutine() }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Finish your current routine before starting another. Your progress is saved.")
        }
    }

    private var ambientBackdrop: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(Color(red: 0.82, green: 0.91, blue: 0.91).opacity(0.45))
                    .frame(width: 330, height: 330)
                    .blur(radius: 50)
                    .position(x: proxy.size.width * 0.16, y: 470)

                Circle()
                    .fill(Color(red: 0.86, green: 0.91, blue: 0.80).opacity(0.42))
                    .frame(width: 360, height: 360)
                    .blur(radius: 58)
                    .position(x: proxy.size.width * 0.92, y: 760)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var quietDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A little breathing room")
                .font(.system(size: 24, weight: .semibold, design: .serif))
            Text("No habits are scheduled for today. You can find your habits and change their days in the Habits tab.")
                .font(.system(size: 14)).foregroundStyle(TodayPalette.muted)
            Button("Add a habit") { showsNewHabit = true }
                .buttonStyle(.borderedProminent).tint(TodayPalette.green)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 28))
        .padding(18)
    }

    private var nowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            IllustratedSectionHeading(title: "Now", detail: model.activeRoutine == nil ? "You set the pace." : "Your place is saved.")
            if let routine = model.activeRoutine ?? model.todayRoutines.first {
                IllustratedRoutineCard(routine: routine, habits: model.activeHabits,
                    isCurrent: model.activeRoutine?.id == routine.id,
                    completedSteps: model.activeRoutine?.id == routine.id ? resolvedSteps(for: routine) : nil) {
                    if model.activeRoutine?.id == routine.id { model.resumeRoutine() }
                    else { model.begin(routine) }
                }
            }
            if let returnTime = model.routineResumeAt {
                Text(returnTime > Date() ? "Paused until \(returnTime.formatted(.dateTime.hour().minute())). Continue whenever you’re ready." : "Ready when you are. Your routine is saved.")
                    .font(.subheadline).foregroundStyle(TodayPalette.muted)
            }
        }.padding(.horizontal, 20).padding(.bottom, 24)
    }

    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            IllustratedSectionHeading(title: "Quick Log", detail: "Small habits. A brighter day.")
            if model.todayHabitSections.quickLog.count == 1 || dynamicTypeSize.isAccessibilitySize {
                ForEach(model.todayHabitSections.quickLog) { habit in
                    QuickLogRow(habit: habit, status: model.status(for: habit), tint: quickLogTint(for: habit)) {
                        model.toggle(habit)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.todayHabitSections.quickLog) { habit in
                            QuickLogTile(habit: habit, status: model.status(for: habit), tint: quickLogTint(for: habit)) {
                                model.toggle(habit)
                            }.frame(width: 112)
                        }
                    }
                }
            }
        }.padding(.horizontal, 20).padding(.bottom, 24)
    }

    private var nextSection: some View {
        let habits = upcomingHabits

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text("Next")
                    .font(.system(.title2, design: .serif, weight: .semibold))

                Text("Keep the momentum going.")
                    .font(.subheadline)
                    .foregroundStyle(TodayPalette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                Button(action: browseHabits) {
                    HStack(spacing: 6) {
                        Text("View All")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TodayPalette.ink)
                    .frame(height: 32)
                    .padding(.horizontal, 12)
                    .background(.white.opacity(0.64), in: Capsule())
                    .overlay {
                        Capsule().stroke(TodayPalette.ink.opacity(0.12), lineWidth: 1)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                    ScheduledHabitRow(
                        habit: habit,
                        status: model.status(for: habit),
                        time: scheduleTime(for: habit),
                        detail: scheduleDetail(for: habit, at: index),
                        tint: index == 0 ? TodayPalette.lavenderTile : TodayPalette.sageTile,
                        action: { model.toggle(habit) }
                    )
                    .contextMenu {
                        Button("Use minimum version", systemImage: "leaf") {
                            model.recover(habit, with: .minimum)
                        }
                        Button("Skip intentionally", systemImage: "forward") {
                            model.recover(habit, with: .skip)
                        }
                        Button("Take a rest day", systemImage: "moon.zzz") {
                            model.recover(habit, with: .rest)
                        }
                        .disabled(habit.settings?.allowsRest == false)
                    }

                }
            }
            .padding(.vertical, 2)
            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.035), radius: 18, y: 7)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 9)
    }

    @ViewBuilder private var laterSection: some View {
        let featuredID = (model.activeRoutine ?? model.todayRoutines.first)?.id
        let others = model.todayRoutines.filter { $0.id != featuredID }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                IllustratedSectionHeading(title: "More routines", detail: "Whenever you're ready.")
                ForEach(others.prefix(2)) { routine in
                    Button(action: browseRoutines) {
                        IllustratedCard {
                            HStack(spacing: 14) {
                                Image(systemName: routine.symbolName).font(.title2)
                                    .foregroundStyle(IllustratedStyle.green)
                                    .frame(width: 52, height: 52).background(IllustratedStyle.lavender, in: Circle())
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(routine.title).font(.system(.title3, design: .serif, weight: .semibold))
                                    Text("\(routine.leafSteps.count) steps • At your pace")
                                        .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right").font(.footnote)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }
    }

    private var upcomingHabits: [Habit] {
        model.todayHabitSections.next
    }

    private func resolvedSteps(for routine: Routine) -> Int {
        if let run = model.state.activeRoutine, run.routineID == routine.id {
            return run.outcomes.filter { $0 != .pending }.count
        }

        return routine.executionSteps(on: model.today).map(\.step).reduce(into: 0) { result, step in
            guard
                let habitID = step.habitID,
                let habit = model.activeHabits.first(where: { $0.id == habitID }),
                model.status(for: habit).isPositive
            else { return }
            result += 1
        }
    }

    private func quickLogTint(for habit: Habit) -> Color {
        switch habit.settings?.category {
        case .mind: TodayPalette.sandTile
        case .productivity: TodayPalette.lavenderTile
        case .lifestyle: TodayPalette.blushTile
        case .health, .custom, .none: TodayPalette.sageTile
        }
    }

    private func scheduleTime(for habit: Habit) -> String {
        guard let settings = habit.settings, settings.timeWindowEnabled else { return "Any time" }
        let date = Calendar.current.date(bySettingHour: settings.startMinute / 60, minute: settings.startMinute % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }

    private func scheduleDetail(for habit: Habit, at index: Int) -> String {
        habit.settings?.category.rawValue ?? habit.minimumTitle ?? "At your own pace"
    }

    private func toggleAppearance() {
        appearance = appearance == "Dark" ? "Light" : "Dark"
    }
}

private struct FirstUseTodayView: View {
    let date: Date
    let width: CGFloat
    let topInset: CGFloat
    let onCreateHabit: () -> Void

    var body: some View {
        let scale = min(width / 432, 1.2)
        VStack(alignment: .leading, spacing: 0) {
            IllustratedScreenHeader(title: "Welcome", subtitle: "Small steps. A brighter you.",
                                    quote: "Your pace.\nYour beginning.", topInset: topInset)

            VStack(alignment: .leading, spacing: 13 * scale) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 24 * scale))
                    .foregroundStyle(TodayPalette.green)
                    .frame(width: 51 * scale, height: 51 * scale)
                    .background(IllustratedStyle.sage, in: Circle())
                    .accessibilityHidden(true)
                Text("Start with one small habit")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                Text("Choose something you want to make time for.\nOne small step is enough for today.")
                    .font(.body)
                    .foregroundStyle(TodayPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onCreateHabit) {
                    HStack(spacing: 12) {
                        Text("Create your first habit")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14 * scale, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 49)
                    .background(IllustratedStyle.button, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 3)
            }
            .padding(23 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 30 * scale))
            .padding(.horizontal, 18 * scale)
            .padding(.top, -12 * scale)

            VStack(alignment: .leading, spacing: 20 * scale) {
                Text("Make it your own")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                tip("A rhythm that fits your life", detail: "Pick your days. Leave room to rest.", symbol: "calendar", tint: IllustratedStyle.sage, scale: scale)
                tip("See the small things add up", detail: "Your insights grow as you check in.", symbol: "chart.bar", tint: IllustratedStyle.mist, scale: scale)
            }
            .padding(.horizontal, 26 * scale)
            .padding(.top, 26 * scale)
            Text("No catching up. Just a place to begin.")
                .font(.subheadline)
                .foregroundStyle(TodayPalette.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 27 * scale)
                .padding(.bottom, 16 * scale)
        }
    }

    private func tip(_ title: String, detail: String, symbol: String, tint: Color, scale: CGFloat) -> some View {
        HStack(spacing: 14 * scale) {
            Image(systemName: symbol)
                .font(.system(size: 20 * scale))
                .foregroundStyle(TodayPalette.green)
                .frame(width: 44 * scale, height: 44 * scale)
                .background(tint, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13 * scale, weight: .medium))
                Text(detail).font(.subheadline).foregroundStyle(TodayPalette.muted)
            }
        }
    }
}

private struct MorningHero: View {
    let date: Date
    let completed: Int
    let total: Int
    let progress: Double
    let width: CGFloat
    let topInset: CGFloat
    let onAppearanceToggle: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage("daymark.profile-name") private var profileName = ""
    @ScaledMetric(relativeTo: .largeTitle) private var greetingSize = 28.0

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? greeting : "\(greeting), \(name)"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased())
                        .font(.caption.weight(.medium)).tracking(1).foregroundStyle(TodayPalette.muted)
                    Spacer()
                }.padding(.trailing, 52)
                Text(greeting)
                    .font(.system(size: greetingSize, weight: .bold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("A calmer, brighter you\nis built by what you do today.")
                    .font(.subheadline).foregroundStyle(TodayPalette.muted)
            }
            .padding(.horizontal, 22)
            .padding(.top, max(topInset, 12) + 4)
            .overlay(alignment: .topTrailing) {
                Button(action: onAppearanceToggle) {
                    Image(systemName: "sun.max.fill").font(.title3).foregroundStyle(.orange)
                        .frame(width: 44, height: 44).background(.white.opacity(0.9), in: Circle())
                }.buttonStyle(.plain).accessibilityLabel("Toggle appearance")
                    .padding(.trailing, 22).padding(.top, max(topInset, 12))
            }

            let arrangement = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(alignment: .bottom, spacing: 14))
            arrangement {
                ProgressMedallion(completed: completed, total: total, progress: progress)
                    .frame(width: min(width * 0.35, 154), height: min(width * 0.35, 154))
                    .overlay { Circle().stroke(.white.opacity(0.95), lineWidth: 5) }
                HStack(spacing: 9) {
                    Image(systemName: "leaf.fill").foregroundStyle(TodayPalette.green).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(total == 0 ? "A little breathing room." : completed == 0 ? "Ready when you are." : "You’re making progress.")
                            .font(.subheadline.weight(.medium))
                        Text(total == 0 ? "Nothing due today." : completed == 0 ? "One small step." : "Keep going.")
                            .font(.footnote).foregroundStyle(TodayPalette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 15).padding(.vertical, 15)
                .background(.white.opacity(0.94), in: Capsule())
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 24)
        }
        .background(alignment: .top) {
            GeometryReader { geometry in
                Image("MorningLandscape").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: max(topInset, 44) + 184, alignment: .bottom)
                    .clipped()
                    .overlay(alignment: .top) {
                        LinearGradient(stops: [.init(color: IllustratedStyle.paper.opacity(0.86), location: 0),
                                               .init(color: IllustratedStyle.paper.opacity(0.76), location: 0.64),
                                               .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                            .frame(height: max(topInset, 44) + 145)
                    }
                IllustratedWave(crest: 0.15, trough: 0.5)
                    .fill(TodayPalette.canvas)
                    .frame(height: max(geometry.size.height - max(topInset, 44) - 137, 80))
                    .offset(y: max(topInset, 44) + 137)
            }.accessibilityHidden(true)
        }
    }
}

private struct ProgressMedallion: View {
    let completed: Int
    let total: Int
    let progress: Double

    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.991, green: 0.991, blue: 0.983))

            Circle()
                .stroke(.white.opacity(0.78), lineWidth: 10)
                .padding(8)

            Circle()
                .stroke(TodayPalette.green.opacity(0.12), lineWidth: 10)
                .padding(8)

            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(Color(red: 0.39, green: 0.58, blue: 0.50), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(8)

            VStack(spacing: 1) {
                if total == 0 {
                    Image(systemName: "leaf")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(TodayPalette.green)
                    Text("Nothing due\ntoday")
                        .font(.system(size: 12))
                        .foregroundStyle(TodayPalette.muted)
                        .multilineTextAlignment(.center)
                } else {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(completed)")
                        .font(.system(size: 29, weight: .semibold, design: .serif))
                    Text("of \(total)")
                        .font(.system(size: 14, weight: .medium))
                }
                Text("habits done\ntoday")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(TodayPalette.muted)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: normalizedProgress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Habits completed today")
        .accessibilityValue("\(completed) of \(total)")
    }
}


private struct QuickLogRow: View {
    let habit: Habit
    let status: DailyHabitStatus
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: habit.symbolName).font(.title2)
                    .foregroundStyle(TodayPalette.green)
                    .frame(width: 46, height: 46).background(tint, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title).font(.body.weight(.semibold))
                    Text(status == .pending ? "Tap to mark done" : status.shortLabel)
                        .font(.subheadline).foregroundStyle(TodayPalette.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28, weight: .light)).foregroundStyle(TodayPalette.green)
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 78)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(habit.title)
        .accessibilityValue(status.shortLabel)
        .accessibilityHint(status == .completed ? "Undo completion" : "Mark done")
    }
}

private struct QuickLogTile: View {
    let habit: Habit
    let status: DailyHabitStatus
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Image(systemName: status == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18)).foregroundStyle(TodayPalette.green)
                }
                Image(systemName: habit.symbolName).font(.system(size: 25, weight: .medium))
                    .foregroundStyle(TodayPalette.green).frame(height: 28)
                Text(habit.title).font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center).lineLimit(2).frame(minHeight: 36)
                Text(status == .pending ? "Mark done" : status.shortLabel)
                    .font(.caption).foregroundStyle(TodayPalette.muted)
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 148)
            .background(tint, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(habit.title)
        .accessibilityValue(status.shortLabel)
        .accessibilityHint(status == .completed ? "Undo completion" : "Mark done")
    }
}

private struct ScheduledHabitRow: View {
    let habit: Habit
    let status: DailyHabitStatus
    let time: String
    let detail: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: status.isPositive ? "checkmark" : "")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(status.isPositive ? TodayPalette.green : .clear, in: Circle())
                    .overlay {
                        Circle().stroke(TodayPalette.muted.opacity(0.42), lineWidth: status.isPositive ? 0 : 1.1)
                    }

                Circle()
                    .fill(tint)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: habit.symbolName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TodayPalette.ink.opacity(0.70))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.compactTitle)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(status.isPositive ? "Completed today" : detail)
                        .font(.subheadline)
                        .foregroundStyle(TodayPalette.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(time)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color(red: 0.30, green: 0.43, blue: 0.55))
                    .padding(.horizontal, 10)
                    .frame(height: 29)
                    .background(Color(red: 0.91, green: 0.94, blue: 0.95).opacity(0.88), in: Capsule())
            }
            .foregroundStyle(TodayPalette.ink)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.title), \(status.shortLabel), \(time)")
    }
}

@MainActor
private struct RecoverySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let habit: Habit

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DaymarkTheme.Spacing.xLarge) {
                VStack(alignment: .leading, spacing: DaymarkTheme.Spacing.small) {
                    Text(habit.title.uppercased())
                        .font(DaymarkTheme.Typography.overline)
                        .tracking(1.2)
                        .foregroundStyle(TodayPalette.green)

                    Text("What fits today?")
                        .font(DaymarkTheme.Typography.title)

                    Text("Adjusting the plan is part of keeping it. Nothing becomes overdue.")
                        .font(DaymarkTheme.Typography.callout)
                        .foregroundStyle(TodayPalette.muted)
                }

                VStack(spacing: DaymarkTheme.Spacing.small) {
                    recoveryButton("Do the minimum", detail: habit.minimumTitle ?? "Do a smaller version", symbol: "leaf.fill", choice: .minimum)
                    recoveryButton("Skip intentionally", detail: "Keep the day clear", symbol: "forward.fill", choice: .skip)
                    recoveryButton("Take a rest day", detail: "Rest without breaking anything", symbol: "moon.zzz.fill", choice: .rest)
                }

                Spacer(minLength: 0)
            }
            .padding(DaymarkTheme.Spacing.page)
            .background(TodayPalette.canvas.ignoresSafeArea())
            .foregroundStyle(TodayPalette.ink)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func recoveryButton(
        _ title: String,
        detail: String,
        symbol: String,
        choice: RecoveryChoice
    ) -> some View {
        Button {
            model.recover(habit, with: choice)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(TodayPalette.green)
                    .frame(width: 38, height: 38)
                    .background(TodayPalette.sageTile, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DaymarkTheme.Typography.bodyEmphasized)
                    Text(detail)
                        .font(DaymarkTheme.Typography.caption)
                        .foregroundStyle(TodayPalette.muted)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(TodayPalette.muted)
            }
            .foregroundStyle(TodayPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(.horizontal, 12)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private extension Routine {
    var durationLabel: String {
        let seconds = steps.compactMap(\.estimatedDurationSeconds).filter { $0 > 0 }.reduce(0, +)
        guard seconds > 0 else { return "Open" }
        let minutes = max(1, Int(ceil(Double(seconds) / 60)))
        return "\(minutes) min"
    }
}

private extension Habit {
    var compactTitle: String {
        title
    }
}

private extension DailyHabitStatus {
    var isPositive: Bool {
        self == .completed || self == .minimum
    }

    var shortLabel: String {
        switch self {
        case .pending: "Not done"
        case .completed: "Done"
        case .minimum: "Minimum"
        case .skipped: "Skipped"
        case .rest: "Rest"
        }
    }
}

#Preview {
    NavigationStack {
        TodayView()
            .environment(AppModel.preview)
    }
}
