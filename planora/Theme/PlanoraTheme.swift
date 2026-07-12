import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum PlanoraTheme {
    static let pageHorizontalPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 28
    static let compactCornerRadius: CGFloat = 18
}

struct PlanoraAppearanceSettings: Codable, Equatable {
    var displayMode: PlanoraDisplayMode = .system
    var fontStyle: PlanoraFontStyle = .system
    var backgroundStyle: PlanoraBackgroundStyle = .aurora
    var accent: PlanoraAccent = .blue
    var usesChineseFont = false

    static let `default` = PlanoraAppearanceSettings()

    @MainActor var summary: String {
        "\(displayMode.title) · \(backgroundStyle.title)"
    }

    var appliedFontDesign: Font.Design? {
        guard usesChineseFont, PlanoraLocalization.usesChineseLocalization else { return nil }
        return fontStyle.design
    }

    private enum CodingKeys: String, CodingKey {
        case displayMode
        case fontStyle
        case backgroundStyle
        case accent
        case usesChineseFont
    }

    init(
        displayMode: PlanoraDisplayMode = .system,
        fontStyle: PlanoraFontStyle = .system,
        backgroundStyle: PlanoraBackgroundStyle = .aurora,
        accent: PlanoraAccent = .blue,
        usesChineseFont: Bool = false
    ) {
        self.displayMode = displayMode
        self.fontStyle = fontStyle
        self.backgroundStyle = backgroundStyle
        self.accent = accent
        self.usesChineseFont = usesChineseFont
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayMode = try container.decodeIfPresent(PlanoraDisplayMode.self, forKey: .displayMode) ?? .system
        fontStyle = try container.decodeIfPresent(PlanoraFontStyle.self, forKey: .fontStyle) ?? .system
        backgroundStyle = try container.decodeIfPresent(PlanoraBackgroundStyle.self, forKey: .backgroundStyle) ?? .aurora
        accent = try container.decodeIfPresent(PlanoraAccent.self, forKey: .accent) ?? .blue
        usesChineseFont = try container.decodeIfPresent(Bool.self, forKey: .usesChineseFont) ?? false
    }
}

enum PlanoraDisplayMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .system: L("跟随系统", "Follow System")
        case .light: L("浅色", "Light")
        case .dark: L("深色", "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum PlanoraFontStyle: String, Codable, CaseIterable, Identifiable {
    case system
    case rounded
    case serif
    case monospaced

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .system: L("系统", "System")
        case .rounded: L("圆体", "Rounded")
        case .serif: L("宋体", "Songti")
        case .monospaced: L("等宽体", "Monospaced")
        }
    }

    var design: Font.Design? {
        switch self {
        case .system: nil
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }

    static var chineseChoices: [PlanoraFontStyle] { [.rounded, .serif, .monospaced] }

    func previewFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: design ?? .default)
    }
}

enum PlanoraColorTheme: String, CaseIterable, Identifiable {
    case classic
    case ocean
    case forest
    case sunset

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .classic: L("经典", "Classic")
        case .ocean: L("海洋", "Ocean")
        case .forest: L("森林", "Forest")
        case .sunset: L("日落", "Sunset")
        }
    }

    var backgroundStyle: PlanoraBackgroundStyle {
        switch self {
        case .classic: .aurora
        case .ocean: .sky
        case .forest: .mint
        case .sunset: .rose
        }
    }

    var accent: PlanoraAccent {
        switch self {
        case .classic, .ocean: .blue
        case .forest: .green
        case .sunset: .pink
        }
    }

    var swatch: LinearGradient {
        LinearGradient(
            colors: [accent.color.opacity(0.9)] + backgroundStyle.colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func matches(_ settings: PlanoraAppearanceSettings) -> Bool {
        settings.backgroundStyle == backgroundStyle && settings.accent == accent
    }
}

enum PlanoraBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case aurora
    case sky
    case mint
    case rose

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .aurora: L("极光", "Aurora")
        case .sky: L("天空", "Sky")
        case .mint: L("薄荷", "Mint")
        case .rose: L("玫瑰", "Rose")
        }
    }

    var colors: [Color] {
        switch self {
        case .aurora:
            [.planoraMist, .planoraSurfaceMid, .planoraPaper]
        case .sky:
            [.planoraMist, .planoraBlue.opacity(0.20), .planoraPaper]
        case .mint:
            [.planoraMist, .planoraGreen.opacity(0.20), .planoraPaper]
        case .rose:
            [.planoraMist, .pink.opacity(0.16), .planoraPaper]
        }
    }

    var swatch: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum PlanoraAccent: String, Codable, CaseIterable, Identifiable {
    case blue
    case green
    case amber
    case pink

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .blue: L("蓝色", "Blue")
        case .green: L("绿色", "Green")
        case .amber: L("琥珀", "Amber")
        case .pink: L("粉色", "Pink")
        }
    }

    var color: Color {
        switch self {
        case .blue: .planoraBlue
        case .green: .planoraGreen
        case .amber: .planoraAmber
        case .pink: .pink
        }
    }
}

enum PlanoraAppearanceStorage {
    private static let key = "planora.appearance"

    static func load() -> PlanoraAppearanceSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(PlanoraAppearanceSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    static func save(_ settings: PlanoraAppearanceSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct PlanoraAppearanceEnvironmentKey: EnvironmentKey {
    static let defaultValue = PlanoraAppearanceSettings.default
}

extension EnvironmentValues {
    var planoraAppearance: PlanoraAppearanceSettings {
        get { self[PlanoraAppearanceEnvironmentKey.self] }
        set { self[PlanoraAppearanceEnvironmentKey.self] = newValue }
    }
}

struct PlanoraTaskDisplaySettings: Codable, Equatable {
    var density: PlanoraTaskDensity = .comfortable
    var sortOrder: PlanoraTaskSortOrder = .smart
    var showsCompletedTasks = true
    var showsProgressPercentage = true
    var showsNotes = true

    static let `default` = PlanoraTaskDisplaySettings()

    @MainActor var summary: String {
        "\(density.title) · \(sortOrder.title)"
    }
}

enum PlanoraTaskDensity: String, Codable, CaseIterable, Identifiable {
    case comfortable
    case compact

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .comfortable: L("舒适", "Comfortable")
        case .compact: L("紧凑", "Compact")
        }
    }
}

enum PlanoraTaskSortOrder: String, Codable, CaseIterable, Identifiable {
    case smart
    case deadline
    case priority
    case createdDate
    case title

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .smart: L("智能排序", "Smart")
        case .deadline: L("截止日期", "Deadline")
        case .priority: L("优先级", "Priority")
        case .createdDate: L("创建时间", "Created")
        case .title: L("标题", "Title")
        }
    }
}

enum PlanoraTaskDisplayStorage {
    private static let key = "planora.task-display.v1"

    static func load() -> PlanoraTaskDisplaySettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(PlanoraTaskDisplaySettings.self, from: data) else {
            return .default
        }
        return settings
    }

    static func save(_ settings: PlanoraTaskDisplaySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct PlanoraTaskDisplayEnvironmentKey: EnvironmentKey {
    static let defaultValue = PlanoraTaskDisplaySettings.default
}

extension EnvironmentValues {
    var planoraTaskDisplay: PlanoraTaskDisplaySettings {
        get { self[PlanoraTaskDisplayEnvironmentKey.self] }
        set { self[PlanoraTaskDisplayEnvironmentKey.self] = newValue }
    }
}

extension Color {
    nonisolated static var planoraInk: Color {
        planoraDynamic(
            light: Color(red: 0.08, green: 0.11, blue: 0.16),
            dark: Color(red: 0.92, green: 0.95, blue: 0.98)
        )
    }

    nonisolated static var planoraBlue: Color {
        planoraDynamic(
            light: Color(red: 0.18, green: 0.43, blue: 0.93),
            dark: Color(red: 0.42, green: 0.65, blue: 1.0)
        )
    }

    nonisolated static var planoraGreen: Color {
        planoraDynamic(
            light: Color(red: 0.10, green: 0.64, blue: 0.52),
            dark: Color(red: 0.28, green: 0.82, blue: 0.70)
        )
    }

    nonisolated static var planoraDeepGreen: Color {
        planoraDynamic(
            light: Color(red: 0.02, green: 0.42, blue: 0.36),
            dark: Color(red: 0.46, green: 0.88, blue: 0.80)
        )
    }

    nonisolated static var planoraAmber: Color {
        planoraDynamic(
            light: Color(red: 0.92, green: 0.55, blue: 0.16),
            dark: Color(red: 1.0, green: 0.72, blue: 0.30)
        )
    }

    nonisolated static var planoraMist: Color {
        planoraDynamic(
            light: Color(red: 0.96, green: 0.99, blue: 1.0),
            dark: Color(red: 0.05, green: 0.07, blue: 0.10)
        )
    }

    nonisolated static var planoraPaper: Color {
        planoraDynamic(
            light: Color(red: 1.0, green: 0.98, blue: 0.94),
            dark: Color(red: 0.10, green: 0.10, blue: 0.13)
        )
    }

    nonisolated static var planoraSurfaceMid: Color {
        planoraDynamic(
            light: Color(red: 0.91, green: 0.97, blue: 0.96),
            dark: Color(red: 0.07, green: 0.11, blue: 0.14)
        )
    }

    nonisolated static var planoraGlassTint: Color {
        planoraDynamic(light: .white.opacity(0.16), dark: .white.opacity(0.10))
    }

    nonisolated static var planoraGlassFill: Color {
        planoraDynamic(light: .white.opacity(0.34), dark: .white.opacity(0.08))
    }

    nonisolated static var planoraGlassStroke: Color {
        planoraDynamic(light: .white.opacity(0.56), dark: .white.opacity(0.18))
    }

    nonisolated static var planoraControlFill: Color {
        planoraDynamic(light: .white.opacity(0.60), dark: .white.opacity(0.11))
    }

    nonisolated static var planoraControlStroke: Color {
        planoraDynamic(light: .white.opacity(0.72), dark: .white.opacity(0.18))
    }

    nonisolated static var planoraTagFill: Color {
        planoraDynamic(light: .white.opacity(0.54), dark: .white.opacity(0.10))
    }

    nonisolated static var planoraButtonStroke: Color {
        planoraDynamic(light: .white.opacity(0.34), dark: .white.opacity(0.24))
    }

    nonisolated static var planoraOnAccent: Color {
        planoraDynamic(
            light: .white,
            dark: Color(red: 0.03, green: 0.06, blue: 0.08)
        )
    }

    nonisolated static var planoraShadow: Color {
        planoraDynamic(light: .planoraInk.opacity(0.08), dark: .black.opacity(0.34))
    }

    nonisolated static var planoraSurfaceOverlayTop: Color {
        planoraDynamic(light: .white.opacity(0.64), dark: .black.opacity(0.10))
    }

    nonisolated static var planoraSurfaceOverlayBlue: Color {
        planoraDynamic(light: .planoraBlue.opacity(0.08), dark: .planoraBlue.opacity(0.14))
    }

    nonisolated static var planoraSurfaceOverlayGreen: Color {
        planoraDynamic(light: .planoraGreen.opacity(0.11), dark: .planoraGreen.opacity(0.12))
    }

#if canImport(UIKit)
    nonisolated private static func planoraDynamic(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
#else
    nonisolated private static func planoraDynamic(light: Color, dark: Color) -> Color {
        light
    }
#endif
}

extension LinearGradient {
    nonisolated static var planoraSurface: LinearGradient {
        LinearGradient(
            colors: [
                .planoraMist,
                .planoraSurfaceMid,
                .planoraPaper
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    nonisolated static var planoraAccent: LinearGradient {
        LinearGradient(
            colors: [.planoraBlue, .planoraGreen],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

extension View {
    @ViewBuilder
    func planoraHiddenNavigationBar() -> some View {
#if os(iOS)
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
#else
        self
#endif
    }

    @ViewBuilder
    func planoraDetailNavigationBar() -> some View {
#if os(iOS)
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
#else
        self
#endif
    }
}
