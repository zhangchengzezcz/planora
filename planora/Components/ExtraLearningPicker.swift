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
        .alert(L("自定义额外学习", "Custom Extra Learning"), isPresented: $isShowingCustomEntry) {
            TextField(L("例如：艺术作品集", "For example: Art Portfolio"), text: $customTitle)

            Button(L("添加", "Add")) {
                store.addCustomExtraLearning(customTitle)
                customTitle = ""
            }

            Button(L("取消", "Cancel"), role: .cancel) {
                customTitle = ""
            }
        } message: {
            Text(L("输入要加入学习空间的项目。", "Enter an item to add to your learning space."))
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
        .alert(L("自定义科目", "Custom Subject"), isPresented: $isShowingCustomEntry) {
            TextField(L("例如：Astronomy", "For example: Astronomy"), text: $customTitle)

            Button(L("添加", "Add")) {
                store.addCustomSubject(customTitle)
                customTitle = ""
            }

            Button(L("取消", "Cancel"), role: .cancel) {
                customTitle = ""
            }
        } message: {
            Text(L("输入要加入科目列表的名称。", "Enter a subject name to add to your subject list."))
        }
    }
}
