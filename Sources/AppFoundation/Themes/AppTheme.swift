import Foundation

public enum ThemeAccess: String, Codable, CaseIterable, Hashable, Sendable {
    case free
    case pro
}

public enum ThemePreferredColorScheme: String, Codable, CaseIterable, Hashable, Sendable {
    case system
    case light
    case dark
}

public struct ThemeColor: Codable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    public func withAlpha(_ alpha: Double) -> ThemeColor {
        ThemeColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public static let clear = ThemeColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let white = ThemeColor(red: 1, green: 1, blue: 1)
    public static let black = ThemeColor(red: 0, green: 0, blue: 0)

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

public struct ThemeAppearance: Codable, Hashable, Sendable {
    public let background: ThemeColor
    public let gradientStart: ThemeColor
    public let gradientEnd: ThemeColor
    public let accent: ThemeColor
    public let primaryForeground: ThemeColor
    public let secondaryForeground: ThemeColor
    public let surface: ThemeColor
    public let elevatedSurface: ThemeColor
    public let border: ThemeColor
    public let shadow: ThemeColor
    public let cardCornerRadius: Double
    public let preferredColorScheme: ThemePreferredColorScheme

    public init(
        background: ThemeColor,
        gradientStart: ThemeColor,
        gradientEnd: ThemeColor,
        accent: ThemeColor,
        primaryForeground: ThemeColor,
        secondaryForeground: ThemeColor,
        surface: ThemeColor,
        elevatedSurface: ThemeColor,
        border: ThemeColor,
        shadow: ThemeColor = .black.withAlpha(0.25),
        cardCornerRadius: Double = 24,
        preferredColorScheme: ThemePreferredColorScheme = .system
    ) {
        self.background = background
        self.gradientStart = gradientStart
        self.gradientEnd = gradientEnd
        self.accent = accent
        self.primaryForeground = primaryForeground
        self.secondaryForeground = secondaryForeground
        self.surface = surface
        self.elevatedSurface = elevatedSurface
        self.border = border
        self.shadow = shadow
        self.cardCornerRadius = max(0, cardCornerRadius)
        self.preferredColorScheme = preferredColorScheme
    }

    public func withAccent(_ accent: ThemeColor) -> ThemeAppearance {
        ThemeAppearance(
            background: background,
            gradientStart: gradientStart,
            gradientEnd: gradientEnd,
            accent: accent,
            primaryForeground: primaryForeground,
            secondaryForeground: secondaryForeground,
            surface: surface,
            elevatedSurface: elevatedSurface,
            border: border,
            shadow: shadow,
            cardCornerRadius: cardCornerRadius,
            preferredColorScheme: preferredColorScheme
        )
    }

    public func withPreferredColorScheme(_ scheme: ThemePreferredColorScheme) -> ThemeAppearance {
        ThemeAppearance(
            background: background,
            gradientStart: gradientStart,
            gradientEnd: gradientEnd,
            accent: accent,
            primaryForeground: primaryForeground,
            secondaryForeground: secondaryForeground,
            surface: surface,
            elevatedSurface: elevatedSurface,
            border: border,
            shadow: shadow,
            cardCornerRadius: cardCornerRadius,
            preferredColorScheme: scheme
        )
    }
}

public struct AppTheme: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let symbolName: String
    public let access: ThemeAccess
    public let appearance: ThemeAppearance
    public let previewDuration: TimeInterval?
    public let alternateIconName: String?
    public let previewImageName: String?

    public init(
        id: String,
        title: String,
        symbolName: String,
        access: ThemeAccess = .free,
        appearance: ThemeAppearance,
        previewDuration: TimeInterval? = nil,
        alternateIconName: String? = nil,
        previewImageName: String? = nil
    ) {
        precondition(!id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Theme id cannot be empty")
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.access = access
        self.appearance = appearance
        self.previewDuration = previewDuration.map { max(0, $0) }
        self.alternateIconName = alternateIconName
        self.previewImageName = previewImageName
    }

    public var isPro: Bool { access == .pro }

    public func withTitle(_ title: String) -> AppTheme {
        copy(title: title)
    }

    public func withAccess(_ access: ThemeAccess) -> AppTheme {
        copy(access: access)
    }

    public func withSymbolName(_ symbolName: String) -> AppTheme {
        copy(symbolName: symbolName)
    }

    public func withAppearance(_ appearance: ThemeAppearance) -> AppTheme {
        copy(appearance: appearance)
    }

    public func withAccent(_ accent: ThemeColor) -> AppTheme {
        copy(appearance: appearance.withAccent(accent))
    }

    public func withPreferredColorScheme(_ scheme: ThemePreferredColorScheme) -> AppTheme {
        copy(appearance: appearance.withPreferredColorScheme(scheme))
    }

    public func withPreviewDuration(_ duration: TimeInterval?) -> AppTheme {
        copy(previewDuration: duration)
    }

    public func withAlternateIconName(_ name: String?) -> AppTheme {
        copy(alternateIconName: name)
    }

    public func withPreviewImageName(_ name: String?) -> AppTheme {
        copy(previewImageName: name)
    }

    private func copy(
        title: String? = nil,
        symbolName: String? = nil,
        access: ThemeAccess? = nil,
        appearance: ThemeAppearance? = nil,
        previewDuration: TimeInterval?? = nil,
        alternateIconName: String?? = nil,
        previewImageName: String?? = nil
    ) -> AppTheme {
        AppTheme(
            id: id,
            title: title ?? self.title,
            symbolName: symbolName ?? self.symbolName,
            access: access ?? self.access,
            appearance: appearance ?? self.appearance,
            previewDuration: previewDuration ?? self.previewDuration,
            alternateIconName: alternateIconName ?? self.alternateIconName,
            previewImageName: previewImageName ?? self.previewImageName
        )
    }
}
