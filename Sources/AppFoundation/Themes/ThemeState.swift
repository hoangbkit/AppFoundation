import Foundation

public struct ThemeStoredState: Codable, Equatable, Sendable {
    /// The user's committed preference, retained when Pro access expires.
    public var selectedThemeID: String?
    /// The last applied base theme. Previews never replace this value.
    public var committedThemeID: String?
    public var previewThemeID: String?
    public var previewExpiresAt: Date?
    public var lastKnownHasPro: Bool

    public init(
        selectedThemeID: String? = nil,
        previewThemeID: String? = nil,
        previewExpiresAt: Date? = nil,
        lastKnownHasPro: Bool = false,
        committedThemeID: String? = nil
    ) {
        self.selectedThemeID = selectedThemeID
        self.committedThemeID = committedThemeID
        self.previewThemeID = previewThemeID
        self.previewExpiresAt = previewExpiresAt
        self.lastKnownHasPro = lastKnownHasPro
    }

    private enum CodingKeys: String, CodingKey {
        case selectedThemeID
        case committedThemeID
        case previewThemeID
        case previewExpiresAt
        case lastKnownHasPro
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        selectedThemeID = try values.decodeIfPresent(String.self, forKey: .selectedThemeID)
        committedThemeID = try values.decodeIfPresent(String.self, forKey: .committedThemeID)
        previewThemeID = try values.decodeIfPresent(String.self, forKey: .previewThemeID)
        previewExpiresAt = try values.decodeIfPresent(Date.self, forKey: .previewExpiresAt)
        lastKnownHasPro = try values.decodeIfPresent(Bool.self, forKey: .lastKnownHasPro) ?? false
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
        let selectedBase =
            selectedTheme.access == .free || resolvedHasPro
            ? selectedTheme : catalog.fallbackTheme
        // Explicit access resolves the preference. Startup and widgets restore
        // the committed base, rather than resurrecting a remembered Pro choice.
        let committedTheme = state.committedThemeID.flatMap(catalog.theme(id:))
        let baseTheme: AppTheme
        if hasPro == nil, state.committedThemeID != nil {
            if let committedTheme, committedTheme.access == .free || resolvedHasPro {
                baseTheme = committedTheme
            } else {
                baseTheme = catalog.fallbackTheme
            }
        } else {
            // Also migrates legacy states without a committed base.
            baseTheme = selectedBase
        }

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
        } else {
            effectiveTheme = baseTheme
            usesFallback = selectedTheme.isPro && !resolvedHasPro
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

    /// Applies one resolved access result to preference, base, and preview together.
    /// Shared by live theme projection and persistence so purchase transitions agree.
    static func applyingAccess(
        _ hasPro: Bool,
        to state: ThemeStoredState,
        catalog: ThemeCatalog,
        now: Date,
        promotesPreviewOnProUnlock: Bool
    ) -> ThemeStoredState {
        var next = state
        let preview = resolve(catalog: catalog, state: state, now: now).previewTheme
        if hasPro {
            if promotesPreviewOnProUnlock, let preview {
                next.selectedThemeID = preview.id
            }
            next.previewThemeID = nil
            next.previewExpiresAt = nil
        }
        next.lastKnownHasPro = hasPro
        let selected = next.selectedThemeID.flatMap(catalog.theme(id:)) ?? catalog.fallbackTheme
        next.committedThemeID =
            selected.access == .free || hasPro
            ? selected.id : catalog.fallbackThemeID
        return next
    }
}
