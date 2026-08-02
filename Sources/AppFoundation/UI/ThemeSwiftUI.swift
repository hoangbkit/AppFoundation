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

public extension View {
    func appFoundationTheme(_ manager: ThemeManager) -> some View {
        modifier(AppFoundationThemeModifier(manager: manager))
    }

    func synchronizesThemeAccess(_ manager: ThemeManager, hasPro: Bool) -> some View {
        modifier(ThemeAccessSynchronizationModifier(manager: manager, hasPro: hasPro))
    }
}

public struct AppThemeBackground: View {
    @Environment(\.appFoundationVisualStyle) private var visualStyle

    private let theme: AppTheme

    public init(theme: AppTheme) {
        self.theme = theme
    }

    public var body: some View {
        backgroundContent
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var backgroundContent: some View {
        switch visualStyle.background {
        case .automatic, .atmospheric:
            atmosphericBackground
        case .solid:
            theme.backgroundColor
        case .systemGrouped:
            systemGroupedBackground
        }
    }

    private var atmosphericBackground: some View {
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
    }

    private var systemGroupedBackground: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(uiColor: .systemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        theme.backgroundColor
        #endif
    }
}

public struct AppThemeCard<Content: View>: View {
    @Environment(\.appFoundationVisualStyle) private var visualStyle

    private let theme: AppTheme
    private let content: Content

    public init(theme: AppTheme, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    public var body: some View {
        let radius = visualStyle.resolvedCornerRadius(
            fallback: CGFloat(theme.appearance.cardCornerRadius)
        )

        content
            .padding(18)
            .background { cardBackground(radius: radius) }
            .overlay { cardBorder(radius: radius) }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffset)
    }

    @ViewBuilder
    private func cardBackground(radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        switch visualStyle.surface {
        case .automatic, .solid:
            shape.fill(theme.surfaceColor)
        case .material:
            shape.fill(.regularMaterial)
        case .plain:
            shape.fill(.clear)
        }
    }

    @ViewBuilder
    private func cardBorder(radius: CGFloat) -> some View {
        if visualStyle.surface != .plain {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        }
    }

    private var shadowColor: Color {
        switch visualStyle.elevation {
        case .none:
            .clear
        case .subtle:
            theme.appearance.shadow.color.opacity(0.55)
        case .automatic, .floating:
            theme.appearance.shadow.color
        }
    }

    private var shadowRadius: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: 8
        case .automatic, .floating: 18
        }
    }

    private var shadowOffset: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: 4
        case .automatic, .floating: 10
        }
    }
}
#endif
