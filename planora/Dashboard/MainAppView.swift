import SwiftUI

struct MainAppView: View {
    @Bindable var store: PlanoraStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            Tab("首页", systemImage: "house.fill", value: MainTab.home) {
                NavigationStack {
                    HomeDashboardView(store: store)
                }
            }

            Tab("新建", systemImage: "plus", value: MainTab.create, role: .prominent) {
                NavigationStack {
                    CreateTaskView(store: store)
                }
            }

            Tab("我的", systemImage: "person.fill", value: MainTab.profile) {
                NavigationStack {
                    ProfileView(store: store)
                }
            }
        }
        .tint(Color.planoraDeepGreen)
        .background(PlanoraBackground())
    }
}
