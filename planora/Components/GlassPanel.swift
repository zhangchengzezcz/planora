import SwiftUI

struct GlassPanel<Content: View>: View {
    let padding: CGFloat
    let cornerRadius: CGFloat
    let tint: Color
    let interactive: Bool
    let content: Content

    init(
        padding: CGFloat = 20,
        cornerRadius: CGFloat = PlanoraTheme.cardCornerRadius,
        tint: Color = Color.white.opacity(0.16),
        interactive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.interactive = interactive
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .background(tint.opacity(0.34), in: shape)
            .glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.56), lineWidth: 1))
            .shadow(color: Color.planoraInk.opacity(0.08), radius: 24, x: 0, y: 12)
    }
}
