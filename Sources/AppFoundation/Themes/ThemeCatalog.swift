import Foundation

public struct ThemeCatalog: Hashable, Sendable {
    public let themes: [AppTheme]
    public let fallbackThemeID: String

    public init(themes: [AppTheme], fallbackThemeID: String) {
        var unique: [AppTheme] = []
        var indices: [String: Int] = [:]

        for theme in themes {
            if let index = indices[theme.id] {
                unique[index] = theme
            } else {
                indices[theme.id] = unique.count
                unique.append(theme)
            }
        }

        if unique.isEmpty {
            unique = [FoundationThemes.rose]
        }

        let resolvedFallbackThemeID = unique.contains(where: { $0.id == fallbackThemeID })
            ? fallbackThemeID
            : unique[0].id
        if let fallbackIndex = unique.firstIndex(where: { $0.id == resolvedFallbackThemeID }),
            unique[fallbackIndex].isPro
        {
            unique[fallbackIndex] = unique[fallbackIndex].withAccess(.free)
        }

        self.themes = unique
        self.fallbackThemeID = resolvedFallbackThemeID
    }

    public static let foundationDefaults = ThemeCatalog(
        themes: FoundationThemes.all,
        fallbackThemeID: FoundationThemes.rose.id
    )

    public var fallbackTheme: AppTheme {
        theme(id: fallbackThemeID) ?? themes[0]
    }

    public var freeThemes: [AppTheme] {
        themes.filter { $0.access == .free }
    }

    public var proThemes: [AppTheme] {
        themes.filter { $0.access == .pro }
    }

    public func theme(id: String) -> AppTheme? {
        themes.first { $0.id == id }
    }

    public func appending(_ additionalThemes: [AppTheme]) -> ThemeCatalog {
        ThemeCatalog(themes: themes + additionalThemes, fallbackThemeID: fallbackThemeID)
    }

    public func appending(_ theme: AppTheme) -> ThemeCatalog {
        appending([theme])
    }

    public func replacing(_ theme: AppTheme) -> ThemeCatalog {
        appending(theme)
    }

    public func excluding(ids: some Sequence<String>) -> ThemeCatalog {
        let excluded = Set(ids)
        return ThemeCatalog(
            themes: themes.filter { !excluded.contains($0.id) },
            fallbackThemeID: fallbackThemeID
        )
    }

    public func withAccess(_ access: ThemeAccess, forThemeIDs ids: some Sequence<String>) -> ThemeCatalog {
        let targetIDs = Set(ids)
        return ThemeCatalog(
            themes: themes.map { targetIDs.contains($0.id) ? $0.withAccess(access) : $0 },
            fallbackThemeID: fallbackThemeID
        )
    }

    public func withFallbackThemeID(_ id: String) -> ThemeCatalog {
        ThemeCatalog(themes: themes, fallbackThemeID: id)
    }
}
