#if canImport(Observation) && canImport(SwiftUI)
import Foundation
import Observation

public struct ThemePreviewBehavior: Equatable, Sendable {
    public var isEnabled: Bool
    public var defaultDuration: TimeInterval
    public var preservesExpiryWhenSwitchingThemes: Bool
    public var promotesPreviewOnProUnlock: Bool
    public var schedulesAutomaticExpiration: Bool

    public init(
        isEnabled: Bool = true,
        defaultDuration: TimeInterval = 5 * 60,
        preservesExpiryWhenSwitchingThemes: Bool = true,
        promotesPreviewOnProUnlock: Bool = true,
        schedulesAutomaticExpiration: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.defaultDuration = max(0, defaultDuration)
        self.preservesExpiryWhenSwitchingThemes = preservesExpiryWhenSwitchingThemes
        self.promotesPreviewOnProUnlock = promotesPreviewOnProUnlock
        self.schedulesAutomaticExpiration = schedulesAutomaticExpiration
    }

    public static let miLoveStyle = ThemePreviewBehavior()
    public static let disabled = ThemePreviewBehavior(isEnabled: false)
}

public enum ThemeSelectionResult: Equatable, Sendable {
    case selected(AppTheme)
    case previewStarted(AppTheme, expiresAt: Date)
    case requiresPro(AppTheme)
    case unavailable(themeID: String)
}

@MainActor
@Observable
public final class ThemeManager {
    public let catalog: ThemeCatalog
    public let previewBehavior: ThemePreviewBehavior

    public private(set) var storedState: ThemeStoredState
    public private(set) var hasPro: Bool
    /// Cached appearance is not permission to commit a newly selected Pro theme.
    public private(set) var isCheckingProAccess: Bool

    @ObservationIgnored private let stateStore: any ThemeStateStoring
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let stateDidChange: @MainActor (ThemeResolution) -> Void
    @ObservationIgnored private var previewExpiryTask: Task<Void, Never>?
    #if canImport(StoreKit)
    @ObservationIgnored private weak var boundPurchases: PurchaseManager?
    @ObservationIgnored private var purchaseObservationID: UUID?
    #endif

    public init(
        catalog: ThemeCatalog = .foundationDefaults,
        stateStore: any ThemeStateStoring = UserDefaultsThemeStateStore(),
        hasPro: Bool? = nil,
        previewBehavior: ThemePreviewBehavior = .miLoveStyle,
        now: @escaping @MainActor () -> Date = { .now },
        stateDidChange: @escaping @MainActor (ThemeResolution) -> Void = { _ in }
    ) {
        self.catalog = catalog
        self.stateStore = stateStore
        self.previewBehavior = previewBehavior
        self.now = now
        self.stateDidChange = stateDidChange

        let persisted = stateStore.load()
        var loaded = persisted
        self.hasPro = hasPro ?? loaded.lastKnownHasPro
        self.isCheckingProAccess = hasPro == nil
        loaded = Self.normalized(
            loaded, catalog: catalog, now: now(), previewsEnabled: previewBehavior.isEnabled
        )
        if let hasPro {
            loaded = ThemeResolver.applyingAccess(
                hasPro,
                to: loaded,
                catalog: catalog,
                now: now(),
                promotesPreviewOnProUnlock: previewBehavior.promotesPreviewOnProUnlock
            )
        }
        self.storedState = loaded
        // Do not rewrite unchanged state every time SwiftUI constructs an owner.
        if self.storedState != persisted {
            stateStore.save(self.storedState)
        }
        schedulePreviewExpirationIfNeeded()
    }

    deinit {
        previewExpiryTask?.cancel()
    }

    public var resolution: ThemeResolution {
        ThemeResolver.resolve(catalog: catalog, state: storedState, now: now())
    }

    public var selectedTheme: AppTheme { resolution.selectedTheme }
    public var committedTheme: AppTheme {
        storedState.committedThemeID.flatMap(catalog.theme(id:)) ?? catalog.fallbackTheme
    }
    public var effectiveTheme: AppTheme { resolution.effectiveTheme }

    /// Resolves the visual theme against live purchase verification state.
    ///
    /// While checking, restore the committed base plus any unexpired preview.
    /// Resolved access uses the same transition that synchronization persists.
    public func effectiveTheme(
        entitlementState: EntitlementState,
        hasPro: Bool
    ) -> AppTheme {
        if case .checking = entitlementState {
            return effectiveTheme
        }
        let projected = ThemeResolver.applyingAccess(
            hasPro,
            to: Self.normalized(
                storedState, catalog: catalog, now: now(), previewsEnabled: previewBehavior.isEnabled
            ),
            catalog: catalog,
            now: now(),
            promotesPreviewOnProUnlock: previewBehavior.promotesPreviewOnProUnlock
        )
        return ThemeResolver.resolve(
            catalog: catalog,
            state: projected,
            now: now()
        ).effectiveTheme
    }

    public var previewTheme: AppTheme? { resolution.previewTheme }
    public var previewExpiresAt: Date? { resolution.previewExpiresAt }
    public var isPreviewActive: Bool { resolution.isPreviewActive }
    public var nextAutomaticChangeDate: Date? { resolution.nextAutomaticChangeDate }
    public var canPreviewProThemes: Bool {
        catalog.proThemes.contains(where: canPreview)
    }

    public func canPreview(_ theme: AppTheme) -> Bool {
        guard theme.isPro, !hasPro, !isCheckingProAccess, previewBehavior.isEnabled else {
            return false
        }
        return (theme.previewDuration ?? previewBehavior.defaultDuration) > 0
    }

    public var previewRemainingSeconds: Int {
        guard let previewExpiresAt else { return 0 }
        return max(0, Int(ceil(previewExpiresAt.timeIntervalSince(now()))))
    }

    @discardableResult
    public func select(themeID: String) -> ThemeSelectionResult {
        guard let theme = catalog.theme(id: themeID) else {
            return .unavailable(themeID: themeID)
        }

        guard !theme.isPro || !isCheckingProAccess else { return .requiresPro(theme) }

        if theme.access == .free || hasPro {
            storedState.selectedThemeID = theme.id
            storedState.committedThemeID = theme.id
            clearPreviewState()
            persistAndNotify()
            return .selected(theme)
        }

        guard previewBehavior.isEnabled else {
            return .requiresPro(theme)
        }

        let duration = theme.previewDuration ?? previewBehavior.defaultDuration
        guard duration > 0 else {
            return .requiresPro(theme)
        }

        let currentResolution = resolution
        let expiry: Date
        if previewBehavior.preservesExpiryWhenSwitchingThemes,
            currentResolution.isPreviewActive,
            let existingExpiry = currentResolution.previewExpiresAt
        {
            expiry = existingExpiry
        } else {
            expiry = now().addingTimeInterval(duration)
        }

        storedState.previewThemeID = theme.id
        storedState.previewExpiresAt = expiry
        persistAndNotify()
        schedulePreviewExpirationIfNeeded()
        return .previewStarted(theme, expiresAt: expiry)
    }

    @discardableResult
    public func select(_ theme: AppTheme) -> ThemeSelectionResult {
        select(themeID: theme.id)
    }

    public func endPreview() {
        guard storedState.previewThemeID != nil || storedState.previewExpiresAt != nil else { return }
        clearPreviewState()
        persistAndNotify()
    }

    public func synchronizeProAccess(
        _ isUnlocked: Bool,
        entitlementState: EntitlementState
    ) {
        if case .checking = entitlementState {
            isCheckingProAccess = true
            return
        }
        synchronizeProAccess(isUnlocked)
    }

    public func synchronizeProAccess(_ isUnlocked: Bool) {
        let next = ThemeResolver.applyingAccess(
            isUnlocked,
            to: Self.normalized(
                storedState, catalog: catalog, now: now(), previewsEnabled: previewBehavior.isEnabled
            ),
            catalog: catalog,
            now: now(),
            promotesPreviewOnProUnlock: previewBehavior.promotesPreviewOnProUnlock
        )
        hasPro = isUnlocked
        isCheckingProAccess = false
        storedState = next
        persistAndNotify()
        schedulePreviewExpirationIfNeeded()
    }

    public func refreshFromPersistence() {
        let loaded = Self.normalized(
            stateStore.load(), catalog: catalog, now: now(), previewsEnabled: previewBehavior.isEnabled
        )
        if isCheckingProAccess {
            storedState = loaded
            hasPro = loaded.lastKnownHasPro
        } else {
            storedState = ThemeResolver.applyingAccess(
                hasPro,
                to: loaded,
                catalog: catalog,
                now: now(),
                promotesPreviewOnProUnlock: previewBehavior.promotesPreviewOnProUnlock
            )
        }
        // Reading shared state must not overwrite a newer access commit on disk.
        stateDidChange(resolution)
        schedulePreviewExpirationIfNeeded()
    }

    public func refresh() {
        let normalized = Self.normalized(
            storedState, catalog: catalog, now: now(), previewsEnabled: previewBehavior.isEnabled
        )
        guard normalized != storedState else { return }
        storedState = normalized
        persistAndNotify()
        schedulePreviewExpirationIfNeeded()
    }

    public func reset() {
        storedState = ThemeStoredState(
            selectedThemeID: catalog.fallbackThemeID,
            lastKnownHasPro: storedState.lastKnownHasPro,
            committedThemeID: catalog.fallbackThemeID
        )
        persistAndNotify()
    }

    public func isEffective(_ theme: AppTheme) -> Bool {
        effectiveTheme.id == theme.id
    }

    public func isPreviewing(_ theme: AppTheme) -> Bool {
        previewTheme?.id == theme.id
    }

    private func persistAndNotify() {
        stateStore.save(storedState)
        stateDidChange(resolution)
    }

    private func clearPreviewState() {
        previewExpiryTask?.cancel()
        previewExpiryTask = nil
        storedState.previewThemeID = nil
        storedState.previewExpiresAt = nil
    }

    private func schedulePreviewExpirationIfNeeded() {
        previewExpiryTask?.cancel()
        previewExpiryTask = nil
        guard previewBehavior.schedulesAutomaticExpiration else { return }
        guard let expiry = resolution.nextAutomaticChangeDate else { return }

        let delay = max(0, expiry.timeIntervalSince(now()))
        previewExpiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    private static func normalized(
        _ state: ThemeStoredState,
        catalog: ThemeCatalog,
        now: Date,
        previewsEnabled: Bool = true
    ) -> ThemeStoredState {
        var normalized = state

        if let selectedID = normalized.selectedThemeID, catalog.theme(id: selectedID) == nil {
            normalized.selectedThemeID = catalog.fallbackThemeID
        }
        if normalized.selectedThemeID == nil {
            normalized.selectedThemeID = catalog.fallbackThemeID
        }

        if normalized.committedThemeID == nil {
            let selected =
                normalized.selectedThemeID.flatMap(catalog.theme(id:))
                ?? catalog.fallbackTheme
            normalized.committedThemeID =
                selected.access == .free || normalized.lastKnownHasPro
                ? selected.id : catalog.fallbackThemeID
        } else if let committed = normalized.committedThemeID.flatMap(catalog.theme(id:)),
            committed.access == .free || normalized.lastKnownHasPro
        {
            // A valid committed base is independent of the remembered preference.
        } else {
            normalized.committedThemeID = catalog.fallbackThemeID
        }

        let previewIsValid: Bool = {
            guard previewsEnabled else { return false }
            guard let previewID = normalized.previewThemeID else { return false }
            guard let previewTheme = catalog.theme(id: previewID), previewTheme.isPro else {
                return false
            }
            guard let expiry = normalized.previewExpiresAt, expiry > now else { return false }
            return true
        }()

        if !previewIsValid {
            normalized.previewThemeID = nil
            normalized.previewExpiresAt = nil
        }

        return normalized
    }

    #if canImport(StoreKit)
    /// Binds for the manager's lifetime. Resolved access is saved synchronously
    /// inside purchase resolution, including when no themed view is mounted.
    public func bind(to purchases: PurchaseManager) {
        guard boundPurchases !== purchases else { return }
        if let boundPurchases, let purchaseObservationID {
            boundPurchases.removeThemeAccessObserver(purchaseObservationID)
        }
        boundPurchases = purchases
        purchaseObservationID = purchases.addThemeAccessObserver { [weak self] state, hasPro in
            guard let self else { return false }
            self.synchronizeProAccess(hasPro, entitlementState: state)
            return true
        }
    }
    #endif
}

#endif
