import SwiftUI
import UIKit

/// Shared visual tokens for Daymark's quiet, editorial interface.
enum DaymarkTheme {
    enum ColorToken {
        static let canvas = adaptive(
            light: UIColor(red: 0.969, green: 0.949, blue: 0.898, alpha: 1),
            dark: UIColor(red: 0.086, green: 0.094, blue: 0.082, alpha: 1)
        )

        static let surface = adaptive(
            light: UIColor(red: 0.992, green: 0.980, blue: 0.945, alpha: 1),
            dark: UIColor(red: 0.125, green: 0.137, blue: 0.118, alpha: 1)
        )

        static let surfaceRaised = adaptive(
            light: UIColor(red: 1.000, green: 0.992, blue: 0.969, alpha: 1),
            dark: UIColor(red: 0.159, green: 0.171, blue: 0.147, alpha: 1)
        )

        static let ink = adaptive(
            light: UIColor(red: 0.137, green: 0.161, blue: 0.122, alpha: 1),
            dark: UIColor(red: 0.929, green: 0.918, blue: 0.855, alpha: 1)
        )

        static let inkMuted = adaptive(
            light: UIColor(red: 0.360, green: 0.390, blue: 0.333, alpha: 1),
            dark: UIColor(red: 0.694, green: 0.714, blue: 0.655, alpha: 1)
        )

        static let moss = adaptive(
            light: UIColor(red: 0.263, green: 0.365, blue: 0.239, alpha: 1),
            dark: UIColor(red: 0.612, green: 0.714, blue: 0.541, alpha: 1)
        )

        static let fern = adaptive(
            light: UIColor(red: 0.420, green: 0.522, blue: 0.365, alpha: 1),
            dark: UIColor(red: 0.510, green: 0.616, blue: 0.447, alpha: 1)
        )

        static let sage = adaptive(
            light: UIColor(red: 0.741, green: 0.786, blue: 0.667, alpha: 1),
            dark: UIColor(red: 0.286, green: 0.349, blue: 0.251, alpha: 1)
        )

        static let sageWash = adaptive(
            light: UIColor(red: 0.882, green: 0.894, blue: 0.812, alpha: 1),
            dark: UIColor(red: 0.192, green: 0.224, blue: 0.176, alpha: 1)
        )

        static let mist = adaptive(
            light: UIColor(red: 0.769, green: 0.847, blue: 0.843, alpha: 1),
            dark: UIColor(red: 0.247, green: 0.337, blue: 0.337, alpha: 1)
        )

        static let sky = adaptive(
            light: UIColor(red: 0.851, green: 0.902, blue: 0.890, alpha: 1),
            dark: UIColor(red: 0.176, green: 0.247, blue: 0.251, alpha: 1)
        )

        static let sun = adaptive(
            light: UIColor(red: 0.906, green: 0.706, blue: 0.376, alpha: 1),
            dark: UIColor(red: 0.827, green: 0.635, blue: 0.325, alpha: 1)
        )

        static let clay = adaptive(
            light: UIColor(red: 0.690, green: 0.420, blue: 0.318, alpha: 1),
            dark: UIColor(red: 0.765, green: 0.510, blue: 0.396, alpha: 1)
        )

        static let hairline = ink.opacity(0.13)
        static let shadow = Color.black.opacity(0.08)

        private static func adaptive(light: UIColor, dark: UIColor) -> Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            })
        }
    }

    enum Typography {
        static let hero = Font.system(.largeTitle, design: .serif, weight: .semibold)
        static let title = Font.system(.title2, design: .serif, weight: .semibold)
        static let section = Font.system(.title3, design: .serif, weight: .semibold)
        static let rowTitle = Font.system(.body, design: .serif, weight: .semibold)
        static let body = Font.system(.body, design: .default, weight: .regular)
        static let bodyEmphasized = Font.system(.body, design: .default, weight: .semibold)
        static let callout = Font.system(.callout, design: .default, weight: .regular)
        static let caption = Font.system(.caption, design: .default, weight: .medium)
        static let overline = Font.system(.caption2, design: .default, weight: .semibold)
        static let metric = Font.system(.title, design: .serif, weight: .semibold)
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let page: CGFloat = 20
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let capsule: CGFloat = 999
    }

    enum Motion {
        static let gentle = Animation.spring(response: 0.45, dampingFraction: 0.86)
    }
}

extension View {
    func daymarkPageBackground() -> some View {
        background(DaymarkTheme.ColorToken.canvas.ignoresSafeArea())
            .foregroundStyle(DaymarkTheme.ColorToken.ink)
    }
}
