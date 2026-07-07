import SwiftUI

struct PlanoraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient.planoraSurface

            LinearGradient(
                colors: [
                    Color.white.opacity(0.64),
                    Color.planoraBlue.opacity(0.08),
                    Color.planoraGreen.opacity(0.11)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
