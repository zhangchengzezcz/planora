import SwiftUI

struct PlanoraChoicePicker<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let title: String
    let label: (Value) -> String

    var body: some View {
        Menu {
            ForEach(values, id: \.self) { value in
                Button { selection = value } label: {
                    if selection == value { Label(label(value), systemImage: "checkmark") }
                    else { Text(label(value)) }
                }
            }
        } label: {
            Text(label(selection)).lineLimit(1)
        }
        .buttonStyle(.glass)
        .tint(.primary)
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
    }
}
