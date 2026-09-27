#if os(macOS)
import SwiftUI

struct MacModePicker<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let title: String
    let label: (Value) -> String
    let symbol: (Value) -> String
    var showsLabels = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Value?

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(values, id: \.self) { value in
                    Group {
                        if reduceTransparency {
                            control(value).buttonStyle(.bordered)
                                .tint(selection == value ? .accentColor : .secondary)
                        } else {
                            control(value).buttonStyle(.glass(selection == value ? .regular.tint(.accentColor) : .regular))
                        }
                    }
                    .focused($focused, equals: value)
                    .accessibilityLabel(label(value))
                    .accessibilityAddTraits(selection == value ? [.isSelected] : [])
                    .help(label(value))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .onMoveCommand { direction in
            guard let index = values.firstIndex(of: selection) else { return }
            let delta = direction == .left ? -1 : direction == .right ? 1 : 0
            let next = index + delta
            guard delta != 0, values.indices.contains(next) else { return }
            select(values[next])
            focused = values[next]
        }
    }

    private func control(_ value: Value) -> some View {
        Button { select(value) } label: {
            if showsLabels {
                Text(label(value)).frame(minWidth: 32, minHeight: 22)
            } else {
                Image(systemName: symbol(value)).frame(width: 24, height: 22)
            }
        }
        .controlSize(.regular)
    }

    private func select(_ value: Value) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { selection = value }
    }
}
#endif
