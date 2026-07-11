import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum PlanoraTheme {
    static let pageHorizontalPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 28
    static let compactCornerRadius: CGFloat = 18
}

extension Color {
    nonisolated static var planoraInk: Color {
        planoraDynamic(
            light: Color(red: 0.08, green: 0.11, blue: 0.16),
            dark: Color(red: 0.92, green: 0.95, blue: 0.98)
        )
    }

    nonisolated static var planoraBlue: Color {
        planoraDynamic(
            light: Color(red: 0.18, green: 0.43, blue: 0.93),
            dark: Color(red: 0.42, green: 0.65, blue: 1.0)
        )
    }

    nonisolated static var planoraGreen: Color {
        planoraDynamic(
            light: Color(red: 0.10, green: 0.64, blue: 0.52),
            dark: Color(red: 0.28, green: 0.82, blue: 0.70)
        )
    }

    nonisolated static var planoraDeepGreen: Color {
        planoraDynamic(
            light: Color(red: 0.02, green: 0.42, blue: 0.36),
            dark: Color(red: 0.46, green: 0.88, blue: 0.80)
        )
    }

    nonisolated static var planoraAmber: Color {
        planoraDynamic(
            light: Color(red: 0.92, green: 0.55, blue: 0.16),
            dark: Color(red: 1.0, green: 0.72, blue: 0.30)
        )
    }

    nonisolated static var planoraMist: Color {
        planoraDynamic(
            light: Color(red: 0.96, green: 0.99, blue: 1.0),
            dark: Color(red: 0.05, green: 0.07, blue: 0.10)
        )
    }

    nonisolated static var planoraPaper: Color {
        planoraDynamic(
            light: Color(red: 1.0, green: 0.98, blue: 0.94),
            dark: Color(red: 0.10, green: 0.10, blue: 0.13)
        )
    }

    nonisolated static var planoraSurfaceMid: Color {
        planoraDynamic(
            light: Color(red: 0.91, green: 0.97, blue: 0.96),
            dark: Color(red: 0.07, green: 0.11, blue: 0.14)
        )
    }

    nonisolated static var planoraGlassTint: Color {
        planoraDynamic(light: .white.opacity(0.16), dark: .white.opacity(0.10))
    }

    nonisolated static var planoraGlassFill: Color {
        planoraDynamic(light: .white.opacity(0.34), dark: .white.opacity(0.08))
    }

    nonisolated static var planoraGlassStroke: Color {
        planoraDynamic(light: .white.opacity(0.56), dark: .white.opacity(0.18))
    }

    nonisolated static var planoraControlFill: Color {
        planoraDynamic(light: .white.opacity(0.60), dark: .white.opacity(0.11))
    }

    nonisolated static var planoraControlStroke: Color {
        planoraDynamic(light: .white.opacity(0.72), dark: .white.opacity(0.18))
    }

    nonisolated static var planoraTagFill: Color {
        planoraDynamic(light: .white.opacity(0.54), dark: .white.opacity(0.10))
    }

    nonisolated static var planoraButtonStroke: Color {
        planoraDynamic(light: .white.opacity(0.34), dark: .white.opacity(0.24))
    }

    nonisolated static var planoraOnAccent: Color {
        planoraDynamic(
            light: .white,
            dark: Color(red: 0.03, green: 0.06, blue: 0.08)
        )
    }

    nonisolated static var planoraShadow: Color {
        planoraDynamic(light: .planoraInk.opacity(0.08), dark: .black.opacity(0.34))
    }

    nonisolated static var planoraSurfaceOverlayTop: Color {
        planoraDynamic(light: .white.opacity(0.64), dark: .black.opacity(0.10))
    }

    nonisolated static var planoraSurfaceOverlayBlue: Color {
        planoraDynamic(light: .planoraBlue.opacity(0.08), dark: .planoraBlue.opacity(0.14))
    }

    nonisolated static var planoraSurfaceOverlayGreen: Color {
        planoraDynamic(light: .planoraGreen.opacity(0.11), dark: .planoraGreen.opacity(0.12))
    }

#if canImport(UIKit)
    nonisolated private static func planoraDynamic(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
#else
    nonisolated private static func planoraDynamic(light: Color, dark: Color) -> Color {
        light
    }
#endif
}

extension LinearGradient {
    nonisolated static var planoraSurface: LinearGradient {
        LinearGradient(
            colors: [
                .planoraMist,
                .planoraSurfaceMid,
                .planoraPaper
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    nonisolated static var planoraAccent: LinearGradient {
        LinearGradient(
            colors: [.planoraBlue, .planoraGreen],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

extension View {
    @ViewBuilder
    func planoraHiddenNavigationBar() -> some View {
#if os(iOS)
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
#else
        self
#endif
    }

    @ViewBuilder
    func planoraDetailNavigationBar() -> some View {
#if os(iOS)
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
#else
        self
#endif
    }
}
