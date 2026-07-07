import SwiftUI

struct MainAppView: View {
    @Bindable var store: PlanoraStore

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch store.selectedTab {
                case .home:
                    NavigationStack {
                        HomeDashboardView(store: store)
                    }
                case .profile:
                    NavigationStack {
                        ProfileView(store: store)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PlanoraTabBar(selectedTab: $store.selectedTab)
                .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
                .padding(.bottom, 10)
        }
        .background(PlanoraBackground())
    }
}

private struct PlanoraTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        FloatingGlassTabBar(selectedTab: $selectedTab)
    }
}

private struct FloatingGlassTabBar: View {
    @Binding var selectedTab: MainTab

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var isDraggingSelection = false
    @Namespace private var glassNamespace

    private let barHeight: CGFloat = 78
    private let centerGap: CGFloat = 86
    private let centerButtonSize: CGFloat = 70
    private let horizontalInset: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(0, proxy.size.width)
            let tabWidth = max(104, (availableWidth - (horizontalInset * 2) - centerGap) / 2)
            let selectedWidth = min(142, tabWidth + 10)
            let travel = (centerGap / 2) + (tabWidth / 2)
            let baseOffset = selectedTab == .home ? -travel : travel
            let currentOffset = clamped(baseOffset + dragTranslation, lower: -travel, upper: travel)
            let selectedShape = Capsule()

            ZStack {
                GlassEffectContainer(spacing: 12) {
                    ZStack {
                        Capsule()
                            .fill(Color.white.opacity(0.03))
                            .glassEffect(.regular.tint(Color.white.opacity(0.16)), in: Capsule())
                            .glassEffectID("planora-tab-base", in: glassNamespace)
                            .frame(height: barHeight)
                            .shadow(color: Color.planoraInk.opacity(0.10), radius: 24, x: 0, y: 14)

                        selectedShape
                            .fill(Color.planoraInk.opacity(isDraggingSelection ? 0.10 : 0.075))
                            .glassEffect(.regular.tint(Color.planoraInk.opacity(isDraggingSelection ? 0.16 : 0.12)).interactive(), in: selectedShape)
                            .glassEffectID("planora-tab-selection", in: glassNamespace)
                            .glassEffectTransition(.matchedGeometry)
                            .frame(width: selectedWidth, height: 64)
                            .offset(x: currentOffset)
                            .scaleEffect(isDraggingSelection ? 1.045 : 1)
                            .overlay(
                                selectedShape
                                    .stroke(Color.white.opacity(0.46), lineWidth: 0.8)
                            )
                            .shadow(color: Color.planoraInk.opacity(0.22), radius: 20, x: 0, y: 10)
                    }
                }

                HStack(spacing: 0) {
                    FloatingTabItem(
                        title: "首页",
                        systemImage: "house.fill",
                        isSelected: selectedTab == .home
                    )
                    .frame(width: tabWidth)

                    Spacer(minLength: centerGap)

                    FloatingTabItem(
                        title: "我的",
                        systemImage: "person.fill",
                        isSelected: selectedTab == .profile
                    )
                    .frame(width: tabWidth)
                }
                .padding(.horizontal, horizontalInset)

                Button {
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "checklist")
                            .font(.title.weight(.bold))

                        Image(systemName: "plus.circle.fill")
                            .font(.caption.weight(.bold))
                            .background(Color.planoraGreen, in: Circle())
                            .offset(x: 6, y: 4)
                    }
                    .foregroundStyle(.white)
                    .frame(width: centerButtonSize, height: centerButtonSize)
                    .background {
                        Circle()
                            .fill(LinearGradient.planoraAccent)
                            .glassEffect(.regular.tint(Color.planoraGreen.opacity(0.24)).interactive(), in: Circle())
                            .shadow(color: Color.planoraGreen.opacity(0.34), radius: 26, x: 0, y: 12)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(y: -18)
                .accessibilityLabel("Add")
            }
            .contentShape(Capsule())
            .simultaneousGesture(
                selectionDragGesture(
                    travel: travel,
                    availableWidth: availableWidth
                )
            )
        }
        .frame(height: 96)
        .animation(.smooth(duration: 0.32), value: selectedTab)
        .animation(.interactiveSpring(duration: 0.22, extraBounce: 0.10), value: isDraggingSelection)
    }

    private func selectionDragGesture(travel: CGFloat, availableWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.width
            }
            .onChanged { _ in
                isDraggingSelection = true
            }
            .onEnded { value in
                withAnimation(.smooth(duration: 0.26)) {
                    if let destination = destinationTab(
                        for: value,
                        travel: travel,
                        availableWidth: availableWidth
                    ) {
                        selectedTab = destination
                    }
                    isDraggingSelection = false
                }
            }
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func destinationTab(
        for value: DragGesture.Value,
        travel: CGFloat,
        availableWidth: CGFloat
    ) -> MainTab? {
        let movement = hypot(value.translation.width, value.translation.height)

        if movement < 8 {
            let middle = availableWidth / 2
            let centerHitSlop = centerGap / 2

            if value.location.x < middle - centerHitSlop {
                return .home
            }
            if value.location.x > middle + centerHitSlop {
                return .profile
            }

            return nil
        }

        let baseOffset = selectedTab == .home ? -travel : travel
        let finalOffset = baseOffset + value.translation.width
        return finalOffset < 0 ? .home : .profile
    }
}

private struct FloatingTabItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))

            Text(title)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(isSelected ? Color.planoraDeepGreen : Color.planoraInk.opacity(0.58))
        .frame(maxWidth: .infinity, minHeight: 64)
        .contentShape(Capsule())
    }
}
