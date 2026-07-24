import Foundation

struct PackageDocumentationTreeItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case folder
        case file
    }

    let path: String
    let name: String
    let kind: Kind
    let depth: Int

    var id: String { path }

    static func folder(_ name: String, path: String, depth: Int) -> Self {
        Self(path: path, name: name, kind: .folder, depth: depth)
    }

    static func file(_ name: String, path: String, depth: Int) -> Self {
        Self(path: path, name: name, kind: .file, depth: depth)
    }
}

struct PackageDocumentationAPIItem: Identifiable, Hashable {
    let name: String
    let kind: String
    let summary: String
    let sourcePath: String
    let usage: String?

    var id: String { sourcePath + "#" + name }

    var searchableText: String {
        [name, kind, summary, sourcePath, usage ?? ""]
            .joined(separator: " ")
            .localizedLowercase
    }

    var copyText: String {
        var parts = [name, summary, "Source: \(sourcePath)"]
        if let usage, !usage.isEmpty {
            parts.append(usage)
        }
        return parts.joined(separator: "\n\n")
    }
}

struct PackageDocumentationAPIGroup: Identifiable, Hashable {
    let title: String
    let systemImage: String
    let items: [PackageDocumentationAPIItem]

    var id: String { title }
}

enum PackageDocumentationCatalog {
    static let sourceTree: [PackageDocumentationTreeItem] = [
        .folder("Sources", path: "Sources", depth: 0),
        .folder("AppFoundation", path: "Sources/AppFoundation", depth: 1),
        .folder("Backup", path: "Sources/AppFoundation/Backup", depth: 2),
        .file("BackupKit.swift", path: "Sources/AppFoundation/Backup/BackupKit.swift", depth: 3),
        .folder("Core", path: "Sources/AppFoundation/Core", depth: 2),
        .file("AppMetadata.swift", path: "Sources/AppFoundation/Core/AppMetadata.swift", depth: 3),
        .file("PurchaseConfiguration.swift", path: "Sources/AppFoundation/Core/PurchaseConfiguration.swift", depth: 3),
        .file("PurchasePlan.swift", path: "Sources/AppFoundation/Core/PurchasePlan.swift", depth: 3),
        .file("PurchaseState.swift", path: "Sources/AppFoundation/Core/PurchaseState.swift", depth: 3),
        .folder("Export", path: "Sources/AppFoundation/Export", depth: 2),
        .file("ExportKit.swift", path: "Sources/AppFoundation/Export/ExportKit.swift", depth: 3),
        .folder("Platform", path: "Sources/AppFoundation/Platform", depth: 2),
        .file("WidgetNotificationSupport.swift", path: "Sources/AppFoundation/Platform/WidgetNotificationSupport.swift", depth: 3),
        .folder("PromoVideoStudio", path: "Sources/AppFoundation/PromoVideoStudio", depth: 2),
        .folder("Templates", path: "Sources/AppFoundation/PromoVideoStudio/Templates", depth: 3),
        .file("PromoVideoFeatureTemplates.swift", path: "Sources/AppFoundation/PromoVideoStudio/Templates/PromoVideoFeatureTemplates.swift", depth: 4),
        .file("PromoVideoStoryTemplates.swift", path: "Sources/AppFoundation/PromoVideoStudio/Templates/PromoVideoStoryTemplates.swift", depth: 4),
        .file("PromoVideoTemplateComponents.swift", path: "Sources/AppFoundation/PromoVideoStudio/Templates/PromoVideoTemplateComponents.swift", depth: 4),
        .file("PromoVideoCompositionView.swift", path: "Sources/AppFoundation/PromoVideoStudio/PromoVideoCompositionView.swift", depth: 3),
        .file("PromoVideoExporter.swift", path: "Sources/AppFoundation/PromoVideoStudio/PromoVideoExporter.swift", depth: 3),
        .file("PromoVideoPreviewView.swift", path: "Sources/AppFoundation/PromoVideoStudio/PromoVideoPreviewView.swift", depth: 3),
        .file("PromoVideoStudioSupport.swift", path: "Sources/AppFoundation/PromoVideoStudio/PromoVideoStudioSupport.swift", depth: 3),
        .file("PromoVideoStudioTypes.swift", path: "Sources/AppFoundation/PromoVideoStudio/PromoVideoStudioTypes.swift", depth: 3),
        .folder("Purchases", path: "Sources/AppFoundation/Purchases", depth: 2),
        .file("PurchaseController.swift", path: "Sources/AppFoundation/Purchases/PurchaseController.swift", depth: 3),
        .file("PurchaseLifecycleModifier.swift", path: "Sources/AppFoundation/Purchases/PurchaseLifecycleModifier.swift", depth: 3),
        .file("PurchaseServiceFactory.swift", path: "Sources/AppFoundation/Purchases/PurchaseServiceFactory.swift", depth: 3),
        .file("SimulatedPurchaseService.swift", path: "Sources/AppFoundation/Purchases/SimulatedPurchaseService.swift", depth: 3),
        .folder("ScreenshotStudio", path: "Sources/AppFoundation/ScreenshotStudio", depth: 2),
        .folder("Components", path: "Sources/AppFoundation/ScreenshotStudio/Components", depth: 3),
        .file("ScreenshotEffects.swift", path: "Sources/AppFoundation/ScreenshotStudio/Components/ScreenshotEffects.swift", depth: 4),
        .file("ScreenshotMacWindowFrame.swift", path: "Sources/AppFoundation/ScreenshotStudio/Components/ScreenshotMacWindowFrame.swift", depth: 4),
        .file("ScreenshotPromotionalComponents.swift", path: "Sources/AppFoundation/ScreenshotStudio/Components/ScreenshotPromotionalComponents.swift", depth: 4),
        .file("ScreenshotSystemChrome.swift", path: "Sources/AppFoundation/ScreenshotStudio/Components/ScreenshotSystemChrome.swift", depth: 4),
        .folder("Templates", path: "Sources/AppFoundation/ScreenshotStudio/Templates", depth: 3),
        .file("FeatureScreenshotTemplates.swift", path: "Sources/AppFoundation/ScreenshotStudio/Templates/FeatureScreenshotTemplates.swift", depth: 4),
        .file("GalleryScreenshotTemplates.swift", path: "Sources/AppFoundation/ScreenshotStudio/Templates/GalleryScreenshotTemplates.swift", depth: 4),
        .file("HeroScreenshotTemplates.swift", path: "Sources/AppFoundation/ScreenshotStudio/Templates/HeroScreenshotTemplates.swift", depth: 4),
        .file("LayeredScreenshotTemplates.swift", path: "Sources/AppFoundation/ScreenshotStudio/Templates/LayeredScreenshotTemplates.swift", depth: 4),
        .file("ScreenshotTemplateComponents.swift", path: "Sources/AppFoundation/ScreenshotStudio/Templates/ScreenshotTemplateComponents.swift", depth: 4),
        .file("ScreenshotStudioEngine.swift", path: "Sources/AppFoundation/ScreenshotStudio/ScreenshotStudioEngine.swift", depth: 3),
        .file("ScreenshotStudioMacView.swift", path: "Sources/AppFoundation/ScreenshotStudio/ScreenshotStudioMacView.swift", depth: 3),
        .file("ScreenshotStudioModels.swift", path: "Sources/AppFoundation/ScreenshotStudio/ScreenshotStudioModels.swift", depth: 3),
        .file("ScreenshotStudioView.swift", path: "Sources/AppFoundation/ScreenshotStudio/ScreenshotStudioView.swift", depth: 3),
        .folder("Themes", path: "Sources/AppFoundation/Themes", depth: 2),
        .file("AppTheme.swift", path: "Sources/AppFoundation/Themes/AppTheme.swift", depth: 3),
        .file("ThemeCatalog.swift", path: "Sources/AppFoundation/Themes/ThemeCatalog.swift", depth: 3),
        .file("ThemeManager.swift", path: "Sources/AppFoundation/Themes/ThemeManager.swift", depth: 3),
        .file("ThemeState.swift", path: "Sources/AppFoundation/Themes/ThemeState.swift", depth: 3),
        .folder("UI", path: "Sources/AppFoundation/UI", depth: 2),
        .file("ClaudePaywallView.swift", path: "Sources/AppFoundation/UI/ClaudePaywallView.swift", depth: 3),
        .file("CommerceViews.swift", path: "Sources/AppFoundation/UI/CommerceViews.swift", depth: 3),
        .file("FoundationOnboardingView.swift", path: "Sources/AppFoundation/UI/FoundationOnboardingView.swift", depth: 3),
        .file("FoundationPaywallView.swift", path: "Sources/AppFoundation/UI/FoundationPaywallView.swift", depth: 3),
        .file("FoundationSettingsView.swift", path: "Sources/AppFoundation/UI/FoundationSettingsView.swift", depth: 3),
        .file("FoundationTheme.swift", path: "Sources/AppFoundation/UI/FoundationTheme.swift", depth: 3),
        .file("LimitReachedUpsellView.swift", path: "Sources/AppFoundation/UI/LimitReachedUpsellView.swift", depth: 3),
        .file("ProPlanSettingsSection.swift", path: "Sources/AppFoundation/UI/ProPlanSettingsSection.swift", depth: 3),
        .file("ThemeAppIconManager.swift", path: "Sources/AppFoundation/UI/ThemeAppIconManager.swift", depth: 3),
        .file("ThemePickerView.swift", path: "Sources/AppFoundation/UI/ThemePickerView.swift", depth: 3),
        .file("ThemeSwiftUI.swift", path: "Sources/AppFoundation/UI/ThemeSwiftUI.swift", depth: 3),
        .folder("WidgetShowcase", path: "Sources/AppFoundation/WidgetShowcase", depth: 2),
        .file("WidgetShowcaseCatalog.swift", path: "Sources/AppFoundation/WidgetShowcase/WidgetShowcaseCatalog.swift", depth: 3),
        .file("WidgetShowcaseDetailView.swift", path: "Sources/AppFoundation/WidgetShowcase/WidgetShowcaseDetailView.swift", depth: 3),
        .file("WidgetShowcaseView.swift", path: "Sources/AppFoundation/WidgetShowcase/WidgetShowcaseView.swift", depth: 3),
    ]

    static let apiGroups: [PackageDocumentationAPIGroup] = [
        group("Commerce", systemImage: "creditcard.fill", items: [
            api("PurchaseManager", kind: "manager", summary: "Preferred app-facing StoreKit manager with product loading, purchases, restore, entitlement refresh, and hasPro access.", source: "Sources/AppFoundation/Purchases/PurchaseController.swift", usage: "@State private var purchases = PurchaseManager(configuration: configuration)"),
            api("PurchaseController", kind: "manager", summary: "Source-compatible underlying purchase controller retained for existing apps.", source: "Sources/AppFoundation/Purchases/PurchaseController.swift"),
            api("PurchaseConfiguration", kind: "configuration", summary: "Defines entitlement product identifiers and the preferred product used by purchase views.", source: "Sources/AppFoundation/Core/PurchaseConfiguration.swift"),
            api("PurchaseProduct", kind: "model", summary: "App-facing product model used by live StoreKit and Debug purchase simulation.", source: "Sources/AppFoundation/Core/PurchaseState.swift"),
            api("PurchasePlanKind", kind: "enum", summary: "Normalizes weekly, monthly, yearly, and lifetime purchase plans.", source: "Sources/AppFoundation/Core/PurchasePlan.swift"),
            api("PurchasePlanDisclosure", kind: "view", summary: "Provides accurate recurring and one-time purchase disclosure copy for a product catalog.", source: "Sources/AppFoundation/UI/CommerceViews.swift"),
            api("PaywallView", kind: "view", summary: "Primary theme-aware paywall for the complete configured product catalog.", source: "Sources/AppFoundation/UI/FoundationPaywallView.swift", usage: "PaywallView(purchaseManager: purchases, configuration: configuration)"),
            api("FoundationPaywallView", kind: "view", summary: "Legacy-compatible AppFoundation paywall presentation.", source: "Sources/AppFoundation/UI/FoundationPaywallView.swift"),
            api("ClaudePaywallView", kind: "view", summary: "Alternate polished paywall style that still uses the shared purchase manager and active theme.", source: "Sources/AppFoundation/UI/ClaudePaywallView.swift"),
            api("PaywallConfiguration", kind: "configuration", summary: "Controls paywall title, copy, features, product emphasis, legal URLs, and theme overrides.", source: "Sources/AppFoundation/UI/FoundationPaywallView.swift"),
            api("PaywallFeature", kind: "model", summary: "One benefit row displayed by the package paywall views.", source: "Sources/AppFoundation/UI/FoundationPaywallView.swift"),
            api("ProPlanSettingsSection", kind: "view", summary: "Reusable subscription status, upgrade, restore, and plan-management section for app settings.", source: "Sources/AppFoundation/UI/ProPlanSettingsSection.swift"),
            api("PremiumFeature", kind: "model", summary: "Describes an app-owned feature evaluated by premium access policy.", source: "Sources/AppFoundation/UI/CommerceViews.swift"),
            api("PremiumAccessPolicy", kind: "policy", summary: "Decides whether creation, editing, or existing user content should remain available after entitlement changes.", source: "Sources/AppFoundation/UI/CommerceViews.swift"),
            api("PremiumGate", kind: "view", summary: "Switches between unlocked content and an app-provided locked presentation.", source: "Sources/AppFoundation/UI/CommerceViews.swift"),
            api("LockedFeatureOverlay", kind: "view", summary: "Reusable locked-feature presentation with an upgrade action.", source: "Sources/AppFoundation/UI/CommerceViews.swift"),
            api("LimitReachedUpsellFlow", kind: "view", summary: "Reusable limit-reached explanation that can continue into an app-provided paywall.", source: "Sources/AppFoundation/UI/LimitReachedUpsellView.swift"),
        ]),
        group("Themes", systemImage: "paintpalette.fill", items: [
            api("AppTheme", kind: "model", summary: "Theme definition containing colors, gradient, appearance values, symbols, and Pro metadata.", source: "Sources/AppFoundation/Themes/AppTheme.swift"),
            api("ThemeCatalog", kind: "catalog", summary: "Ordered set of available themes and the required fallback theme.", source: "Sources/AppFoundation/Themes/ThemeCatalog.swift"),
            api("ThemeManager", kind: "manager", summary: "Persists selection, exposes the effective theme, and manages timed Pro previews.", source: "Sources/AppFoundation/Themes/ThemeManager.swift", usage: "ThemePickerView(manager: themes, onRequestUpgrade: showPaywall)"),
            api("ThemeState", kind: "model", summary: "Persisted selection and preview state shared by theme state stores.", source: "Sources/AppFoundation/Themes/ThemeState.swift"),
            api("ThemeSelectionResult", kind: "enum", summary: "Reports whether selection succeeded or requires Pro access.", source: "Sources/AppFoundation/Themes/ThemeManager.swift"),
            api("ThemePickerView", kind: "view", summary: "Package-owned horizontal theme selector with selection state, locks, and optional preview countdown.", source: "Sources/AppFoundation/UI/ThemePickerView.swift", usage: "ThemePickerView(manager: themes, title: nil, onRequestUpgrade: { showPaywall = true })"),
            api("DefaultThemePreview", kind: "view", summary: "Default visual tile used by ThemePickerView when the app does not provide custom previews.", source: "Sources/AppFoundation/UI/ThemePickerView.swift"),
            api("UserDefaultsThemeStateStore", kind: "store", summary: "Persists theme state in standard UserDefaults.", source: "Sources/AppFoundation/Themes/ThemeState.swift"),
            api("AppGroupThemeStateStore", kind: "store", summary: "Persists theme state in an App Group so an app and widgets can share selection.", source: "Sources/AppFoundation/Themes/ThemeState.swift"),
            api("AppThemeBackground", kind: "view", summary: "Reusable full-screen background driven by an AppTheme.", source: "Sources/AppFoundation/UI/FoundationTheme.swift"),
            api("AppThemeCard", kind: "view", summary: "Theme-aware card surface using shared appearance and border values.", source: "Sources/AppFoundation/UI/FoundationTheme.swift"),
            api("FoundationPill", kind: "view", summary: "Compact themed label used across package-owned surfaces.", source: "Sources/AppFoundation/UI/FoundationTheme.swift"),
            api("appFoundationTheme(_:)", kind: "modifier", summary: "Applies the effective package theme to a SwiftUI hierarchy.", source: "Sources/AppFoundation/UI/ThemeSwiftUI.swift"),
            api("synchronizesThemeAccess(_:hasPro:)", kind: "modifier", summary: "Keeps theme preview and selection access synchronized with Pro entitlement.", source: "Sources/AppFoundation/UI/ThemeSwiftUI.swift"),
            api("ThemeAppIconManager", kind: "manager", summary: "Optional helper for mapping active themes to alternate app icons.", source: "Sources/AppFoundation/UI/ThemeAppIconManager.swift"),
        ]),
        group("Export", systemImage: "square.and.arrow.up.fill", items: [
            api("ExportImageFormat", kind: "enum", summary: "PNG or JPEG output definition with safe file-extension mapping.", source: "Sources/AppFoundation/Export/ExportKit.swift"),
            api("ExportRenderRequest", kind: "model", summary: "Validates output dimensions, scale, and maximum pixel count before rendering.", source: "Sources/AppFoundation/Export/ExportKit.swift"),
            api("ExportFile", kind: "model", summary: "Temporary export URL paired with the filename shown to the user.", source: "Sources/AppFoundation/Export/ExportKit.swift"),
            api("ExportError", kind: "error", summary: "Typed rendering, encoding, validation, and file-writing failures.", source: "Sources/AppFoundation/Export/ExportKit.swift"),
            api("ExportFilename", kind: "utility", summary: "Sanitizes user-provided filenames and file extensions.", source: "Sources/AppFoundation/Export/ExportKit.swift"),
            api("ExportFileWriter", kind: "actor", summary: "Atomically writes temporary export files and removes them after sharing.", source: "Sources/AppFoundation/Export/ExportKit.swift"),
            api("ViewImageExporter", kind: "renderer", summary: "Renders a SwiftUI view at exact dimensions, scale, opacity, corner radius, and format.", source: "Sources/AppFoundation/Export/ExportKit.swift", usage: "let data = try ViewImageExporter.render(view, size: size, format: .png)"),
            api("ExportShareSheet", kind: "view", summary: "UIKit-backed share sheet for one or more ExportFile values.", source: "Sources/AppFoundation/Export/ExportKit.swift"),
        ]),
        group("Backup", systemImage: "externaldrive.fill", items: [
            api("BackupEnvelope", kind: "model", summary: "Versioned Codable wrapper for an app-owned backup payload and metadata.", source: "Sources/AppFoundation/Backup/BackupKit.swift"),
            api("BackupAsset", kind: "model", summary: "Named binary asset stored alongside the JSON payload inside a backup package.", source: "Sources/AppFoundation/Backup/BackupKit.swift"),
            api("BackupPackageConfiguration", kind: "configuration", summary: "Defines format, version compatibility, app identity, and custom file extension.", source: "Sources/AppFoundation/Backup/BackupKit.swift"),
            api("BackupPackageManifest", kind: "model", summary: "Manifest containing compatibility fields, payload checksum, assets, and metadata.", source: "Sources/AppFoundation/Backup/BackupKit.swift"),
            api("BackupReadResult", kind: "model", summary: "Validated manifest, decoded payload, and restored assets returned by the reader.", source: "Sources/AppFoundation/Backup/BackupKit.swift"),
            api("BackupError", kind: "error", summary: "Typed format, version, application, corruption, checksum, path, and file-operation failures.", source: "Sources/AppFoundation/Backup/BackupKit.swift"),
            api("BackupChecksum", kind: "utility", summary: "Stable checksum helper used for accidental-corruption detection.", source: "Sources/AppFoundation/Backup/BackupKit.swift"),
            api("BackupPackageWriter", kind: "actor", summary: "Writes a folder-based custom backup package atomically.", source: "Sources/AppFoundation/Backup/BackupKit.swift", usage: "let url = try await BackupPackageWriter().write(envelope: envelope, configuration: configuration)"),
            api("BackupPackageReader", kind: "actor", summary: "Validates package identity and checksum before decoding app-owned data.", source: "Sources/AppFoundation/Backup/BackupKit.swift"),
            api("SecurityScopedURLAccess", kind: "utility", summary: "Runs work while a user-selected URL has security-scoped access.", source: "Sources/AppFoundation/Backup/BackupKit.swift"),
        ]),
        group("Screenshot Studio", systemImage: "photo.stack.fill", items: [
            api("ScreenshotStudioEngine", kind: "engine", summary: "Coordinates registered screenshot projects, selected screens, rendering, and export.", source: "Sources/AppFoundation/ScreenshotStudio/ScreenshotStudioEngine.swift"),
            api("ScreenshotStudioView", kind: "view", summary: "Package-owned mobile studio for previewing and exporting registered screenshot designs.", source: "Sources/AppFoundation/ScreenshotStudio/ScreenshotStudioView.swift"),
            api("ScreenshotStudioMacView", kind: "view", summary: "Desktop studio presentation for macOS workflows.", source: "Sources/AppFoundation/ScreenshotStudio/ScreenshotStudioMacView.swift"),
            api("ScreenshotStudioProject", kind: "model", summary: "App-owned screenshot project containing screens, presets, and registered SwiftUI content.", source: "Sources/AppFoundation/ScreenshotStudio/ScreenshotStudioModels.swift"),
            api("ScreenshotStudioScreen", kind: "model", summary: "One named exportable screen in a screenshot project.", source: "Sources/AppFoundation/ScreenshotStudio/ScreenshotStudioModels.swift"),
            api("ScreenshotOutputPreset", kind: "model", summary: "Reusable App Store and social output dimensions.", source: "Sources/AppFoundation/ScreenshotStudio/ScreenshotStudioModels.swift"),
            api("ScreenshotBackground", kind: "view", summary: "Reusable background shared by screenshot templates and demo fixtures.", source: "Sources/AppFoundation/ScreenshotStudio/Templates/ScreenshotTemplateComponents.swift"),
            api("ScreenshotPhoneFrame", kind: "view", summary: "Reusable phone framing component for app-owned screenshot content.", source: "Sources/AppFoundation/ScreenshotStudio/Components/ScreenshotSystemChrome.swift"),
            api("ScreenshotMacWindowFrame", kind: "view", summary: "Reusable macOS window framing component.", source: "Sources/AppFoundation/ScreenshotStudio/Components/ScreenshotMacWindowFrame.swift"),
        ]),
        group("Promo Video Studio", systemImage: "film.stack.fill", items: [
            api("PromoVideoProject", kind: "model", summary: "Registered video project containing scenes, output presets, frame rate, and motion defaults.", source: "Sources/AppFoundation/PromoVideoStudio/PromoVideoStudioTypes.swift"),
            api("PromoVideoSceneDefinition", kind: "model", summary: "One deterministic SwiftUI scene with duration, transition, metadata, and content builder.", source: "Sources/AppFoundation/PromoVideoStudio/PromoVideoStudioTypes.swift"),
            api("PromoVideoOutputPreset", kind: "model", summary: "Named video canvas dimensions for vertical, portrait, square, and app-owned formats.", source: "Sources/AppFoundation/PromoVideoStudio/PromoVideoStudioTypes.swift"),
            api("PromoVideoCompositionView", kind: "view", summary: "Renders a project at a precise timeline position using its scene and transition.", source: "Sources/AppFoundation/PromoVideoStudio/PromoVideoCompositionView.swift"),
            api("PromoVideoPreviewView", kind: "view", summary: "Interactive playback and scrub preview for a registered promo video project.", source: "Sources/AppFoundation/PromoVideoStudio/PromoVideoPreviewView.swift"),
            api("PromoVideoExporter", kind: "exporter", summary: "Renders deterministic SwiftUI frames into a silent MP4 file.", source: "Sources/AppFoundation/PromoVideoStudio/PromoVideoExporter.swift"),
            api("PromoVideoStudioControlContext", kind: "model", summary: "Selected-project and scene context supplied to app-owned control views.", source: "Sources/AppFoundation/PromoVideoStudio/PromoVideoStudioSupport.swift"),
            api("HeroIntroPromoVideoScene", kind: "template", summary: "Responsive hero introduction scene with brand, message, and visual regions.", source: "Sources/AppFoundation/PromoVideoStudio/Templates/PromoVideoStoryTemplates.swift"),
            api("DeviceRevealPromoVideoScene", kind: "template", summary: "Responsive scene that introduces a real app view inside a device presentation.", source: "Sources/AppFoundation/PromoVideoStudio/Templates/PromoVideoStoryTemplates.swift"),
            api("FeatureFocusPromoVideoScene", kind: "template", summary: "Responsive scene for explaining one capability with a focused visual and callout.", source: "Sources/AppFoundation/PromoVideoStudio/Templates/PromoVideoFeatureTemplates.swift"),
            api("AppFlowPromoVideoScene", kind: "template", summary: "Multi-step story scene for showing an app workflow in sequence.", source: "Sources/AppFoundation/PromoVideoStudio/Templates/PromoVideoStoryTemplates.swift"),
        ]),
        group("Platform & Utilities", systemImage: "shippingbox.fill", items: [
            api("AppMetadata", kind: "model", summary: "Reads version, build, display name, and bundle metadata for the current app.", source: "Sources/AppFoundation/Core/AppMetadata.swift"),
            api("AppGroupStore", kind: "actor", summary: "Typed Codable snapshot storage backed by an App Group container.", source: "Sources/AppFoundation/Platform/WidgetNotificationSupport.swift"),
            api("WidgetReloadCoordinator", kind: "actor", summary: "Throttles repeated WidgetKit reload requests during bursts of app changes.", source: "Sources/AppFoundation/Platform/WidgetNotificationSupport.swift"),
            api("LocalNotificationRequest", kind: "model", summary: "App-owned notification identifier, copy, and delivery date.", source: "Sources/AppFoundation/Platform/WidgetNotificationSupport.swift"),
            api("LocalNotificationManager", kind: "actor", summary: "Requests authorization and schedules, replaces, or cancels local notifications.", source: "Sources/AppFoundation/Platform/WidgetNotificationSupport.swift"),
            api("FoundationOnboardingView", kind: "view", summary: "Reusable multi-page onboarding presentation with an app-owned completion action.", source: "Sources/AppFoundation/UI/FoundationOnboardingView.swift"),
            api("FoundationSettingsView", kind: "view", summary: "Configurable package settings surface for subscription, support, legal, and app information rows.", source: "Sources/AppFoundation/UI/FoundationSettingsView.swift"),
            api("FoundationSettingsConfiguration", kind: "configuration", summary: "URLs, labels, and Pro-plan configuration consumed by package settings views.", source: "Sources/AppFoundation/UI/FoundationSettingsView.swift"),
            api("WidgetShowcaseCatalog", kind: "catalog", summary: "Registered widget designs and installation guidance for an app-owned gallery.", source: "Sources/AppFoundation/WidgetShowcase/WidgetShowcaseCatalog.swift"),
            api("WidgetShowcaseView", kind: "view", summary: "Mobile gallery for browsing registered widget designs.", source: "Sources/AppFoundation/WidgetShowcase/WidgetShowcaseView.swift"),
            api("WidgetShowcaseDetailView", kind: "view", summary: "Detail presentation for one widget design across supported families.", source: "Sources/AppFoundation/WidgetShowcase/WidgetShowcaseDetailView.swift"),
        ]),
    ]

    static var allAPIItems: [PackageDocumentationAPIItem] {
        apiGroups.flatMap(\.items)
    }

    private static func group(_ title: String, systemImage: String, items: [PackageDocumentationAPIItem]) -> PackageDocumentationAPIGroup {
        PackageDocumentationAPIGroup(title: title, systemImage: systemImage, items: items)
    }

    private static func api(_ name: String, kind: String, summary: String, source: String, usage: String? = nil) -> PackageDocumentationAPIItem {
        PackageDocumentationAPIItem(name: name, kind: kind, summary: summary, sourcePath: source, usage: usage)
    }
}
