import SwiftUI

struct PlanoraBackground: View {
    @Environment(\.planoraAppearance) private var appearance

    var body: some View {
        ZStack {
            appearance.backgroundStyle.swatch

            LinearGradient(
                colors: [
                    .planoraSurfaceOverlayTop,
                    appearance.accent.color.opacity(0.09),
                    .planoraSurfaceOverlayGreen.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
