import SwiftUI

/// A light code-drawn botanical detail used as punctuation, never decoration behind text.
struct DaymarkBotanicalAccent: View {
    enum Direction {
        case leading
        case trailing
    }

    var tint: Color = DaymarkTheme.ColorToken.fern
    var direction: Direction = .leading

    var body: some View {
        BotanicalBranch()
            .stroke(tint, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
            .overlay {
                leaves
            }
            .scaleEffect(x: direction == .leading ? 1 : -1, y: 1)
            .accessibilityHidden(true)
    }

    private var leaves: some View {
        ZStack {
            leaf(width: 16, height: 7, rotation: -30, x: -17, y: 13)
            leaf(width: 15, height: 7, rotation: 28, x: 5, y: 1)
            leaf(width: 14, height: 6, rotation: -29, x: -4, y: -12)
            leaf(width: 11, height: 5, rotation: 24, x: 16, y: -24)
        }
    }

    private func leaf(
        width: CGFloat,
        height: CGFloat,
        rotation: Double,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        Capsule(style: .continuous)
            .fill(tint.opacity(0.76))
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: y)
    }
}

private struct BotanicalBranch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 7, y: rect.maxY - 4))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 8, y: rect.minY + 5),
            control1: CGPoint(x: rect.midX - 11, y: rect.midY + 17),
            control2: CGPoint(x: rect.midX + 6, y: rect.midY - 12)
        )

        path.move(to: CGPoint(x: rect.midX - 11, y: rect.midY + 10))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 8, y: rect.midY + 4),
            control: CGPoint(x: rect.midX - 18, y: rect.midY + 2)
        )

        path.move(to: CGPoint(x: rect.midX + 2, y: rect.midY - 4))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 5, y: rect.midY - 13),
            control: CGPoint(x: rect.midX + 9, y: rect.midY - 10)
        )
        return path
    }
}
