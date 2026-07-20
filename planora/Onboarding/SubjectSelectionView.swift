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
                        Text(String(localized: "Choose Subjects"))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.planoraInk)

                        Text(String(localized: "Select what you are studying now."))
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
                        Text(String(localized: "Extra Learning"))
                            .font(.headline)
                            .foregroundStyle(Color.planoraInk)

                        ExtraLearningPicker(store: store, columns: columns)
                    }

                    PlanoraPrimaryButton(
                        title: String(localized: "Finish"),
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
