import SwiftUI

/// A restrained surface for information that needs separation from the page.
/// Most rows should remain unboxed; reserve this for featured content.
struct DaymarkEditorialSurface<Content: View>: View {
    private let content: Content
    private let tint: Color
    private let inset: CGFloat

    init(
        tint: Color = DaymarkTheme.ColorToken.surface,
        inset: CGFloat = DaymarkTheme.Spacing.large,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.inset = inset
        self.content = content()
    }

    var body: some View {
        content
            .padding(inset)
            .background(tint, in: RoundedRectangle(cornerRadius: DaymarkTheme.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DaymarkTheme.Radius.large, style: .continuous)
                    .stroke(DaymarkTheme.ColorToken.hairline, lineWidth: 0.75)
            }
            .shadow(color: DaymarkTheme.ColorToken.shadow, radius: 18, y: 8)
    }
}
