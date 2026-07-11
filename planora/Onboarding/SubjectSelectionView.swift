import SwiftUI

struct SubjectSelectionView: View {
    let store: PlanoraStore

    private let columns = [
        GridItem(.adaptive(minimum: 136), spacing: 12)
    ]

    var body: some View {
        GeometryReader { proxy in
            let topPadding: CGFloat = max(28, proxy.safeAreaInsets.top + 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("选择科目", "Choose Subjects"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.planoraInk)

                        Text(L("先选正在学习的内容。", "Select what you are studying now."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: store.curriculum.symbol)
                                    .foregroundStyle(store.curriculum.tint)

                                Text(store.curriculum.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.planoraInk)

                                Spacer()

                                Text(store.curriculum.badge)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(store.curriculum.tint)
                            }

                            SubjectPicker(store: store, columns: columns)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("额外学习", "Extra Learning"))
                            .font(.headline)
                            .foregroundStyle(Color.planoraInk)

                        ExtraLearningPicker(store: store, columns: columns)
                    }

                    PlanoraPrimaryButton(
                        title: L("完成", "Finish"),
                        systemImage: "sparkles",
                        isDisabled: store.selectedSubjects.isEmpty
                    ) {
                        store.createLearningSpace()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height - topPadding, alignment: .top)
                .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, PlanoraTheme.pageHorizontalPadding)
            }
        }
    }
}
