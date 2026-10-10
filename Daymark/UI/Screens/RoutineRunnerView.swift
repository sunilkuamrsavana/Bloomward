import Foundation
import RoutineCore
import SwiftUI

@MainActor
struct RoutineRunnerView: View {
    @Environment(AppModel.self) private var model
    @State private var showsRoutine = false
    @State private var showsSchedule = false
    @State private var returnDate = Date().addingTimeInterval(3600)

    var body: some View {
        GeometryReader { layout in
            let scale = min(layout.size.width / 432, 1.2)
            ScrollView {
                if let routine = model.activeRoutine,
                   let active = model.state.activeRoutine,
                   let step = model.currentStep {
                    VStack(spacing: 0) {
                        playerHeader(routine: routine, active: active, width: layout.size.width, topInset: layout.safeAreaInsets.top)
                        currentStep(step, scale: scale)
                            .padding(.top, -8 * scale)
                        completeButton
                            .frame(width: 254 * scale)
                            .padding(.top, 10 * scale)
                        recoveryActions
                            .padding(.horizontal, 58 * scale)
                            .padding(.top, 12 * scale)
                            .padding(.bottom, 16 * scale)
                        upcomingSection(routine: routine, active: active, scale: scale)
                    }
                    .padding(.bottom, 12)
                } else {
                    ContentUnavailableView("Routine finished", systemImage: "leaf.circle.fill", description: Text("Your progress is saved for today."))
                        .padding(.top, 150)
                    Button("Back to today") { model.isRunnerPresented = false }
                }
            }
            .scrollIndicators(.hidden)
            .background { IllustratedPageBackdrop() }
            .ignoresSafeArea(edges: .top)
        }
        .foregroundStyle(IllustratedStyle.ink)
        .tint(IllustratedStyle.green)
        .sheet(isPresented: $showsRoutine) { routineOutline }
        .sheet(isPresented: $showsSchedule) { rescheduleSheet }
    }

    private func playerHeader(routine: Routine, active: ActiveRoutine, width: CGFloat, topInset: CGFloat) -> some View {
        let scale = min(width / 432, 1.2)
        let adjustment = max(0, topInset - 44)
        let seconds = model.runningSteps.dropFirst(active.currentStepIndex).compactMap(\.estimatedDurationSeconds).reduce(0, +)
        return ZStack(alignment: .topLeading) {
            IllustratedScenery()

            HStack(alignment: .top, spacing: 13 * scale) {
                Button { model.deferRoutine() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19 * scale, weight: .medium))
                        .frame(width: 38 * scale, height: 38 * scale)
                        .background(.white.opacity(0.80), in: Circle())
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back, pause routine")

                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.title)
                        .font(.system(size: 28 * scale, weight: .semibold, design: .serif))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text("Step \(active.currentStepIndex + 1) of \(model.runningSteps.count)  •  \(seconds > 0 ? "~ \(Int(ceil(Double(seconds) / 60))) min left" : "At your pace")")
                        .font(.system(size: 13 * scale))
                        .foregroundStyle(IllustratedStyle.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Menu {
                    Button("View routine", systemImage: "list.bullet") { showsRoutine = true }
                    Button("Pause and close", systemImage: "pause") { model.deferRoutine() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 19 * scale, weight: .medium))
                        .frame(width: 38 * scale, height: 38 * scale)
                        .background(.white.opacity(0.85), in: Circle())
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Routine options")
            }
            .padding(.horizontal, 19 * scale)
            .padding(.top, 45 * scale + adjustment)

            Text("Calmer\nminds\nbrighter\ndays")
                .font(.custom("SnellRoundhand", size: 16 * scale))
                .foregroundStyle(IllustratedStyle.green.opacity(0.73))
                .multilineTextAlignment(.center)
                .rotationEffect(.degrees(-12))
                .position(x: width * 0.89, y: 144 * scale + adjustment)
                .accessibilityHidden(true)

            IllustratedWave(crest: 0.2, trough: 0.38)
                .fill(IllustratedStyle.sage.opacity(0.96))
                .frame(height: 86 * scale)
                .frame(maxHeight: .infinity, alignment: .bottom)
            IllustratedWave(crest: 0.87, trough: 0.47)
                .fill(IllustratedStyle.paper)
                .frame(height: 76 * scale)
                .frame(maxHeight: .infinity, alignment: .bottom)

            Text("A SMALL STEP\nA BRIGHTER YOU")
                .font(.system(size: 8 * scale, weight: .medium))
                .tracking(2)
                .lineSpacing(4)
                .foregroundStyle(Color(red: 0.47, green: 0.58, blue: 0.59))
                .offset(x: 26 * scale, y: 205 * scale + adjustment)
        }
        .frame(width: width, height: 248 * scale + adjustment)
        .clipped()
    }

    private func currentStep(_ step: RoutineStep, scale: CGFloat) -> some View {
        VStack(spacing: 4 * scale) {
            Text(model.currentStepContext ?? "CURRENT STEP")
                .font(.system(size: 9 * scale, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(IllustratedStyle.muted)
            Text(step.title)
                .font(.system(size: 32 * scale, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Text(step.illustratedSubtitle)
                .font(.system(size: 14 * scale))
                .foregroundStyle(IllustratedStyle.muted)
            if let notes = step.notes, !notes.isEmpty {
                Text(notes).font(.subheadline).foregroundStyle(IllustratedStyle.muted)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let duration = step.estimatedDurationSeconds ?? 0
                let remaining = max(0, Int(ceil((model.currentStepDeadline ?? context.date).timeIntervalSince(context.date))))
                let fraction = duration > 0 ? min(1, Double(remaining) / Double(duration)) : 0
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.88, green: 0.92, blue: 0.89), lineWidth: 14 * scale)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Color(red: 0.37, green: 0.57, blue: 0.47), style: StrokeStyle(lineWidth: 14 * scale, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2 * scale) {
                        PaintedLeaf()
                            .fill(LinearGradient(colors: [Color(red: 0.44, green: 0.65, blue: 0.50), IllustratedStyle.green], startPoint: .topTrailing, endPoint: .bottomLeading))
                            .frame(width: 20 * scale, height: 26 * scale)
                            .padding(.bottom, 6 * scale)
                        Text(duration > 0 ? String(format: "%02d:%02d", remaining / 60, remaining % 60) : "Open")
                            .font(.system(size: 43 * scale, weight: .bold, design: .serif))
                            .monospacedDigit()
                        Text(duration > 0 ? (remaining > 0 ? "left" : "Take your time") : "at your pace")
                            .font(.system(size: 15 * scale))
                            .foregroundStyle(IllustratedStyle.muted)
                    }
                }
                .frame(width: 188 * scale, height: 188 * scale)
                .padding(7 * scale)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(duration > 0 ? "Time remaining" : "Untimed step")
                .accessibilityValue(duration > 0 ? "\(remaining / 60) minutes and \(remaining % 60) seconds" : "Go at your own pace")
            }
            .padding(.top, 12 * scale)
            .background(alignment: .trailing) {
                Text("A calmer\ntoday creates\na brighter\ntomorrow.")
                    .font(.custom("SnellRoundhand", size: 14 * scale))
                    .foregroundStyle(IllustratedStyle.green.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .rotationEffect(.degrees(-10))
                    .offset(x: 99 * scale, y: -17 * scale)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var completeButton: some View {
        Button { model.completeCurrentStep() } label: {
            HStack(spacing: 17) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(IllustratedStyle.green)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.94), in: Circle())
                Text("Complete")
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(IllustratedStyle.button, in: Capsule())
            .overlay { Capsule().stroke(.white.opacity(0.75), lineWidth: 0.75) }
            .shadow(color: IllustratedStyle.green.opacity(0.17), radius: 16, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Complete current step")
    }

    private var recoveryActions: some View {
        HStack(alignment: .top) {
            circularAction("Snooze 10m", symbol: "clock", tint: IllustratedStyle.lavender) {
                model.rescheduleRoutine(to: Date().addingTimeInterval(600))
            }
            Spacer(minLength: 12)
            circularAction("Skip", symbol: "forward.end.fill", tint: IllustratedStyle.blush) {
                model.skipCurrentStep()
            }
            Spacer(minLength: 12)
            circularAction("Reschedule", symbol: "calendar", tint: IllustratedStyle.sand) {
                returnDate = Date().addingTimeInterval(3600)
                showsSchedule = true
            }
        }
    }

    private func circularAction(_ title: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 52, height: 52)
                    .background(tint, in: Circle())
                Text(title).font(.system(size: 11.5)).fixedSize()
            }
            .foregroundStyle(Color(red: 0.34, green: 0.39, blue: 0.48))
        }
        .buttonStyle(.plain)
    }

    private func upcomingSection(routine: Routine, active: ActiveRoutine, scale: CGFloat) -> some View {
        let remaining = Array(model.runningSteps.dropFirst(active.currentStepIndex + 1))
        return VStack(alignment: .leading, spacing: 11 * scale) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(remaining.isEmpty ? "One last step" : "Up next")
                        .font(.system(size: 23 * scale, weight: .semibold, design: .serif))
                    Text(remaining.isEmpty ? "Finish gently. You've made time for you." : "Keep the momentum going.")
                        .font(.system(size: 11.5 * scale))
                        .foregroundStyle(IllustratedStyle.muted)
                }
                Spacer(minLength: 6)
                Button { showsRoutine = true } label: {
                    HStack(spacing: 7) {
                        Text("View routine")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 10 * scale))
                    .foregroundStyle(IllustratedStyle.muted)
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background(.white.opacity(0.65), in: Capsule())
                    .overlay { Capsule().stroke(IllustratedStyle.muted.opacity(0.20), lineWidth: 0.8) }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(remaining.prefix(2).enumerated()), id: \.element.id) { offset, step in
                HStack(spacing: 13 * scale) {
                    Text("\(active.currentStepIndex + offset + 2)")
                        .font(.system(size: 13 * scale))
                        .foregroundStyle(IllustratedStyle.muted)
                        .frame(width: 24 * scale, height: 24 * scale)
                        .overlay { Circle().stroke(IllustratedStyle.muted.opacity(0.35), lineWidth: 0.7) }
                    Image(systemName: step.illustratedSymbol)
                        .font(.system(size: 23 * scale))
                        .foregroundStyle(offset == 0 ? Color(red: 0.39, green: 0.43, blue: 0.58) : IllustratedStyle.green)
                        .frame(width: 42 * scale, height: 42 * scale)
                        .background(offset == 0 ? IllustratedStyle.lavender : IllustratedStyle.sage, in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title)
                            .font(.system(size: 15 * scale, weight: .semibold, design: .serif))
                        Text("\(step.illustratedSubtitle)  •  \(step.shortDuration)")
                            .font(.system(size: 10 * scale))
                            .foregroundStyle(IllustratedStyle.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12 * scale)
                .frame(width: 286 * scale, height: 54 * scale, alignment: .leading)
                .background(.white.opacity(0.79), in: Capsule())
            }
        }
        .padding(.horizontal, 23 * scale)
        .padding(.top, 8 * scale)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottomTrailing) {
            ZStack(alignment: .bottomTrailing) {
                IllustratedWave(crest: 0.08, trough: 0.05)
                    .fill(LinearGradient(colors: [IllustratedStyle.mist.opacity(0.66), IllustratedStyle.sage.opacity(0.55)], startPoint: .leading, endPoint: .trailing))
                    .padding(.top, -20)
                IllustratedFoliage().frame(width: 71 * scale, height: 112 * scale).offset(x: 14, y: 29)
                Text("Progress\nlives in\nthe little\nthings.")
                    .font(.custom("SnellRoundhand", size: 12 * scale))
                    .foregroundStyle(IllustratedStyle.green.opacity(0.67))
                    .rotationEffect(.degrees(-13))
                    .offset(x: -25 * scale, y: -48 * scale)
                    .accessibilityHidden(true)
            }
        }
    }

    private var routineOutline: some View {
        NavigationStack {
            List {
                if let active = model.state.activeRoutine {
                    ForEach(Array(model.runningSteps.enumerated()), id: \.element.id) { index, step in
                        HStack {
                            Image(systemName: active.outcomes[index] == .completed ? "checkmark.circle.fill" : active.outcomes[index] == .skipped ? "forward.circle" : index == active.currentStepIndex ? "play.circle.fill" : "circle")
                                .foregroundStyle(IllustratedStyle.green)
                            VStack(alignment: .leading) {
                                Text(step.title)
                                if !model.runningPlan[index].path.isEmpty {
                                    Text(model.runningPlan[index].path.joined(separator: " › "))
                                        .font(.caption).foregroundStyle(IllustratedStyle.green)
                                }
                                Text(step.shortDuration).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if index == active.currentStepIndex { Text("Current").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .navigationTitle(model.activeRoutine?.title ?? "Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsRoutine = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var rescheduleSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Come back at", selection: $returnDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                Section {
                    Text("Your progress and remaining timer will be saved. The return time appears on Today; no notification will be sent. Continue whenever you're ready.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Make a little space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showsSchedule = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        showsSchedule = false
                        model.rescheduleRoutine(to: returnDate)
                    }
                    .disabled(returnDate <= Date())
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private extension RoutineStep {
    var shortDuration: String {
        guard let seconds = estimatedDurationSeconds, seconds > 0 else { return "Your pace" }
        return "\(max(1, Int(ceil(Double(seconds) / 60)))) min"
    }
}

#Preview {
    RoutineRunnerView().environment({
        let model = AppModel.preview
        if let routine = model.activeRoutines.first { model.begin(routine) }
        return model
    }())
}
