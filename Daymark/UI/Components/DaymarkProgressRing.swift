import SwiftUI

struct DaymarkProgressRing: View {
    var progress: Double
    var valueText: String
    var caption: String? = nil
    var diameter: CGFloat = 88
    var lineWidth: CGFloat = 7
    var tint: Color = DaymarkTheme.ColorToken.moss

    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(valueText)
                    .font(DaymarkTheme.Typography.metric)
                    .foregroundStyle(DaymarkTheme.ColorToken.ink)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                if let caption {
                    Text(caption.uppercased())
                        .font(DaymarkTheme.Typography.overline)
                        .tracking(0.7)
                        .foregroundStyle(DaymarkTheme.ColorToken.inkMuted)
                        .lineLimit(1)
                }
            }
            .padding(lineWidth + 3)
        }
        .frame(width: diameter, height: diameter)
        .animation(DaymarkTheme.Motion.gentle, value: normalizedProgress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption ?? "Progress")
        .accessibilityValue(Text(valueText))
    }
}
