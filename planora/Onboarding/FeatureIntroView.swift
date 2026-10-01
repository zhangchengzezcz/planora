import SwiftUI

struct FeatureIntroView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    let onContinue: () -> Void

    var body: some View {
        let copy = OnboardingCopy(locale: locale)
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 20) {
                    PlanoraLogoMark(size: 84)
                    Text(verbatim: "Planora")
                        .font(.system(size: 36, weight: .bold))
                    Text(copy.introduction)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 26) {
                    IntroFeatureRow(symbol: "checklist", title: copy.tasksTitle, detail: copy.tasksDetail)
                    IntroFeatureRow(symbol: "books.vertical", title: copy.coursesTitle, detail: copy.coursesDetail)
                    IntroFeatureRow(symbol: "person.crop.circle.badge.checkmark", title: copy.attendanceTitle, detail: copy.attendanceDetail)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlanoraPrimaryButton(title: String(localized: "Get Started"), systemImage: "arrow.right", action: onContinue)
                .frame(maxWidth: 520)
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(OnboardingBrand.background(for: colorScheme))
        }
        .background(OnboardingBrand.background(for: colorScheme).ignoresSafeArea())
    }
}

private struct IntroFeatureRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(OnboardingBrand.accent(for: colorScheme))
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
