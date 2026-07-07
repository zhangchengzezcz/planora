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
                    Text("怎么称呼你？")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.planoraInk)
                        .multilineTextAlignment(.center)

                    Text("这个名字会显示在主页。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)

            GlassPanel(padding: 18) {
                TextField("你的名字", text: $nameDraft)
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
                title: "继续",
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
