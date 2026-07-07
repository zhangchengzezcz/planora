import SwiftUI

struct ContentView: View {
    @State private var store = PlanoraStore()

    var body: some View {
        PlanoraRootView(store: store)
    }
}

private struct PlanoraRootView: View {
    let store: PlanoraStore

    var body: some View {
        ZStack {
            PlanoraBackground()

            Group {
                switch store.phase {
                case .welcome:
                    WelcomeView {
                        store.showFeatureIntro()
                    }
                case .features:
                    FeatureIntroView {
                        store.showNameEntry()
                    }
                case .name:
                    UserNameEntryView(store: store)
                case .curriculum:
                    CurriculumSelectionView(store: store)
                case .subjects:
                    SubjectSelectionView(store: store)
                case .dashboard:
                    MainAppView(store: store)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
        .animation(.smooth(duration: 0.35), value: store.phase)
    }
}

#Preview("Fresh Launch") {
    ContentView()
}

#Preview("Dashboard") {
    PlanoraRootView(store: .previewDashboard)
}
