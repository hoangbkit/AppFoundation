import Foundation

public struct ThemeStoredState: Codable, Equatable, Sendable {
    public var selectedThemeID: String?
    public var previewThemeID: String?
    public var previewExpiresAt: Date?
    public var lastKnownHasPro: Bool

    public init(
        selectedThemeID: String? = nil,
        previewThemeID: String? = nil,
        previewExpiresAt: Date? = nil,
        lastKnownHasPro: Bool = false
    ) {
        self.selectedThemeID = selectedThemeID
        self.previewThemeID = previewThemeID
        self.previewExpiresAt = previewExpiresAt
        self.lastKnownHasPro = lastKnownHasPro
    }
}

public protocol ThemeStateStoring: Sendable {
    func load() -> ThemeStoredState
    func save(_ state: ThemeStoredState)
}

public final class UserDefaultsThemeStateStore: ThemeStateStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let storageKey: String

    public init(
        storageKey: String = "appFoundation.themeState.v1",
        suiteName: String? = nil
    ) {
        defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        self.storageKey = storageKey
    }

    public func load() -> ThemeStoredState {
        guard
            let data = defaults.data(forKey: storageKey),
            let state = try? JSONDecoder().decode(ThemeStoredState.self, from: data)
        else {
            return ThemeStoredState()
        }
        return state
    }

    public func save(_ state: ThemeStoredState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

public struct ThemeResolution: Equatable, Sendable {
    public let selectedTheme: AppTheme
    public let effectiveTheme: AppTheme
    public let previewTheme: AppTheme?
    public let previewExpiresAt: Date?
    public let hasPro: Bool
    public let isPreviewActive: Bool
    public let isUsingFallbackForAccess: Bool

    public var nextAutomaticChangeDate: Date? {
        isPreviewActive ? previewExpiresAt : nil
    }
}

public enum ThemeResolver {
    public static func resolve(
        catalog: ThemeCatalog,
        state: ThemeStoredState,
        hasPro: Bool? = nil,
        now: Date = .now
    ) -> ThemeResolution {
        let resolvedHasPro = hasPro ?? state.lastKnownHasPro
        let selectedTheme = state.selectedThemeID.flatMap(catalog.theme(id:)) ?? catalog.fallbackTheme

        let activePreview: AppTheme? = {
            guard !resolvedHasPro else { return nil }
            guard let previewID = state.previewThemeID else { return nil }
            guard let expiry = state.previewExpiresAt, expiry > now else { return nil }
            guard let theme = catalog.theme(id: previewID), theme.isPro else { return nil }
            return theme
        }()

        let effectiveTheme: AppTheme
        let usesFallback: Bool
        if let activePreview {
            effectiveTheme = activePreview
            usesFallback = false
        } else if selectedTheme.access == .free || resolvedHasPro {
            effectiveTheme = selectedTheme
            usesFallback = false
        } else {
            effectiveTheme = catalog.fallbackTheme
            usesFallback = true
        }

        return ThemeResolution(
            selectedTheme: selectedTheme,
            effectiveTheme: effectiveTheme,
            previewTheme: activePreview,
            previewExpiresAt: activePreview == nil ? nil : state.previewExpiresAt,
            hasPro: resolvedHasPro,
            isPreviewActive: activePreview != nil,
            isUsingFallbackForAccess: usesFallback
        )
    }
}
