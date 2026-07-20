import SwiftUI

struct PlanoraLogoMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.planoraGlassFill)
                .glassEffect(.regular.tint(Color.planoraGlassTint), in: Circle())

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.86), Color.planoraBlue.opacity(0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(size * 0.025, 1)
                )

            VStack(spacing: -size * 0.08) {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.2, weight: .semibold))
                    .foregroundStyle(Color.planoraGreen)

                Text(verbatim: "P")
                    .font(.system(size: size * 0.46, weight: .black, design: .rounded))
                    .foregroundStyle(Color.planoraBlue)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.planoraBlue.opacity(0.24), radius: size * 0.26, x: 0, y: size * 0.12)
        .accessibilityLabel(Text(verbatim: "Planora"))
    }
}
