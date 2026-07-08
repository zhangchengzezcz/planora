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
                    CreatePlaceholderView()
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

private struct CreatePlaceholderView: View {
    var body: some View {
        ZStack {
            PlanoraBackground()

            VStack(spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(LinearGradient.planoraAccent)

                Text("新建")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.planoraInk)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
        }
        .planoraHiddenNavigationBar()
    }
}
