import SwiftUI

struct UserNameEntryView: View {
    let store: PlanoraStore

    @State private var nameDraft: String
    @FocusState private var isNameFocused: Bool

    init(store: PlanoraStore) {
        self.store = store
        _nameDraft = State(initialValue: store.userName)
    }

    private var trimmedName: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 52)

            VStack(spacing: 14) {
                PlanoraLogoMark(size: 72)

                VStack(spacing: 8) {
                    Text(String(localized: "What should we call you?"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)
                        .multilineTextAlignment(.center)

                    Text(String(localized: "This name will appear on your home page."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)

            GlassPanel(padding: 18) {
                TextField(String(localized: "Your name"), text: $nameDraft)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
                    .textFieldStyle(.plain)
                    .focused($isNameFocused)
                    .onSubmit(continueToCurriculum)
                    .padding(.horizontal, 2)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)

            Spacer()

            PlanoraPrimaryButton(
                title: String(localized: "Continue"),
                systemImage: "arrow.right",
                isDisabled: !canContinue,
                action: continueToCurriculum
            )
            .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
            .padding(.bottom, 22)
        }
        .task {
            isNameFocused = true
        }
    }

    private func continueToCurriculum() {
        guard canContinue else { return }
        store.updateUserName(trimmedName)
        store.showCurriculumSelection()
    }
}

#Preview {
    UserNameEntryView(store: .previewOnboarding)
        .background(PlanoraBackground())
}
