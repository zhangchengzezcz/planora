#if os(macOS)
import AppKit
import SwiftUI

struct MacModePicker<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let title: String
    let label: (Value) -> String
    let symbol: (Value) -> String
    var showsLabels = false

    var body: some View {
        NativeMacModePicker(selection: $selection, values: values, title: title,
                            label: label, symbol: symbol, showsLabels: showsLabels)
            .controlSize(.large)
    }
}

private struct NativeMacModePicker<Value: Hashable>: NSViewRepresentable {
    @Binding var selection: Value
    let values: [Value]
    let title: String
    let label: (Value) -> String
    let symbol: (Value) -> String
    var showsLabels = false

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.controlSize = .large
        control.segmentStyle = .automatic
        control.borderShape = .capsule
        control.segmentDistribution = .fillEqually
        control.trackingMode = .selectOne
        control.prefersCompactControlSizeMetrics = false
        if #available(macOS 27, *) {
            control.role = .valueSelection
        }
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        updateNSView(control, context: context)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        let configuration = values.map { label($0) + "|" + (showsLabels ? "" : symbol($0)) }
        if context.coordinator.configuration != configuration {
            control.segmentCount = values.count
            for (index, value) in values.enumerated() {
                control.setWidth(showsLabels ? 82 : 52, forSegment: index)
                control.setToolTip(label(value), forSegment: index)
                if showsLabels {
                    control.setImage(nil, forSegment: index)
                    control.setLabel(label(value), forSegment: index)
                } else {
                    let image = NSImage(systemSymbolName: symbol(value), accessibilityDescription: label(value))
                    image?.isTemplate = true
                    control.setLabel("", forSegment: index)
                    control.setImage(image, forSegment: index)
                    control.setImageScaling(.scaleProportionallyDown, forSegment: index)
                }
            }
            context.coordinator.configuration = configuration
        }
        control.setAccessibilityLabel(title)
        let index = values.firstIndex(of: selection) ?? -1
        if control.selectedSegment != index { control.selectedSegment = index }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSegmentedControl, context: Context) -> CGSize? {
        CGSize(width: CGFloat(values.count) * (showsLabels ? 82 : 52), height: 38)
    }

    final class Coordinator: NSObject {
        var parent: NativeMacModePicker
        var configuration: [String] = []
        init(parent: NativeMacModePicker) { self.parent = parent }

        @objc func changed(_ control: NSSegmentedControl) {
            guard parent.values.indices.contains(control.selectedSegment) else { return }
            parent.selection = parent.values[control.selectedSegment]
        }
    }
}
#endif
