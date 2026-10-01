# Mac Glass Controls / Mac 玻璃控件

## Shared Components / 统一组件

- `MacModePicker` is the single implementation for horizontal mode switching.
- `PlanoraSegmentedPicker` uses it on Mac and keeps the native segmented Picker on iOS/iPadOS.
- `PlanoraChoicePicker` preserves the standard Picker on Mac; it is not a horizontal mode switch.
- 只对横向模式切换应用本文的玻璃方案。普通按钮、菜单、选择项和页面必须保留原有材质与颜色：原本无玻璃的不添加玻璃，原本有玻璃的不重设 tint、渐变或阴影。不得把 `.buttonStyle(.glass)` 扩散到所有控件。

## macOS 27

Use `NSSegmentedControl.role = .tabs`, `.controlSize = .large`, `.borderShape = .capsule`, `.segmentStyle = .automatic`, and `.trackingMode = .selectOne`.
Also set SwiftUI `.controlSize(.large)` on the representable so its environment does not override the AppKit size.
The coordinator updates the SwiftUI binding. Do not rewrite `selectedSegment` when it already matches the binding.

这是用户确认过的原生效果。按下、横向拖动、透明玻璃和静止材质的过渡交给系统；不要添加 SwiftUI 手势、延时或第二层玻璃覆盖原生控件。
`.valueSelection` is not interchangeable: it produces the blue value-selection appearance, not this tab appearance.
There is no exposed transition-duration setting in the reviewed public segmented-control API. Do not use private selectors.

## macOS 26

The `.tabs` role is available only on macOS 27. Keep the availability gate and the existing compatible glass implementation on macOS 26. Do not claim the two render identically without runtime verification.

## Verification / 验证

Check light/dark appearance, selection binding, disabled state, horizontal dragging, keyboard/accessibility behavior and fixed layout size. Reuse `MacGlassControlTests` and `MacTaskLayoutTests`.
Do not ship standalone probe applications or screenshots as project/release assets. Release attachments remain DMG, ZIP and SHA256SUMS only.

## Apple References / 官方参考

- https://developer.apple.com/documentation/appkit/nssegmentedcontrol/role-swift.enum/tabs
- https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass
- https://developer.apple.com/documentation/swiftui/pickerstyle/segmented
