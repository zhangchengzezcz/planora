import SwiftUI

struct WelcomeView: View {
    let onComplete: () -> Void

    @State private var logoVisible = false
    @State private var textVisible = false
    @State private var lifted = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            PlanoraLogoMark(size: 104)
                .scaleEffect(logoVisible ? 1 : 0.78)
                .opacity(logoVisible ? 1 : 0)
                .offset(y: lifted ? -26 : 0)

            VStack(spacing: 8) {
                Text(L("欢迎使用", "Welcome to"))
                    .planoraFont(.title3.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Planora")
                    .planoraFont(.system(size: 48, weight: .bold))
                    .foregroundStyle(Color.planoraInk)
            }
            .opacity(textVisible ? 1 : 0)
            .offset(y: lifted ? -26 : 0)

            Spacer()

            Text(L("学习计划，简单清晰。", "Study planning, simple and clear."))
                .planoraFont(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .opacity(textVisible ? 0.75 : 0)
                .padding(.bottom, 36)
        }
        .padding(.horizontal, 28)
        .task {
            await runWelcomeAnimation()
        }
    }

    @MainActor
    private func runWelcomeAnimation() async {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
            logoVisible = true
        }
        try? await Task.sleep(for: .milliseconds(520))

        withAnimation(.easeOut(duration: 0.58)) {
            textVisible = true
        }
        try? await Task.sleep(for: .milliseconds(1_150))

        withAnimation(.spring(response: 0.64, dampingFraction: 0.82)) {
            lifted = true
        }
        try? await Task.sleep(for: .milliseconds(430))

        onComplete()
    }
}
