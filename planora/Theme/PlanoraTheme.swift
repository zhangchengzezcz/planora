import SwiftUI

enum PlanoraTheme {
    static let pageHorizontalPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 28
    static let compactCornerRadius: CGFloat = 18
}

extension Color {
    nonisolated static var planoraInk: Color { Color(red: 0.08, green: 0.11, blue: 0.16) }
    nonisolated static var planoraBlue: Color { Color(red: 0.18, green: 0.43, blue: 0.93) }
    nonisolated static var planoraGreen: Color { Color(red: 0.10, green: 0.64, blue: 0.52) }
    nonisolated static var planoraDeepGreen: Color { Color(red: 0.02, green: 0.42, blue: 0.36) }
    nonisolated static var planoraAmber: Color { Color(red: 0.92, green: 0.55, blue: 0.16) }
    nonisolated static var planoraMist: Color { Color(red: 0.96, green: 0.99, blue: 1.0) }
    nonisolated static var planoraPaper: Color { Color(red: 1.0, green: 0.98, blue: 0.94) }
}

extension LinearGradient {
    nonisolated static var planoraSurface: LinearGradient {
        LinearGradient(
            colors: [
                .planoraMist,
                Color(red: 0.91, green: 0.97, blue: 0.96),
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
}
