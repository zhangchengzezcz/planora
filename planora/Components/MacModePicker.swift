#if os(macOS)
import SwiftUI
import AppKit

struct MacModePicker<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let title: String
    let label: (Value) -> String
    let symbol: (Value) -> String
    var showsLabels = false

    var body: some View {
        if #available(macOS 27, *) {
            MacNativeModePicker(selection: $selection, values: values, title: title,
                label: label, symbol: symbol, showsLabels: showsLabels)
                .controlSize(.large)
                .frame(width: MacModePickerGeometry.totalWidth(labels: values.map(label), showsLabels: showsLabels), height: 38)
        } else {
            MacGlassModePicker(selection: $selection, values: values, title: title,
                label: label, symbol: symbol, showsLabels: showsLabels)
        }
    }
}

@available(macOS 27, *)
struct MacNativeModePicker<Value: Hashable>: NSViewRepresentable {
    @Binding var selection: Value
    let values: [Value]
    let title: String
    let label: (Value) -> String
    let symbol: (Value) -> String
    let showsLabels: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.role = .tabs
        control.controlSize = .large
        control.borderShape = .capsule
        control.segmentStyle = .automatic
        control.trackingMode = .selectOne
        control.segmentDistribution = .fit
        control.target = context.coordinator
        control.action = #selector(Coordinator.selectionChanged(_:))
        configure(control)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        configure(control)
    }

    private func configure(_ control: NSSegmentedControl) {
        if control.segmentCount != values.count { control.segmentCount = values.count }
        for (index, value) in values.enumerated() {
            let caption = label(value)
            control.setLabel(showsLabels ? caption : "", forSegment: index)
            control.setImage(showsLabels ? nil : NSImage(systemSymbolName: symbol(value),
                accessibilityDescription: caption), forSegment: index)
            control.setToolTip(caption, forSegment: index)
            control.setWidth(MacModePickerGeometry.segmentWidth(labels: [caption], showsLabels: showsLabels), forSegment: index)
        }
        let index = values.firstIndex(of: selection) ?? -1
        // Leave native tracking and material transitions untouched on unrelated view updates.
        if control.selectedSegment != index { control.selectedSegment = index }
        control.isEnabled = isEnabled
        control.setAccessibilityLabel(title)
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: MacNativeModePicker
        init(_ parent: MacNativeModePicker) { self.parent = parent }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            guard sender.isEnabled, parent.values.indices.contains(sender.selectedSegment) else { return }
            parent.selection = parent.values[sender.selectedSegment]
        }
    }
}

private struct MacGlassModePicker<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let title: String
    let label: (Value) -> String
    let symbol: (Value) -> String
    var showsLabels = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pointerX: CGFloat?
    @State private var dragOffset: CGFloat = 0
    @State private var isSettling = false
    @State private var hasAppeared = false

    private var width: CGFloat { CGFloat(values.count) * MacModePickerGeometry.segmentWidth(labels: values.map(label), showsLabels: showsLabels) }
    private var selectedIndex: Int { values.firstIndex(of: selection) ?? 0 }
    private var isGlassActive: Bool { pointerX != nil || isSettling }

    var body: some View {
        GlassEffectContainer {
            GeometryReader { geometry in
                let segmentWidth = geometry.size.width / CGFloat(max(1, values.count))
                let offset = lensOffset(segmentWidth: segmentWidth, width: geometry.size.width)
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary.opacity(0.65))
                    if !values.isEmpty {
                        Color.clear
                            .frame(width: max(0, segmentWidth - 6), height: isGlassActive ? 36 : 32,
                                   alignment: .leading)
                            .overlay {
                                if !isGlassActive {
                                    modeLabel(values[selectedIndex]).foregroundStyle(.primary)
                                }
                            }
                            .background {
                                Capsule().fill(.regularMaterial).opacity(isGlassActive ? 0 : 1)
                                    .animation(reduceMotion || isGlassActive ? nil : .smooth(duration: 0.18),
                                               value: isGlassActive)
                            }
                            .glassEffect(isGlassActive ? .clear.interactive() : .identity, in: Capsule())
                            .offset(x: offset)
                            .animation(reduceMotion ? nil : (pointerX == nil
                                ? .spring(duration: 0.65, bounce: 0.08)
                                : .interactiveSpring(response: 0.24, dampingFraction: 0.86)),
                                       value: pointerX)
                            .accessibilityHidden(true)
                    }
                    HStack(spacing: 0) {
                        ForEach(Array(values.enumerated()), id: \.element) { index, value in
                            Button { select(index) } label: {
                                modeLabel(value)
                                .foregroundStyle(index == selectedIndex ? .primary : .secondary)
                                .opacity(!isGlassActive && index == selectedIndex ? 0 : 1)
                                .frame(width: segmentWidth, height: 38)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(label(value))
                            .accessibilityLabel(label(value))
                            .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                        }
                    }
                }
                .contentShape(Capsule())
                .highPriorityGesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        if pointerX == nil {
                            let startIndex = MacModePickerGeometry.index(at: value.startLocation.x,
                                width: geometry.size.width, count: values.count)
                            dragOffset = startIndex == selectedIndex
                                ? (CGFloat(selectedIndex) + 0.5) * segmentWidth - value.startLocation.x : 0
                        }
                        pointerX = value.location.x + dragOffset
                    }
                    .onEnded { value in
                        guard isEnabled else { pointerX = nil; return }
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.65, bounce: 0.08)) {
                            if let index = MacModePickerGeometry.index(at: value.location.x + dragOffset,
                                width: geometry.size.width, count: values.count) {
                                select(index)
                            }
                            pointerX = nil
                        }
                    })
                .animation(pointerX == nil && !reduceMotion ? .smooth(duration: 0.65) : nil,
                           value: selectedIndex)
            }
        }
        .frame(width: width, height: 38)
        .opacity(isEnabled ? 1 : 0.5)
        .task(id: selection) {
            guard hasAppeared else { hasAppeared = true; return }
            isSettling = true
            do {
                try await Task.sleep(for: .milliseconds(950))
            } catch {
                return
            }
            isSettling = false
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(selectedIndex + 1)
            case .decrement: select(selectedIndex - 1)
            @unknown default: break
            }
        }
        .focusable()
        .onKeyPress(.leftArrow) { select(selectedIndex - 1); return .handled }
        .onKeyPress(.rightArrow) { select(selectedIndex + 1); return .handled }
    }

    @ViewBuilder
    private func modeLabel(_ value: Value) -> some View {
        if showsLabels {
            Text(label(value)).font(.system(size: 13, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.65)
        } else {
            Image(systemName: symbol(value)).font(.system(size: 17, weight: .medium))
        }
    }

    private func lensOffset(segmentWidth: CGFloat, width: CGFloat) -> CGFloat {
        guard let pointerX else { return CGFloat(selectedIndex) * segmentWidth + 3 }
        return min(max(3, pointerX - segmentWidth / 2 + 3), max(3, width - segmentWidth + 3))
    }

    private func select(_ index: Int) {
        guard isEnabled, values.indices.contains(index) else { return }
        guard selection != values[index] else { return }
        isSettling = true
        selection = values[index]
    }
}

enum MacModePickerGeometry {
    static func totalWidth(labels: [String], showsLabels: Bool) -> CGFloat {
        labels.reduce(0) { $0 + segmentWidth(labels: [$1], showsLabels: showsLabels) }
    }

    static func segmentWidth(labels: [String], showsLabels: Bool) -> CGFloat {
        guard showsLabels else { return 52 }
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .large), weight: .semibold)
        let widest = labels.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return max(82, ceil(widest) + 32)
    }

    static func index(at x: CGFloat, width: CGFloat, count: Int) -> Int? {
        guard count > 0, width > 0, width.isFinite, x.isFinite else { return nil }
        let boundedX = min(max(0, x), width)
        return min(count - 1, Int(boundedX / width * CGFloat(count)))
    }
}
#endif
