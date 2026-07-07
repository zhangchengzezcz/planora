import SwiftUI

struct DashboardSection<Content: View>: View {
    let title: String
    let trailing: String?
    let content: Content

    init(title: String, trailing: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.planoraInk)

                Spacer()

                if let trailing {
                    Text(trailing)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            GlassPanel(padding: 0) {
                content
            }
        }
    }
}

struct ProgressSubjectRow: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }

            ProgressView(value: value)
                .tint(tint)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.planoraBlue)
                .frame(width: 38, height: 38)
                .background(Color.planoraBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.planoraInk)

            Spacer()

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
