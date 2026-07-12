import SwiftUI

struct CurriculumSelectionView: View {
    let store: PlanoraStore

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 28)

            VStack(alignment: .leading, spacing: 10) {
                Text(L("选择课程体系", "Choose Curriculum"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.planoraInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L("之后可以随时调整。", "You can change this later."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            VStack(spacing: 14) {
                ForEach(Curriculum.allCases) { curriculum in
                    CurriculumCard(
                        curriculum: curriculum,
                        isSelected: store.curriculum == curriculum
                    ) {
                        store.selectCurriculum(curriculum)
                    }
                }
            }
            .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)

            Spacer()

            PlanoraPrimaryButton(title: L("继续", "Continue"), systemImage: "arrow.right") {
                store.showSubjectSelection()
            }
            .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
            .padding(.bottom, 22)
        }
    }
}

struct CurriculumCard: View {
    let curriculum: Curriculum
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassPanel(interactive: true) {
                HStack(spacing: 16) {
                    Image(systemName: curriculum.symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(curriculum.tint)
                        .frame(width: 54, height: 54)
                        .background(curriculum.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(curriculum.title)
                            .font(.headline)
                            .foregroundStyle(Color.planoraInk)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(curriculum.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? curriculum.tint : Color.secondary.opacity(0.45))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: PlanoraTheme.cardCornerRadius, style: .continuous)
                    .stroke(isSelected ? curriculum.tint.opacity(0.75) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.012 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isSelected)
    }
}
