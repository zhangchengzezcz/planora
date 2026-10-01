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
            #if os(macOS)
            .foregroundStyle(Color.planoraOnAccent)
            #else
            .foregroundStyle(Color.planoraInk)
            #endif
            .frame(maxWidth: .infinity, minHeight: 56)
            #if os(macOS)
            .background {
                shape.fill(LinearGradient.planoraAccent)
                    .opacity(isDisabled ? 0.36 : 0.74)
            }
            .glassEffect(.regular.tint(Color.planoraBlue.opacity(isDisabled ? 0.12 : 0.24))
                .interactive(!isDisabled), in: shape)
            #else
            .glassEffect(
                .regular
                    .tint(Color.planoraBlue.opacity(isDisabled ? 0.04 : 0.10))
                    .interactive(!isDisabled),
                in: shape
            )
            #endif
            .overlay(
                shape
                    .stroke(Color.planoraButtonStroke.opacity(isDisabled ? 0.48 : 1), lineWidth: 1)
            )
            #if os(macOS)
            .shadow(color: Color.planoraBlue.opacity(isDisabled ? 0.08 : 0.22), radius: 18, x: 0, y: 10)
            #endif
            .opacity(isDisabled ? 0.45 : 1)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    var isLocked = false
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.bold))
                }
            }
            #if os(macOS)
            .foregroundStyle(isSelected ? Color.planoraOnAccent : Color.planoraInk)
            #else
            .foregroundStyle(Color.planoraInk)
            #endif
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 12)
            #if os(macOS)
            .background(isSelected ? Color.planoraBlue : Color.planoraControlFill, in: Capsule())
            #else
            .glassEffect(.regular.tint(isSelected ? Color.planoraBlue.opacity(0.12) : .clear).interactive(), in: Capsule())
            #endif
            .overlay(
                Capsule()
                    #if os(macOS)
                    .stroke(isSelected ? Color.clear : Color.planoraControlStroke, lineWidth: 1)
                    #else
                    .stroke(isSelected ? Color.planoraBlue.opacity(0.3) : Color.planoraControlStroke, lineWidth: 1)
                    #endif
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? String(localized: "Selected") : String(localized: "Not Selected"))
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
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 1))
    }
}
