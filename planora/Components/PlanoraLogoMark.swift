import SwiftUI

struct PlanoraLogoMark: View {
    @Environment(\.colorScheme) private var colorScheme
    let size: CGFloat

    var body: some View {
        Image(colorScheme == .dark ? "PlanoraBrandDark" : "PlanoraBrandLight", bundle: .main)
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: size * 0.10, x: 0, y: size * 0.05)
        .accessibilityLabel(Text(verbatim: "Planora"))
    }
}
