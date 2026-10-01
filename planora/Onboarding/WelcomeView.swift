import SwiftUI

struct WelcomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onComplete: () -> Void

    @State private var logoVisible = false
    @State private var textVisible = false
    @State private var lifted = false

    var body: some View {
        VStack(spacing: 28) {
            PlanoraLogoMark(size: 116)
                .scaleEffect(logoVisible || reduceMotion ? 1 : 0.92)
                .opacity(logoVisible ? 1 : 0)
            VStack(spacing: 12) {
                Text(verbatim: "Planora")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.primary)
                Text(OnboardingCopy(locale: locale).subtitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(textVisible ? 1 : 0)
        }
        .offset(y: lifted && !reduceMotion ? -10 : 0)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingBrand.background(for: colorScheme).ignoresSafeArea())
        .task { await runWelcomeAnimation() }
    }

    @MainActor
    private func runWelcomeAnimation() async {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.64, dampingFraction: 0.88)) {
            logoVisible = true
        }
        do {
            try await Task.sleep(for: .milliseconds(220))
            withAnimation(.easeOut(duration: 0.45)) { textVisible = true }
            try await Task.sleep(for: .milliseconds(1_200))
            withAnimation(.smooth(duration: 0.5)) { lifted = true }
            try await Task.sleep(for: .milliseconds(400))
        } catch { return }
        guard !Task.isCancelled else { return }
        onComplete()
    }
}
