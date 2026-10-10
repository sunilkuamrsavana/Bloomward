import SwiftUI

enum DaymarkHabitStatus: Equatable {
    case pending
    case completed
    case minimum
    case skipped
    case rest

    var label: String {
        switch self {
        case .pending: "Not completed"
        case .completed: "Completed"
        case .minimum: "Minimum completed"
        case .skipped: "Skipped intentionally"
        case .rest: "Rest day"
        }
    }
}

struct DaymarkHabitRow: View {
    var title: String
    var detail: String
    var symbol: String
    var status: DaymarkHabitStatus
    var trailingText: String? = nil
    var showsDivider: Bool = true
    var onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DaymarkTheme.Spacing.medium) {
                Button(action: onToggle) {
                    statusControl
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityValue(status.label)
                .accessibilityHint(status == .completed ? "Marks as incomplete" : "Marks as complete")

                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DaymarkTheme.ColorToken.moss)
                    .frame(width: 34, height: 34)
                    .background(DaymarkTheme.ColorToken.sageWash, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DaymarkTheme.Typography.rowTitle)
                        .foregroundStyle(DaymarkTheme.ColorToken.ink)
                        .strikethrough(status == .completed, color: DaymarkTheme.ColorToken.inkMuted)

                    Text(detail)
                        .font(DaymarkTheme.Typography.caption)
                        .foregroundStyle(DaymarkTheme.ColorToken.inkMuted)
                }

                Spacer(minLength: DaymarkTheme.Spacing.small)

                if let trailingText {
                    Text(trailingText)
                        .font(DaymarkTheme.Typography.caption)
                        .foregroundStyle(DaymarkTheme.ColorToken.inkMuted)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(DaymarkTheme.ColorToken.surface, in: Capsule())
                }
            }
            .padding(.vertical, DaymarkTheme.Spacing.small)

            if showsDivider {
                Divider()
                    .overlay(DaymarkTheme.ColorToken.hairline)
                    .padding(.leading, 90)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var statusControl: some View {
        switch status {
        case .pending:
            Circle()
                .stroke(DaymarkTheme.ColorToken.fern.opacity(0.58), lineWidth: 1.5)
                .frame(width: 25, height: 25)

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(DaymarkTheme.ColorToken.moss)

        case .minimum:
            ZStack {
                Circle()
                    .fill(DaymarkTheme.ColorToken.sun.opacity(0.28))
                Image(systemName: "leaf.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DaymarkTheme.ColorToken.clay)
            }
            .frame(width: 25, height: 25)

        case .skipped:
            Image(systemName: "minus.circle")
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(DaymarkTheme.ColorToken.inkMuted)

        case .rest:
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(DaymarkTheme.ColorToken.fern)
                .frame(width: 25, height: 25)
        }
    }
}
