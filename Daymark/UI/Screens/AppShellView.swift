import Combine
import SwiftUI

enum AppTab: Hashable {
    case today
    case routines
    case habits
    case insights
    case settings
}

@MainActor
struct LegacyAppShellView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .today
    @AppStorage("daymark.appearance") private var appearance = "System"
    private let dayClock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var model = model

        TabView(selection: $selection) {
            NavigationStack { TodayView(browseRoutines: { selection = .routines }, browseHabits: { selection = .habits }) }
                .tag(AppTab.today)
                .toolbar(.hidden, for: .tabBar)
            NavigationStack { RoutinesView() }
                .tag(AppTab.routines)
                .toolbar(.hidden, for: .tabBar)
            NavigationStack { HabitsView() }
                .tag(AppTab.habits)
                .toolbar(.hidden, for: .tabBar)
            NavigationStack { InsightsView() }
                .tag(AppTab.insights)
                .toolbar(.hidden, for: .tabBar)
            NavigationStack { SettingsView() }
                .tag(AppTab.settings)
                .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DaymarkTabBar(selection: $selection)
        }
        .tint(Color(red: 0.165, green: 0.405, blue: 0.333))
        .preferredColorScheme(preferredColorScheme)
        .fullScreenCover(isPresented: $model.isRunnerPresented) {
            RoutineRunnerView()
                .environment(model)
        }
        .onReceive(dayClock) { _ in
            model.refreshDay()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refreshDay()
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "Light": .light
        case "Dark": .dark
        default: nil
        }
    }
}

private struct DaymarkTabBar: View {
    @Binding var selection: AppTab
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private let items: [(tab: AppTab, title: String)] = [
        (.today, "Today"),
        (.routines, "Routines"),
        (.habits, "Habits"),
        (.insights, "Insights"),
        (.settings, "Settings")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                Button {
                    selection = item.tab
                } label: {
                    VStack(spacing: 5) {
                        ReferenceTabIcon(tab: item.tab, isSelected: selection == item.tab)
                            .frame(width: 22, height: 22)

                        Text(item.title)
                            .font(.system(size: 10, weight: selection == item.tab ? .medium : .regular))
                    }
                    .foregroundStyle(
                        selection == item.tab
                            ? Color(red: 0.16, green: 0.39, blue: 0.22)
                            : Color(red: 0.49, green: 0.51, blue: 0.56)
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item.tab ? .isSelected : [])
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 7)
        .padding(.bottom, 0)
        .background {
            GeometryReader { geometry in
                let shape = UnevenRoundedRectangle(topLeadingRadius: 17, topTrailingRadius: 17)
                ZStack {
                    shape.fill(.regularMaterial)
                    shape.fill(
                        colorScheme == .dark
                            ? Color(white: 0.12).opacity(reduceTransparency ? 1 : 0.85)
                            : Color(red: 0.986, green: 0.988, blue: 0.980).opacity(reduceTransparency ? 1 : 0.94)
                    )
                }
                .frame(height: geometry.size.height + geometry.safeAreaInsets.bottom)
                .shadow(color: .black.opacity(0.018), radius: 10, y: -3)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

/// Selected tabs fill the icon itself; inactive tabs retain the reference's outline.
private struct ReferenceTabIcon: View {
    let tab: AppTab
    let isSelected: Bool

    var body: some View {
        if tab == .settings {
            Image(systemName: isSelected ? "gearshape.fill" : "gearshape")
                .resizable()
                .scaledToFit()
                .fontWeight(.light)
        } else if isSelected && tab == .routines {
            ReferenceTabFill(tab: tab)
                .fill(style: FillStyle(eoFill: true))
        } else {
            ReferenceTabPath(tab: tab)
                .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .background {
                    if isSelected {
                        ReferenceTabFill(tab: tab).fill()
                    }
                }
        }
    }
}

private struct ReferenceTabPath: Shape {
    let tab: AppTab

    func path(in rect: CGRect) -> Path {
        var path = Path()
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width / 24, y: rect.minY + y * rect.height / 24)
        }

        switch tab {
        case .today:
            path.addEllipse(in: CGRect(x: p(6, 6).x, y: p(6, 6).y, width: rect.width / 2, height: rect.height / 2))
            for index in 0..<8 {
                let angle = Double(index) * .pi / 4
                path.move(to: p(12 + CGFloat(cos(angle)) * 9, 12 + CGFloat(sin(angle)) * 9))
                path.addLine(to: p(12 + CGFloat(cos(angle)) * 11.5, 12 + CGFloat(sin(angle)) * 11.5))
            }
        case .routines:
            path.addRoundedRect(in: CGRect(x: p(4, 2).x, y: p(4, 2).y, width: rect.width * 16 / 24, height: rect.height * 20 / 24), cornerSize: CGSize(width: 2, height: 2))
            for y: CGFloat in [7, 12, 17] {
                path.move(to: p(8, y))
                path.addLine(to: p(16, y))
            }
        case .habits:
            path.move(to: p(12, 23))
            path.addQuadCurve(to: p(13, 11), control: p(10, 17))
            path.addCurve(to: p(23, 2), control1: p(13, 4), control2: p(18, 2))
            path.addCurve(to: p(13, 14), control1: p(24, 11), control2: p(19, 14))
            path.move(to: p(12, 19))
            path.addCurve(to: p(1, 7), control1: p(4, 20), control2: p(1, 15))
            path.addCurve(to: p(11, 18), control1: p(8, 7), control2: p(12, 11))
            path.move(to: p(6, 13))
            path.addLine(to: p(12, 20))
        case .insights:
            for (x, y): (CGFloat, CGFloat) in [(4, 13), (10.5, 2), (17, 6)] {
                path.addRoundedRect(in: CGRect(x: p(x, y).x, y: p(x, y).y, width: rect.width * 2.6 / 24, height: rect.height * (22 - y) / 24), cornerSize: CGSize(width: 0.9, height: 0.9))
            }
        case .settings:
            break
        }
        return path
    }
}

/// Closed interior shapes are separate from the outline's open stems, rays and text lines.
private struct ReferenceTabFill: Shape {
    let tab: AppTab

    func path(in rect: CGRect) -> Path {
        var path = Path()
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width / 24, y: rect.minY + y * rect.height / 24)
        }

        switch tab {
        case .today:
            path.addEllipse(in: CGRect(origin: p(6, 6), size: CGSize(width: rect.width / 2, height: rect.height / 2)))
        case .routines:
            // Match the outline's outside edge, with transparent cutouts for the page's lines.
            path.addRoundedRect(in: CGRect(origin: p(3.25, 1.25), size: CGSize(width: rect.width * 17.5 / 24, height: rect.height * 21.5 / 24)),
                                cornerSize: CGSize(width: rect.width * 2.75 / 24, height: rect.height * 2.75 / 24))
            for y: CGFloat in [7, 12, 17] {
                path.addRoundedRect(in: CGRect(origin: p(7.5, y - 0.75), size: CGSize(width: rect.width * 9 / 24, height: rect.height * 1.5 / 24)),
                                    cornerSize: CGSize(width: rect.width * 0.75 / 24, height: rect.height * 0.75 / 24))
            }
        case .habits:
            path.move(to: p(13, 11))
            path.addCurve(to: p(23, 2), control1: p(13, 4), control2: p(18, 2))
            path.addCurve(to: p(13, 14), control1: p(24, 11), control2: p(19, 14))
            path.closeSubpath()
            path.move(to: p(12, 19))
            path.addCurve(to: p(1, 7), control1: p(4, 20), control2: p(1, 15))
            path.addCurve(to: p(11, 18), control1: p(8, 7), control2: p(12, 11))
            path.closeSubpath()
        case .insights:
            return ReferenceTabPath(tab: tab).path(in: rect)
        case .settings:
            break // Uses the matching filled SF Symbol.
        }
        return path
    }
}

#Preview {
    AppShellView()
        .environment(AppModel.preview)
        .environment(AccountModel(isUITesting: true))
}
