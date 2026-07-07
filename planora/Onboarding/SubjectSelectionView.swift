import SwiftUI

struct SubjectSelectionView: View {
    let store: PlanoraStore

    private let columns = [
        GridItem(.adaptive(minimum: 136), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("选择科目")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.planoraInk)

                    Text("先选正在学习的内容。")
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

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                            ForEach(SubjectLibrary.subjects(for: store.curriculum)) { subject in
                                SelectableChip(
                                    title: subject.title,
                                    isSelected: store.selectedSubjects.contains(subject.title)
                                ) {
                                    store.toggleSubject(subject.title)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("额外学习")
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(SubjectLibrary.extraLearning, id: \.self) { item in
                            SelectableChip(
                                title: item,
                                isSelected: store.selectedExtraLearning.contains(item)
                            ) {
                                store.toggleExtraLearning(item)
                            }
                        }
                    }
                }

                PlanoraPrimaryButton(
                    title: "完成",
                    systemImage: "sparkles",
                    isDisabled: store.selectedSubjects.isEmpty
                ) {
                    store.createLearningSpace()
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
    }
}
