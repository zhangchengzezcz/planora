import SwiftUI

struct PlanoraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient.planoraSurface

            LinearGradient(
                colors: [
                    .planoraSurfaceOverlayTop,
                    .planoraSurfaceOverlayBlue,
                    .planoraSurfaceOverlayGreen
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
