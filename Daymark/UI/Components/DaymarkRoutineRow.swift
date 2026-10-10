import SwiftUI

struct DaymarkRoutineRow: View {
    var eyebrow: String
    var title: String
    var detail: String
    var duration: String
    var completedSteps: Int
    var totalSteps: Int
    var symbol: String = "sun.max.fill"
    var isActive: Bool = false
    var actionTitle: String = "Begin"
    var onStart: () -> Void

    private var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return min(max(Double(completedSteps) / Double(totalSteps), 0), 1)
    }

    var body: some View {
        DaymarkEditorialSurface(
            tint: isActive ? DaymarkTheme.ColorToken.sageWash : DaymarkTheme.ColorToken.surface
        ) {
            VStack(alignment: .leading, spacing: DaymarkTheme.Spacing.large) {
                HStack(alignment: .top, spacing: DaymarkTheme.Spacing.medium) {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DaymarkTheme.ColorToken.moss)
                        .frame(width: 42, height: 42)
                        .background(DaymarkTheme.ColorToken.canvas.opacity(0.72), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(eyebrow.uppercased())
                            .font(DaymarkTheme.Typography.overline)
                            .tracking(1)
                            .foregroundStyle(DaymarkTheme.ColorToken.fern)

                        Text(title)
                            .font(DaymarkTheme.Typography.title)
                            .foregroundStyle(DaymarkTheme.ColorToken.ink)

                        Text(detail)
                            .font(DaymarkTheme.Typography.callout)
                            .foregroundStyle(DaymarkTheme.ColorToken.inkMuted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: DaymarkTheme.Spacing.small)

                    Text(duration)
                        .font(DaymarkTheme.Typography.caption)
                        .foregroundStyle(DaymarkTheme.ColorToken.inkMuted)
                }

                HStack(spacing: DaymarkTheme.Spacing.medium) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(completedSteps) of \(totalSteps) steps")
                                .font(DaymarkTheme.Typography.caption)
                                .foregroundStyle(DaymarkTheme.ColorToken.inkMuted)

                            Spacer()

                            Text(progress, format: .percent.precision(.fractionLength(0)))
                                .font(DaymarkTheme.Typography.caption)
                                .foregroundStyle(DaymarkTheme.ColorToken.moss)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(DaymarkTheme.ColorToken.moss.opacity(0.12))

                                Capsule()
                                    .fill(DaymarkTheme.ColorToken.moss)
                                    .frame(width: proxy.size.width * progress)
                            }
                        }
                        .frame(height: 5)
                        .animation(DaymarkTheme.Motion.gentle, value: progress)
                    }

                    Button(actionTitle, action: onStart)
                        .font(DaymarkTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(DaymarkTheme.ColorToken.surfaceRaised)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(DaymarkTheme.ColorToken.moss, in: Capsule())
                        .buttonStyle(.plain)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
