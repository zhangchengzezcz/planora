import SwiftData
import SwiftUI

#if os(macOS)
struct MacHomeView: View {
    let store: PlanoraStore
    let createTask: () -> Void

    var body: some View {
        NavigationStack {
            HomeDashboardView(store: store, onCreateRequested: createTask)
                .frame(maxWidth: 1040)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct MacCompactTaskRow: View {
    let task: PlanoraTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.type.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).lineLimit(1)
                Text(PlanoraFormat.subjectDisplayName(task.subject))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let date = task.plannedDate ?? task.deadline {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
#endif
