import SwiftUI

// MARK: - Extra Learning

struct ExtraLearningPicker: View {
    let store: PlanoraStore
    let columns: [GridItem]

    @State private var isShowingCustomEntry = false
    @State private var customTitle = ""

    private var options: [String] {
        SubjectLibrary.extraLearning + store.customExtraLearningTitles
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(options, id: \.self) { item in
                let isCustomTrigger = item == SubjectLibrary.customExtraLearningTrigger

                SelectableChip(
                    title: PlanoraFormat.subjectDisplayName(item),
                    isSelected: !isCustomTrigger && store.selectedExtraLearning.contains(item)
                ) {
                    if isCustomTrigger {
                        isShowingCustomEntry = true
                    } else {
                        store.toggleExtraLearning(item)
                    }
                }
            }
        }
        .alert(String(localized: "Custom Extra Learning"), isPresented: $isShowingCustomEntry) {
            TextField(String(localized: "For example: Art Portfolio"), text: $customTitle)

            Button(String(localized: "Add")) {
                store.addCustomExtraLearning(customTitle)
                customTitle = ""
            }

            Button(String(localized: "Cancel"), role: .cancel) {
                customTitle = ""
            }
        } message: {
            Text(String(localized: "Enter an item to add to your learning space."))
        }
    }
}

// MARK: - Subjects

struct SubjectPicker: View {
    let store: PlanoraStore
    let columns: [GridItem]

    @State private var isShowingCustomEntry = false
    @State private var customTitle = ""

    private var options: [SubjectOption] {
        SubjectLibrary.subjects(for: store.curriculum) +
        store.customSubjectTitles.map(SubjectOption.init(title:)) +
        [SubjectOption(title: SubjectLibrary.customSubjectTrigger)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(options) { subject in
                let isCustomTrigger = subject.title == SubjectLibrary.customSubjectTrigger
                let isRequired = SubjectLibrary.isRequiredSubject(subject.title, for: store.curriculum)

                SelectableChip(
                    title: PlanoraFormat.subjectDisplayName(subject.title),
                    isSelected: !isCustomTrigger && store.selectedSubjects.contains(subject.title),
                    isLocked: !isCustomTrigger && isRequired
                ) {
                    if isCustomTrigger {
                        isShowingCustomEntry = true
                    } else {
                        store.toggleSubject(subject.title)
                    }
                }
            }
        }
        .alert(String(localized: "Custom Subject"), isPresented: $isShowingCustomEntry) {
            TextField(String(localized: "For example: Astronomy"), text: $customTitle)

            Button(String(localized: "Add")) {
                store.addCustomSubject(customTitle)
                customTitle = ""
            }

            Button(String(localized: "Cancel"), role: .cancel) {
                customTitle = ""
            }
        } message: {
            Text(String(localized: "Enter a subject name to add to your subject list."))
        }
    }
}
