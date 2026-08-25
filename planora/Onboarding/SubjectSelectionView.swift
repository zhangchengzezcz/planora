import SwiftData
import SwiftUI

struct SubjectSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanoraCourse.displayName) private var importedCourses: [PlanoraCourse]
    @State private var manageBacFlow: ManageBacFlow?
    @State private var suggestedCurriculum: Curriculum?
    @State private var isShowingCurriculumSuggestion = false

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

                    HStack(spacing: 12) {
                        Button {
                            manageBacFlow = .connect
                        } label: {
                            OnboardingSubjectMethod(
                                title: String(localized: "Import from ManageBac"),
                                subtitle: String(localized: "Read courses and tasks"),
                                symbol: "building.columns.fill",
                                tint: .planoraBlue
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            manageBacFlow = nil
                        } label: {
                            OnboardingSubjectMethod(
                                title: String(localized: "Choose Manually"),
                                subtitle: String(localized: "Select subjects below"),
                                symbol: "hand.tap.fill",
                                tint: store.curriculum.tint
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text(String(localized: "Subjects"))
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

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
        .fullScreenCover(item: $manageBacFlow) { flow in
            ManageBacConnectionFlowView(store: store, flow: flow) { snapshot in
                manageBacFlow = nil
                handleManageBacCompletion(snapshot)
            } onCancel: {
                manageBacFlow = nil
            }
        }
        .alert(
            String(localized: "Update Curriculum?"),
            isPresented: $isShowingCurriculumSuggestion,
            presenting: suggestedCurriculum
        ) { curriculum in
            Button("\(String(localized: "Switch Curriculum")) · \(curriculum.badge)") {
                applyImportedCurriculum(curriculum)
                store.createLearningSpace()
            }
            Button(String(localized: "Keep Current Curriculum")) {
                store.createLearningSpace()
            }
        } message: { curriculum in
            Text(String(localized: "ManageBac suggests a different curriculum. Review the suggestion before changing your Planora learning space."))
        }
    }

    private func handleManageBacCompletion(_ snapshot: ManageBacConnectionSnapshot) {
        guard let detected = snapshot.detectedCurriculum,
              detected != store.curriculum,
              snapshot.detectionConfidence != .low else {
            store.createLearningSpace()
            return
        }
        suggestedCurriculum = detected
        isShowingCurriculumSuggestion = true
    }

    private func applyImportedCurriculum(_ curriculum: Curriculum) {
        let names = importedCourses
            .filter { $0.externalSource == .manageBac && !$0.isArchived }
            .map(\.displayName)
        store.selectCurriculum(curriculum)
        for name in names { store.addCustomSubject(name) }
    }
}

private struct OnboardingSubjectMethod: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        GlassPanel(padding: 16, interactive: true) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.planoraInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        }
    }
}
