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
        tint: Color = .planoraGlassTint,
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

#if os(iOS)
        content
            .padding(padding)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
#else
        content
            .padding(padding)
            .background(Color(nsColor: .controlBackgroundColor), in: shape)
            .overlay(shape.stroke(.separator.opacity(0.35), lineWidth: 0.5))
#endif
    }
}
