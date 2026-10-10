import RoutineCore
import SwiftUI

@MainActor
struct InsightsView: View {
    @Environment(AppModel.self) private var model
    @State private var period: InsightPeriod = .thisWeek
    @AppStorage("daymark.week-start") private var weekStart = 2
    @State private var showsDefinitions = false
    @State private var adjustmentHabit: Habit?
    @State private var showsFinishedMessage = false

    var body: some View {
        GeometryReader { layout in
            let scale = min(layout.size.width / 432, 1.25)
            let snapshot = model.insights(for: period, weekStartsOn: weekStart)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    InsightsHero(snapshot: snapshot, period: $period, date: model.currentDayDate,
                                 width: layout.size.width, topInset: layout.safeAreaInsets.top,
                                 onExplain: { showsDefinitions = true })
                    weekChart(snapshot, scale: scale)
                    patterns(snapshot, scale: scale)
                    if !model.activeHabits.isEmpty {
                    adjustment(scale: scale)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                    streaks(snapshot, scale: scale)
                }
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .background { IllustratedScreenBackdrop() }
            .ignoresSafeArea(edges: .top)
        }
        .foregroundStyle(IllustratedStyle.ink)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsDefinitions) { definitions }
        .sheet(item: $adjustmentHabit) { habit in
            InsightAdjustmentSheet(habit: habit).environment(model)
        }
        .alert("A little space for you", isPresented: $showsFinishedMessage) {
            Button("Done", role: .cancel) { }
        } message: { Text("You have no open habits to adjust today. Enjoy the clear space.") }
    }

    private func sectionHeading(_ title: String, detail: String, scale: CGFloat) -> some View {
        IllustratedSectionHeading(title: title, detail: detail)
    }

    private func weekChart(_ snapshot: InsightsSnapshot, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Your week at a glance", detail: "More good days ahead.", scale: scale)
            IllustratedCard {
                VStack(spacing: 18) {
                    InsightBarChart(days: snapshot.days, scale: 1.2).frame(height: 128)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.dailyAverage.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                                .font(.system(.title2, design: .serif, weight: .semibold))
                            Text("Daily average").font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                        }
                        Spacer(minLength: 12)
                        if let difference = snapshot.previousWeekDifference {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(difference >= 0 ? "▲" : "▼") \(Int(abs(difference * 100).rounded())) pts")
                                    .font(.headline).foregroundStyle(IllustratedStyle.green)
                                Text("vs. previous week").font(.footnote).foregroundStyle(IllustratedStyle.muted)
                            }
                        } else {
                            Text("More history for comparison")
                                .font(.footnote).foregroundStyle(IllustratedStyle.muted).multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }.padding(.horizontal, 20).padding(.top, 24)
    }

    private func patterns(_ snapshot: InsightsSnapshot, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("Patterns", detail: "Real insights. Real progress.", scale: scale)
            if let pattern = snapshot.timePattern {
                patternRow(symbol: "sun.max.fill", tint: IllustratedStyle.sand,
                           title: pattern.isMorning ? "You often show up in the morning." : "Your rhythm leans later in the day.",
                           detail: "\(pattern.count) of \(pattern.total) completions were logged \(pattern.isMorning ? "between 5 AM and noon" : "outside the morning hours") \(period == .thisWeek ? "this" : "last") week.",
                           scale: scale)
            } else {
                patternRow(symbol: "sun.max.fill", tint: IllustratedStyle.sand,
                           title: "Your rhythm is taking shape.",
                           detail: "\(snapshot.completionCount) completed check-in\(snapshot.completionCount == 1 ? "" : "s") \(period == .thisWeek ? "this" : "last") week. A few more days will reveal your patterns.",
                           scale: scale)
            }
            patternRow(symbol: "moon.fill", tint: IllustratedStyle.lavender,
                       title: snapshot.adjustmentCount > 0 ? "You made room to adjust." : "A lighter day is still a choice.",
                       detail: snapshot.adjustmentCount > 0
                        ? "\(snapshot.adjustmentCount) minimum, skipped, or rest choices recorded. Notice what fits your life."
                        : "Log minimum versions and intentional rest to understand how you return.",
                       scale: scale)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .background(alignment: .bottomTrailing) {
            IllustratedFoliage().frame(width: 62 * scale, height: 107 * scale)
                .offset(x: 17 * scale, y: 13 * scale).opacity(0.16)
        }
    }

    private func patternRow(symbol: String, tint: Color, title: String, detail: String, scale: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12 * scale) {
            Image(systemName: symbol)
                .font(.system(size: 23 * scale, weight: .regular))
                .foregroundStyle(symbol == "sun.max.fill" ? Color.orange.opacity(0.66) : Color(red: 0.48, green: 0.50, blue: 0.65))
                .frame(width: 46 * scale, height: 46 * scale)
                .background(tint.opacity(0.85), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3 * scale) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.subheadline)
                    .foregroundStyle(IllustratedStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 4)
        }
        .frame(minHeight: 48 * scale)
        .accessibilityElement(children: .combine)
    }

    private var suggestedHabit: Habit? {
        model.todayHabits.first { model.status(for: $0) == .pending && $0.minimumTitle != nil }
    }

    private func adjustment(scale: CGFloat) -> some View {
        IllustratedCard {
            VStack(alignment: .leading, spacing: 14) {
                IllustratedSectionHeading(title: "One small adjustment")
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: suggestedHabit?.symbolName ?? "leaf.fill")
                        .font(.title2).foregroundStyle(IllustratedStyle.green)
                        .frame(width: 52, height: 52).background(IllustratedStyle.sage, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(suggestedHabit.map { "Try a smaller version of \($0.title.lowercased())." } ?? "Make a little room for yourself.")
                            .font(.body.weight(.medium))
                        Text(suggestedHabit?.minimumTitle ?? "No open habits to adjust today.")
                            .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                    }
                }
                Button {
                    if let habit = suggestedHabit { adjustmentHabit = habit }
                    else { showsFinishedMessage = true }
                } label: { Label("Try this", systemImage: "chevron.right") }
                    .buttonStyle(IllustratedPillButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func streaks(_ snapshot: InsightsSnapshot, scale: CGFloat) -> some View {
        VStack(spacing: 12) {
            sectionHeading("Streaks", detail: "Nice work so far.", scale: scale)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    streakPill(snapshot.currentStreak, label: "Current streak", symbol: "flame.fill", scale: scale)
                    streakPill(snapshot.longestStreak, label: "Longest streak", symbol: "star.fill", scale: scale)
                }
                VStack(spacing: 12) {
                    streakPill(snapshot.currentStreak, label: "Current streak", symbol: "flame.fill", scale: scale)
                    streakPill(snapshot.longestStreak, label: "Longest streak", symbol: "star.fill", scale: scale)
                }
            }
        }.padding(.horizontal, 20).padding(.top, 24)
    }

    private func streakPill(_ count: Int, label: String, symbol: String, scale: CGFloat) -> some View {
        IllustratedCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("\(count) \(count == 1 ? "day" : "days")", systemImage: symbol)
                    .font(.headline).foregroundStyle(IllustratedStyle.green)
                Text(label).font(.subheadline).foregroundStyle(IllustratedStyle.muted)
            }
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(label)
        .accessibilityValue("\(count) \(count == 1 ? "day" : "days")")
    }

    private var definitions: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("A little context").font(.system(size: 27, weight: .semibold, design: .serif))
            Text("Consistency").font(.headline)
            Text("The share of scheduled habits completed in full or as a minimum version on days with a logged choice. Daily average also includes unlogged days since you started tracking. Future and untracked days are excluded.")
            Text("Recovery").font(.headline)
            Text("A habit-return score, not a health score: how often you completed a habit the day after a minimum, skipped, or rest day. It uses the 28 days ending with the selected week, excludes unfinished days, and needs at least 3 opportunities.")
            Text("Streaks").font(.headline)
            Text("Consecutive days with at least one full or minimum completion, across all recorded history. An unfinished today doesn’t break yesterday’s streak. Scheduled rest protection is not included in this first calculation.")
            Button("Got it") { showsDefinitions = false }
                .buttonStyle(.borderedProminent).tint(IllustratedStyle.green)
                .frame(maxWidth: .infinity)
        }
        .font(.callout)
        .padding(24)
        .presentationDetents([.large])
    }
}

private struct InsightsHero: View {
    let snapshot: InsightsSnapshot
    @Binding var period: InsightPeriod
    let date: Date
    let width: CGFloat
    let topInset: CGFloat
    let onExplain: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased())
                    .font(.caption.weight(.medium)).tracking(1).foregroundStyle(IllustratedStyle.muted)
                    .padding(.trailing, typeSize.isAccessibilitySize ? 0 : 138)
                Text("Insights").font(.system(.largeTitle, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text("Small patterns. A brighter you.")
                    .font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                if typeSize.isAccessibilitySize { periodMenu }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topTrailing) { if !typeSize.isAccessibilitySize { periodMenu } }
            .padding(.horizontal, 22).padding(.top, max(topInset, 12) + 10)
            let arrangement = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 20)) : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
            arrangement {
                scoreColumn(blue: false)
                scoreColumn(blue: true).padding(.top, typeSize.isAccessibilitySize ? 0 : 18)
            }
            .padding(.horizontal, 30)
        }
        .background(alignment: .top) {
            GeometryReader { geometry in
                Image("MorningLandscape").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: max(topInset, 44) + 202, alignment: .bottom).clipped()
                    .overlay(alignment: .top) {
                        LinearGradient(stops: [.init(color: IllustratedStyle.paper.opacity(0.86), location: 0),
                                               .init(color: IllustratedStyle.paper.opacity(0.76), location: 0.64),
                                               .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                            .frame(height: max(topInset, 44) + 145)
                    }
                IllustratedWave(crest: 0.24, trough: 0.42).fill(IllustratedStyle.paper)
                    .frame(height: max(geometry.size.height - max(topInset, 44) - 150, 100))
                    .offset(y: max(topInset, 44) + 150)
            }.accessibilityHidden(true)
        }
    }

    private var periodMenu: some View {
        Menu {
            Picker("Insight period", selection: $period) {
                ForEach(InsightPeriod.allCases) { item in Text(item.rawValue).tag(item) }
            }
        } label: {
            Label(period.rawValue, systemImage: "chevron.down")
                .font(.subheadline).padding(.horizontal, 14).frame(minHeight: 44)
                .background(.white.opacity(0.95), in: Capsule())
        }.accessibilityLabel("Insight period").accessibilityValue(period.rawValue)
    }

    private func scoreColumn(blue: Bool) -> some View {
        let score = blue ? snapshot.recoveryScore : snapshot.consistency
        let value = blue ? score.map { String(format: "%.1f", $0) } : score.map { "\(Int(($0 * 100).rounded()))" }
        return VStack(spacing: 12) {
            Button(action: onExplain) {
                InsightScoreRing(value: value ?? "—", denominator: blue ? "/10" : nil,
                    title: blue ? "Recovery\nscore" : "Consistency\nscore",
                    progress: blue ? score.map { $0 / 10 } : score, blue: blue)
                    .frame(width: min(width * 0.32, 148), height: min(width * 0.32, 148))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(blue ? "Recovery score" : "Consistency score")
            .accessibilityValue(value.map { "\($0). Learn how this is calculated." } ?? "Not enough history. Learn how this is calculated.")
            Text(blue
                 ? snapshot.recoveryScore != nil ? "You returned after \(snapshot.recoveryReturns) of \(snapshot.recoveryOpportunities) lighter days." : "A little more history will reveal your recovery pattern."
                 : snapshot.consistency.map { "You showed up for \(Int(($0 * 100).rounded()))% of your habits on logged days." } ?? "Your first check-ins will start building this picture.")
                .font(.footnote).foregroundStyle(IllustratedStyle.muted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity)
    }
}


private struct InsightScoreRing: View {
    let value: String
    let denominator: String?
    let title: String
    let progress: Double?
    let blue: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size.width
            ZStack {
                Circle().fill(.white.opacity(0.95))
                Circle().stroke(.white.opacity(0.92), lineWidth: 5)
                Circle().stroke(blue ? Color(red: 0.88, green: 0.94, blue: 0.97) : Color(red: 0.87, green: 0.92, blue: 0.89), lineWidth: 10)
                    .padding(10)
                Circle().trim(from: 0, to: progress ?? 0)
                    .stroke(LinearGradient(colors: blue ? [Color(red: 0.37, green: 0.60, blue: 0.74), Color(red: 0.69, green: 0.83, blue: 0.89)] : [Color(red: 0.35, green: 0.55, blue: 0.43), Color(red: 0.50, green: 0.68, blue: 0.55)], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .padding(10).rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Image(systemName: blue ? "moon.fill" : "leaf.fill")
                        .font(.system(size: size * 0.12))
                        .foregroundStyle(blue ? Color(red: 0.54, green: 0.70, blue: 0.82) : Color(red: 0.39, green: 0.60, blue: 0.45))
                        .padding(.bottom, 3)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(value).font(.system(size: size * 0.205, weight: .bold, design: .serif))
                        if let denominator { Text(denominator).font(.system(size: size * 0.10, weight: .medium)) }
                    }
                    Text(title).font(.system(size: size * 0.079))
                        .foregroundStyle(IllustratedStyle.muted)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .accessibilityElement(children: .ignore)
    }
}

private struct InsightBarChart: View {
    let days: [InsightDay]
    let scale: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 7 * scale) {
            VStack {
                Text("100")
                Spacer()
                Text("50")
                Spacer()
                Text("0")
            }
            .font(.system(size: 8.5 * scale))
            .foregroundStyle(IllustratedStyle.muted)
            .frame(height: 78 * scale)
            .padding(.top, -4 * scale)
            VStack(spacing: 6 * scale) {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        Path { path in
                            for fraction in [0.0, 0.5, 1.0] {
                                let y = geometry.size.height * fraction
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                            }
                        }
                        .stroke(IllustratedStyle.muted.opacity(0.24), style: StrokeStyle(lineWidth: 0.6, dash: [2, 2]))
                        HStack(alignment: .bottom, spacing: 9 * scale) {
                            ForEach(days) { day in
                                VStack(spacing: 0) {
                                    if let completion = day.completion {
                                        RoundedRectangle(cornerRadius: 6 * scale)
                                            .fill(LinearGradient(colors: [Color(red: 0.43, green: 0.64, blue: 0.52), Color(red: 0.72, green: 0.82, blue: 0.74)], startPoint: .top, endPoint: .bottom))
                                            .frame(height: max(0, geometry.size.height * completion))
                                    } else {
                                        Capsule().fill(IllustratedStyle.muted.opacity(0.22)).frame(width: 7, height: 1.5)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                .accessibilityValue(day.completion.map { "\(Int(($0 * 100).rounded())) percent" } ?? "No tracked day")
                            }
                        }
                        .padding(.horizontal, 5 * scale)
                    }
                }
                .frame(height: 73 * scale)
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 8.5 * scale))
                            .foregroundStyle(IllustratedStyle.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.top, 7 * scale)
    }
}

private struct InsightAdjustmentSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("One small adjustment")
                .font(.system(size: 27, weight: .semibold, design: .serif))
            Label(habit.title, systemImage: habit.symbolName).font(.title3)
            Text(habit.minimumTitle ?? "Try a smaller version today.").font(.headline)
            Text("Only mark this complete after you've done it. This records a minimum version for today, not a schedule change.")
                .foregroundStyle(.secondary)
            Button("I did the minimum") {
                model.recover(habit, with: .minimum)
                dismiss()
            }
            .buttonStyle(.borderedProminent).tint(IllustratedStyle.green)
            Button("Not now") { dismiss() }.buttonStyle(.bordered)
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium])
    }
}

#Preview { InsightsView().environment(AppModel.preview) }
