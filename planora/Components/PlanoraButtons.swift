import SwiftUI

struct PlanoraPrimaryButton: View {
    let title: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        let shape = Capsule()

        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                shape
                    .fill(LinearGradient.planoraAccent)
                    .opacity(isDisabled ? 0.36 : 0.74)
            }
            .glassEffect(
                .regular
                    .tint(Color.planoraBlue.opacity(isDisabled ? 0.12 : 0.24))
                    .interactive(!isDisabled),
                in: shape
            )
            .overlay(
                shape
                    .stroke(Color.white.opacity(isDisabled ? 0.16 : 0.34), lineWidth: 1)
            )
            .shadow(color: Color.planoraBlue.opacity(isDisabled ? 0.08 : 0.22), radius: 18, x: 0, y: 10)
            .opacity(isDisabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(isSelected ? Color.white : Color.planoraInk)
            .frame(maxWidth: .infinity, minHeight: 42)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.planoraBlue : Color.white.opacity(0.6), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MiniStatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.1), in: Capsule())
    }
}
