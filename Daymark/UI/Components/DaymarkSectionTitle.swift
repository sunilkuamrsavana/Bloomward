import SwiftUI

struct DaymarkSectionTitle: View {
    var eyebrow: String? = nil
    var title: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: DaymarkTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: DaymarkTheme.Spacing.xSmall) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(DaymarkTheme.Typography.overline)
                        .tracking(1.2)
                        .foregroundStyle(DaymarkTheme.ColorToken.fern)
                }

                Text(title)
                    .font(DaymarkTheme.Typography.section)
                    .foregroundStyle(DaymarkTheme.ColorToken.ink)

                if let detail {
                    Text(detail)
                        .font(DaymarkTheme.Typography.callout)
                        .foregroundStyle(DaymarkTheme.ColorToken.inkMuted)
                }
            }

            Spacer(minLength: DaymarkTheme.Spacing.small)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(DaymarkTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(DaymarkTheme.ColorToken.moss)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
