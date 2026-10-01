import SwiftUI

struct PlanoraSegmentedPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let title: String
    let label: (Value) -> String

    var body: some View {
        #if os(macOS)
        LabeledContent(title) {
            MacModePicker(selection: $selection, values: values, title: title,
                label: label, symbol: { _ in "circle" }, showsLabels: true)
        }
        #else
        Picker(title, selection: $selection) {
            ForEach(values, id: \.self) { Text(label($0)).tag($0) }
        }
        .pickerStyle(.segmented)
        #endif
    }
}
