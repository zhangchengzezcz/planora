import SwiftUI

struct ProfileView: View {
    let store: PlanoraStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("我的")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.planoraInk)
                    .padding(.top, 18)

                GlassPanel {
                    HStack(spacing: 16) {
                        PlanoraLogoMark(size: 58)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.userName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.planoraInk)

                            Text("\(store.curriculum.badge) learning space")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }

                DashboardSection(title: "Profile") {
                    VStack(spacing: 0) {
                        SettingsRow(icon: "person.crop.circle", title: "Profile", value: store.userName)
                        Divider().padding(.leading, 52)
                        SettingsRow(icon: store.curriculum.symbol, title: "Curriculum", value: store.curriculum.badge)
                        Divider().padding(.leading, 52)
                        SettingsRow(icon: "book.pages", title: "My Subjects", value: "\(store.selectedSubjectTitles.count)")
                        Divider().padding(.leading, 52)
                        SettingsRow(icon: "gearshape", title: "Settings", value: "Default")
                    }
                }

                ChangeCurriculumCard()

                if !store.selectedSubjectTitles.isEmpty {
                    DashboardSection(title: "Current Subjects") {
                        FlowTagList(items: store.selectedSubjectTitles + store.selectedExtraLearningTitles)
                            .padding(18)
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
    }
}

private struct ChangeCurriculumCard: View {
    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.planoraAmber)

                    Text("Change Curriculum")
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

                    Spacer()
                }

                Text("Existing tasks detected.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    MiniStatusPill(title: "Keep data", tint: .planoraBlue)
                    MiniStatusPill(title: "Archive", tint: .planoraGreen)
                    MiniStatusPill(title: "Delete", tint: .red)
                }
            }
        }
    }
}

private struct FlowTagList: View {
    let items: [String]

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.54), in: Capsule())
            }
        }
    }
}
