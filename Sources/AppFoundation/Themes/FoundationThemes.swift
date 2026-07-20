import Foundation

public enum FoundationThemes {
    public static let rose = AppTheme(
        id: "rose",
        title: "Rose",
        symbolName: "heart.fill",
        access: .free,
        appearance: ThemeAppearance(
            background: ThemeColor(hex: 0x08090D),
            gradientStart: ThemeColor(hex: 0xFFC7D4),
            gradientEnd: ThemeColor(hex: 0xED4F7A),
            accent: ThemeColor(hex: 0xED4F7A),
            primaryForeground: .white,
            secondaryForeground: .white.withAlpha(0.72),
            surface: .white.withAlpha(0.07),
            elevatedSurface: .white.withAlpha(0.11),
            border: .white.withAlpha(0.14),
            shadow: .black.withAlpha(0.34),
            preferredColorScheme: .dark
        )
    )

    public static let sunset = AppTheme(
        id: "sunset",
        title: "Sunset",
        symbolName: "sun.horizon.fill",
        access: .pro,
        appearance: ThemeAppearance(
            background: ThemeColor(hex: 0x10090B),
            gradientStart: ThemeColor(hex: 0xFFB36E),
            gradientEnd: ThemeColor(hex: 0xE04075),
            accent: ThemeColor(hex: 0xFF8A4C),
            primaryForeground: .white,
            secondaryForeground: .white.withAlpha(0.72),
            surface: .white.withAlpha(0.07),
            elevatedSurface: .white.withAlpha(0.11),
            border: .white.withAlpha(0.14),
            shadow: .black.withAlpha(0.34),
            preferredColorScheme: .dark
        )
    )

    public static let lavender = AppTheme(
        id: "lavender",
        title: "Lavender",
        symbolName: "sparkles",
        access: .pro,
        appearance: ThemeAppearance(
            background: ThemeColor(hex: 0x0B0912),
            gradientStart: ThemeColor(hex: 0xDBC7FF),
            gradientEnd: ThemeColor(hex: 0x7D5CD1),
            accent: ThemeColor(hex: 0xA783F0),
            primaryForeground: .white,
            secondaryForeground: .white.withAlpha(0.72),
            surface: .white.withAlpha(0.07),
            elevatedSurface: .white.withAlpha(0.11),
            border: .white.withAlpha(0.14),
            shadow: .black.withAlpha(0.34),
            preferredColorScheme: .dark
        )
    )

    public static let midnight = AppTheme(
        id: "midnight",
        title: "Midnight",
        symbolName: "moon.stars.fill",
        access: .pro,
        appearance: ThemeAppearance(
            background: ThemeColor(hex: 0x070810),
            gradientStart: ThemeColor(hex: 0x1F193D),
            gradientEnd: ThemeColor(hex: 0x522E73),
            accent: ThemeColor(hex: 0x806CFF),
            primaryForeground: .white,
            secondaryForeground: .white.withAlpha(0.72),
            surface: .white.withAlpha(0.065),
            elevatedSurface: .white.withAlpha(0.10),
            border: .white.withAlpha(0.13),
            shadow: .black.withAlpha(0.42),
            preferredColorScheme: .dark
        )
    )

    public static let paper = AppTheme(
        id: "paper",
        title: "Paper",
        symbolName: "photo.on.rectangle.angled",
        access: .pro,
        appearance: ThemeAppearance(
            background: ThemeColor(hex: 0xF7F0E5),
            gradientStart: ThemeColor(hex: 0xFAF0DE),
            gradientEnd: ThemeColor(hex: 0xE0C7AB),
            accent: ThemeColor(hex: 0x8B5B36),
            primaryForeground: ThemeColor(hex: 0x362318),
            secondaryForeground: ThemeColor(hex: 0x362318, alpha: 0.68),
            surface: .white.withAlpha(0.68),
            elevatedSurface: .white.withAlpha(0.86),
            border: ThemeColor(hex: 0x6F4B33, alpha: 0.14),
            shadow: ThemeColor(hex: 0x513621, alpha: 0.18),
            preferredColorScheme: .light
        )
    )

    public static let champagne = AppTheme(
        id: "champagne",
        title: "Champagne",
        symbolName: "party.popper.fill",
        access: .pro,
        appearance: ThemeAppearance(
            background: ThemeColor(hex: 0xF8F0DD),
            gradientStart: ThemeColor(hex: 0xFFF0B0),
            gradientEnd: ThemeColor(hex: 0xC18C47),
            accent: ThemeColor(hex: 0x8C5C12),
            primaryForeground: ThemeColor(hex: 0x30200D),
            secondaryForeground: ThemeColor(hex: 0x30200D, alpha: 0.68),
            surface: .white.withAlpha(0.62),
            elevatedSurface: .white.withAlpha(0.82),
            border: ThemeColor(hex: 0x6B4718, alpha: 0.15),
            shadow: ThemeColor(hex: 0x5D3C12, alpha: 0.20),
            preferredColorScheme: .light
        )
    )

    public static let all: [AppTheme] = [rose, sunset, lavender, midnight, paper, champagne]
}
