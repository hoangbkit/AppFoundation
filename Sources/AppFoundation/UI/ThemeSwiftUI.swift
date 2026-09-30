#if canImport(SwiftUI)
import SwiftUI

public extension ThemeColor {
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

public extension ThemePreferredColorScheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

public extension ThemeAppearance {
    var gradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart.color, gradientEnd.color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public extension AppTheme {
    var gradient: LinearGradient { appearance.gradient }
    var accentColor: Color { appearance.accent.color }
    var backgroundColor: Color { appearance.background.color }
    var primaryForegroundColor: Color { appearance.primaryForeground.color }
    var secondaryForegroundColor: Color { appearance.secondaryForeground.color }
    var surfaceColor: Color { appearance.surface.color }
    var elevatedSurfaceColor: Color { appearance.elevatedSurface.color }
    var borderColor: Color { appearance.border.color }
}

public extension FoundationTheme {
    init(_ appTheme: AppTheme) {
        self.init(
            primary: appTheme.appearance.gradientStart.color,
            secondary: appTheme.appearance.gradientEnd.color,
            background: appTheme.backgroundColor,
            cardCornerRadius: CGFloat(appTheme.appearance.cardCornerRadius)
        )
    }
}

public extension FoundationBackground {
    init(theme: AppTheme) {
        self.init(theme: FoundationTheme(theme))
    }
}

public extension FoundationCard {
    init(theme: AppTheme, @ViewBuilder content: () -> Content) {
        self.init(theme: FoundationTheme(theme), content: content)
    }
}

public extension FoundationPrimaryButtonStyle {
    init(theme: AppTheme) {
        self.init(theme: FoundationTheme(theme))
    }
}

private struct AppFoundationThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = FoundationThemes.rose
}

public extension EnvironmentValues {
    var appFoundationTheme: AppTheme {
        get { self[AppFoundationThemeEnvironmentKey.self] }
        set { self[AppFoundationThemeEnvironmentKey.self] = newValue }
    }
}

private struct AppFoundationThemeModifier: ViewModifier {
    let manager: ThemeManager

    func body(content: Content) -> some View {
        let theme = manager.effectiveTheme
        content
            .environment(\.appFoundationTheme, theme)
            .tint(theme.accentColor)
            .preferredColorScheme(theme.appearance.preferredColorScheme.colorScheme)
    }
}

private struct ThemeAccessSynchronizationModifier: ViewModifier {
    let manager: ThemeManager
    let hasPro: Bool

    func body(content: Content) -> some View {
        content.task(id: hasPro) {
            manager.synchronizeProAccess(hasPro)
        }
    }
}

#if canImport(Observation) && canImport(StoreKit)
private struct ThemePurchaseAccessState: Equatable {
    let entitlementState: EntitlementState
    let hasPro: Bool
}

private struct AppFoundationEntitledThemeModifier: ViewModifier {
    let manager: ThemeManager
    let purchaseManager: PurchaseManager

    func body(content: Content) -> some View {
        let entitlementState = purchaseManager.entitlementState
        let hasPro = purchaseManager.hasPro
        let theme = manager.effectiveTheme(
            entitlementState: entitlementState,
            hasPro: hasPro
        )
        let synchronizationState = ThemePurchaseAccessState(
            entitlementState: entitlementState,
            hasPro: hasPro
        )

        content
            .environment(\.appFoundationTheme, theme)
            .tint(theme.accentColor)
            .preferredColorScheme(theme.appearance.preferredColorScheme.colorScheme)
            .task(id: synchronizationState) {
                manager.synchronizeProAccess(
                    hasPro,
                    entitlementState: entitlementState
                )
            }
    }
}
#endif

public extension View {
    func appFoundationTheme(_ manager: ThemeManager) -> some View {
        modifier(AppFoundationThemeModifier(manager: manager))
    }

    #if canImport(Observation) && canImport(StoreKit)
    /// Injects the active theme using PurchaseManager-aware access resolution.
    ///
    /// During entitlement checking, the theme resolves against the last verified
    /// persisted access state until StoreKit provides a newer result.
    func appFoundationTheme(
        _ manager: ThemeManager,
        purchaseManager: PurchaseManager
    ) -> some View {
        modifier(
            AppFoundationEntitledThemeModifier(
                manager: manager,
                purchaseManager: purchaseManager
            )
        )
    }
    #endif

    func synchronizesThemeAccess(_ manager: ThemeManager, hasPro: Bool) -> some View {
        modifier(ThemeAccessSynchronizationModifier(manager: manager, hasPro: hasPro))
    }
}

public struct AppThemeBackground: View {
    private let theme: AppTheme

    public init(theme: AppTheme) {
        self.theme = theme
    }

    public var body: some View {
        ZStack {
            theme.backgroundColor
            theme.gradient
                .opacity(0.24)
                .blur(radius: 32)
                .scaleEffect(1.18)
            RadialGradient(
                colors: [theme.accentColor.opacity(0.30), .clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 520
            )
            LinearGradient(
                colors: [.white.opacity(0.035), .clear, .black.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

public struct AppThemeCard<Content: View>: View {
    private let theme: AppTheme
    private let content: Content

    public init(theme: AppTheme, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    public var body: some View {
        content
            .padding(18)
            .background(
                theme.surfaceColor,
                in: RoundedRectangle(
                    cornerRadius: CGFloat(theme.appearance.cardCornerRadius),
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: CGFloat(theme.appearance.cardCornerRadius),
                    style: .continuous
                )
                .stroke(theme.borderColor, lineWidth: 1)
            }
            .shadow(
                color: theme.appearance.shadow.color,
                radius: 18,
                y: 10
            )
    }
}
#endif
