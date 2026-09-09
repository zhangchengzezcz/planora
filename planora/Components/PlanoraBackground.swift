import SwiftUI

struct PlanoraBackground: View {
    @Environment(\.planoraAppearance) private var appearance

    var body: some View {
#if os(iOS)
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
#else
        Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
#endif
    }
}
