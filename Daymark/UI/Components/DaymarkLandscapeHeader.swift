import SwiftUI

enum IllustratedStyle {
    static let paper = Color(red: 0.982, green: 0.983, blue: 0.970)
    static let ink = Color(red: 0.035, green: 0.065, blue: 0.135)
    static let muted = Color(red: 0.44, green: 0.49, blue: 0.56)
    static let green = Color(red: 0.19, green: 0.39, blue: 0.33)
    static let sage = Color(red: 0.89, green: 0.94, blue: 0.90)
    static let mist = Color(red: 0.90, green: 0.95, blue: 0.96)
    static let lavender = Color(red: 0.91, green: 0.90, blue: 0.96)
    static let sand = Color(red: 0.99, green: 0.95, blue: 0.87)
    static let blush = Color(red: 0.98, green: 0.91, blue: 0.89)
    static let button = LinearGradient(colors: [Color(red: 0.33, green: 0.53, blue: 0.45), green], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// These shapes are layout masks, so every label and control remains native and accessible.
struct IllustratedWave: Shape {
    var crest: CGFloat = 0.18
    var trough: CGFloat = 0.55

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveHeight = min(rect.height, 110)
        path.move(to: CGPoint(x: 0, y: waveHeight * crest))
        path.addCurve(to: CGPoint(x: rect.width, y: waveHeight * trough),
                      control1: CGPoint(x: rect.width * 0.30, y: -waveHeight * 0.25),
                      control2: CGPoint(x: rect.width * 0.65, y: waveHeight * 1.05))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct IllustratedScenery: View {
    var alignment: Alignment = .top

    var body: some View {
        GeometryReader { geometry in
            Image("MorningLandscape")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
                .saturation(0.70)
                .contrast(0.82)
                .overlay(.white.opacity(0.06))
                .clipped()
        }
        .accessibilityHidden(true)
    }
}

struct IllustratedPageBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                IllustratedStyle.paper
                IllustratedWave(crest: 0.1, trough: 0.2)
                    .fill(LinearGradient(colors: [IllustratedStyle.mist.opacity(0.8), IllustratedStyle.sage.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: geometry.size.height * 0.62)
                    .offset(y: geometry.size.height * 0.35)
                IllustratedWave(crest: 0.2, trough: 0.1)
                    .fill(.white.opacity(0.62))
                    .frame(height: geometry.size.height * 0.40)
                    .offset(y: geometry.size.height * 0.58)
                IllustratedWave(crest: 0.5, trough: 0.04)
                    .fill(IllustratedStyle.sage.opacity(0.56))
                    .frame(height: geometry.size.height * 0.38)
                    .offset(y: geometry.size.height * 0.76)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PaintedLeaf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.1, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: 0), control1: CGPoint(x: -rect.width * 0.35, y: rect.height * 0.25), control2: CGPoint(x: rect.width * 0.75, y: rect.height * 0.3))
        path.addCurve(to: CGPoint(x: rect.width * 0.1, y: rect.maxY), control1: CGPoint(x: rect.width * 1.1, y: rect.height * 0.73), control2: CGPoint(x: rect.width * 0.55, y: rect.height * 0.96))
        return path
    }
}

struct IllustratedFoliage: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width, y: height))
                    path.addQuadCurve(to: CGPoint(x: width * 0.70, y: height * 0.05), control: CGPoint(x: width * 0.74, y: height * 0.48))
                }
                .stroke(IllustratedStyle.green.opacity(0.48), lineWidth: 1.4)
                ForEach(0..<8) { index in
                    let isLeft = index.isMultiple(of: 2)
                    PaintedLeaf()
                        .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.66, blue: 0.51), IllustratedStyle.green.opacity(0.80)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay {
                            Path { path in
                                path.move(to: CGPoint(x: width * 0.045, y: height * 0.23))
                                path.addLine(to: CGPoint(x: width * 0.38, y: height * 0.02))
                            }.stroke(.white.opacity(0.18), lineWidth: 0.65)
                        }
                        .frame(width: width * 0.45, height: height * 0.25)
                        .rotationEffect(.degrees(isLeft ? -63 : 18))
                        .position(x: width * (isLeft ? 0.57 : 0.92), y: height * (0.16 + Double(index) * 0.115))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DaymarkLandscapeHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var eyebrow: String
    var title: String
    var subtitle: String
    var progress: Double
    var progressText: String
    var progressCaption: String = "today"

    var body: some View {
        ZStack(alignment: .topLeading) {
            landscape

            headerContent
            .padding(.horizontal, DaymarkTheme.Spacing.page)
            .padding(.top, DaymarkTheme.Spacing.xLarge)
            .padding(.bottom, DaymarkTheme.Spacing.xLarge)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 360 : 258)
        .clipShape(RoundedRectangle(cornerRadius: DaymarkTheme.Radius.large, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            DaymarkBotanicalAccent(tint: DaymarkTheme.ColorToken.moss.opacity(0.62), direction: .trailing)
                .frame(width: 70, height: 86)
                .padding(.trailing, 12)
                .padding(.bottom, -7)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var headerContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DaymarkTheme.Spacing.large) {
                copy
                progressRing
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: DaymarkTheme.Spacing.large) {
                copy
                Spacer(minLength: 0)
                progressRing
            }
        }
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: DaymarkTheme.Spacing.small) {
            Text(eyebrow.uppercased())
                .font(DaymarkTheme.Typography.overline)
                .tracking(1.35)
                .foregroundStyle(DaymarkTheme.ColorToken.moss.opacity(0.86))

            Text(title)
                .font(DaymarkTheme.Typography.hero)
                .foregroundStyle(DaymarkTheme.ColorToken.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(DaymarkTheme.Typography.callout)
                .foregroundStyle(DaymarkTheme.ColorToken.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var progressRing: some View {
        DaymarkProgressRing(
            progress: progress,
            valueText: progressText,
            caption: progressCaption,
            diameter: 78,
            lineWidth: 6
        )
    }

    private var landscape: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        DaymarkTheme.ColorToken.sky,
                        DaymarkTheme.ColorToken.mist.opacity(0.76),
                        DaymarkTheme.ColorToken.sageWash
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(DaymarkTheme.ColorToken.sun.opacity(0.56))
                    .frame(width: 54, height: 54)
                    .blur(radius: 0.35)
                    .position(x: proxy.size.width * 0.78, y: proxy.size.height * 0.48)

                LandscapeHill(
                    crest: 0.40,
                    leadingHeight: 0.55,
                    trailingHeight: 0.36
                )
                .fill(DaymarkTheme.ColorToken.sage.opacity(0.82))
                .frame(height: proxy.size.height * 0.54)

                LandscapeHill(
                    crest: 0.64,
                    leadingHeight: 0.30,
                    trailingHeight: 0.64
                )
                .fill(DaymarkTheme.ColorToken.fern.opacity(0.70))
                .frame(height: proxy.size.height * 0.40)

                LandscapeHill(
                    crest: 0.26,
                    leadingHeight: 0.38,
                    trailingHeight: 0.28
                )
                .fill(DaymarkTheme.ColorToken.moss.opacity(0.44))
                .frame(height: proxy.size.height * 0.24)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LandscapeHill: Shape {
    var crest: CGFloat
    var leadingHeight: CGFloat
    var trailingHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.height * leadingHeight))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * trailingHeight),
            control1: CGPoint(x: rect.width * crest, y: rect.minY),
            control2: CGPoint(x: rect.width * (crest + 0.17), y: rect.height * 0.94)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Keep the artwork's full height visible; a short, top-aligned crop hides the lake.
struct IllustratedScreenHeader: View {
    let title: String
    let subtitle: String
    let quote: String
    let topInset: CGFloat
    var back: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 42.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let back {
                Button(action: back) {
                    Image(systemName: "chevron.left").font(.title3.weight(.medium))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.94), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
            Text(title)
                .font(.system(size: titleSize, weight: .bold, design: .serif))
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.body).foregroundStyle(IllustratedStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 100)
        }
        .padding(.horizontal, 24)
        .padding(.top, max(topInset, 12) + 12)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, minHeight: back == nil ? 304 : 326, alignment: .topLeading)
        .background {
            GeometryReader { geometry in
                Image("MorningLandscape").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
                    .clipped()
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [IllustratedStyle.paper.opacity(0.5), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    }
            }
            .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            if !typeSize.isAccessibilitySize {
                Text(quote).font(.custom("SnellRoundhand", size: 16))
                    .foregroundStyle(IllustratedStyle.green.opacity(0.78))
                    .multilineTextAlignment(.center).rotationEffect(.degrees(-12))
                    .frame(width: 108)
                    .padding(.trailing, 18)
                    .padding(.top, max(topInset, 12) + (back == nil ? 126 : 158))
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottom) {
            IllustratedWave(crest: 0.48, trough: 0.32)
                .fill(IllustratedStyle.paper)
                .frame(height: 44)
                .allowsHitTesting(false)
        }
        .clipped()
    }
}

/// A shorter landscape for task-focused libraries; keeps the lake without pushing rows offscreen.
struct IllustratedLibraryHeader: View {
    let title: String
    let subtitle: String
    let topInset: CGFloat
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 36.0
    @ScaledMetric(relativeTo: .subheadline) private var subtitleProtection = 78.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: headingSize, weight: .bold, design: .serif))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.subheadline).foregroundStyle(IllustratedStyle.muted)
            Spacer(minLength: 38)
        }
        .padding(.horizontal, 22).padding(.top, max(topInset, 12) + 8).padding(.bottom, 22)
        .frame(maxWidth: .infinity, minHeight: topInset + 150, alignment: .topLeading)
        .background {
            GeometryReader { geometry in
                Image("MorningLandscape").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
                    .clipped()
                    .overlay(alignment: .top) {
                        LinearGradient(stops: [
                            .init(color: IllustratedStyle.paper.opacity(0.98), location: 0),
                            .init(color: IllustratedStyle.paper.opacity(0.90), location: 0.68),
                            .init(color: .clear, location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                        .frame(height: max(topInset, 12) + headingSize + subtitleProtection + 18)
                    }
            }.accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            IllustratedWave(crest: 0.48, trough: 0.32).fill(IllustratedStyle.paper)
                .frame(height: 28).allowsHitTesting(false)
        }.clipped()
    }
}

/// Creation belongs to the current library, not to the app's destination tab bar.
/// A native toolbar keeps the action reachable while the illustrated content scrolls.
struct IllustratedLibraryActions: ViewModifier {
    let addLabel: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: action) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(addLabel)
                    .accessibilityHint("Opens the creation form")
                    .accessibilityIdentifier("library.add")
                }
            }
    }
}

struct IllustratedSectionHeading: View {
    let title: String
    var detail = ""

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                heading.fixedSize()
                if !detail.isEmpty {
                    Spacer(minLength: 0)
                    caption.fixedSize()
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                heading
                if !detail.isEmpty { caption }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heading: some View {
        Text(title).font(.system(.title2, design: .serif, weight: .semibold))
            .accessibilityAddTraits(.isHeader)
    }
    private var caption: some View {
        Text(detail).font(.footnote).foregroundStyle(IllustratedStyle.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct IllustratedCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content.padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28))
    }
}

struct IllustratedActionFooter: View {
    let title: String
    let symbol: String
    var compact = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                if symbol == "plus" { Image(systemName: symbol).font(.title3) }
                Text(title).font(.system(.title3, design: .serif, weight: .semibold))
                if symbol != "plus" { Image(systemName: symbol).font(.title3) }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, compact ? 10 : 16)
            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 56)
            .background(IllustratedStyle.button, in: Capsule())
            .opacity(enabled ? 1 : 0.48)
        }
        .buttonStyle(.plain).disabled(!enabled)
        .padding(.horizontal, compact ? 20 : 32).padding(.top, compact ? 6 : 12).padding(.bottom, compact ? 6 : 14)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [IllustratedStyle.paper.opacity(0.96), IllustratedStyle.paper],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

struct IllustratedScreenBackdrop: View {
    var body: some View {
        IllustratedPageBackdrop()
            .overlay(alignment: .bottomLeading) {
                IllustratedFoliage().frame(width: 80, height: 150)
                    .scaleEffect(x: -1, y: 1).offset(x: -24, y: 20).opacity(0.36)
            }
            .overlay(alignment: .bottomTrailing) {
                IllustratedFoliage().frame(width: 80, height: 150)
                    .offset(x: 20, y: 20).opacity(0.32)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}


struct IllustratedFilterBar<Value: Hashable>: View {
    let items: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                filters
            }
            .scrollIndicators(.hidden)
        } else {
            filters
        }
    }

    private var filters: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button { selection = item } label: {
                    Text(title(item)).font(.subheadline.weight(.medium))
                        .foregroundStyle(selection == item ? .white : IllustratedStyle.muted)
                        .fixedSize(horizontal: typeSize.isAccessibilitySize, vertical: true)
                        .padding(.horizontal, typeSize.isAccessibilitySize ? 20 : 8).padding(.vertical, 12)
                        .frame(maxWidth: typeSize.isAccessibilitySize ? nil : .infinity, minHeight: 44)
                        .background(selection == item ? IllustratedStyle.green : Color(red: 0.93, green: 0.94, blue: 0.96), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
    }
}

struct IllustratedPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 12).frame(minHeight: 44)
            .background(IllustratedStyle.button, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
