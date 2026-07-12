import SwiftUI

struct FeatureIntroView: View {
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let topContentInset = max(76, proxy.safeAreaInsets.top + 36)
            let buttonInset = PlanoraTheme.pageHorizontalPadding

            VStack(spacing: 0) {
                VStack(spacing: 34) {
                    VStack(spacing: 16) {
                        PlanoraLogoMark(size: 74)

                        VStack(spacing: 10) {
                            Text(L("欢迎使用 Planora", "Welcome to Planora"))
                                .planoraFont(.system(size: 34, weight: .bold))
                                .foregroundStyle(Color.planoraInk)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(L("为 IB 与 IGCSE 学生准备的学习规划工具。先选择课程和科目，之后主页会帮你看清任务、进度与重要日期。", "A study planner for IB and IGCSE students. Choose your curriculum and subjects first, then the home page helps you see tasks, progress, and important dates clearly."))
                                .planoraFont(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 22) {
                        ForEach(PlanoraFeature.samples) { feature in
                            IntroFeatureRow(feature: feature)
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, topContentInset)

                Spacer(minLength: 18)

                PlanoraPrimaryButton(title: L("开始使用", "Get Started"), systemImage: "arrow.right", action: onContinue)
                    .padding(.horizontal, buttonInset)
                    .padding(.top, 8)
                    .padding(.bottom, buttonInset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }
}

private struct IntroFeatureRow: View {
    let feature: PlanoraFeature

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.symbol)
                .planoraFont(.title3.weight(.semibold))
                .foregroundStyle(feature.tint)
                .frame(width: 46, height: 46)
                .background(feature.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(feature.title)
                    .planoraFont(.headline)
                    .foregroundStyle(Color.planoraInk)

                Text(feature.description)
                    .planoraFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
