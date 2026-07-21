#if canImport(SwiftUI)
import SwiftUI

/// Resolved visual tokens shared by every paywall style.
///
/// Paywalls follow the active `AppTheme` supplied by `.appFoundationTheme(_:)`.
/// A configuration-level override can still provide an isolated visual treatment.
struct PaywallThemeTokens {
    let accent: Color
    let secondaryAccent: Color
    let background: Color
    let primaryForeground: Color
    let secondaryForeground: Color
    let surface: Color
    let elevatedSurface: Color
    let border: Color
    let shadow: Color
    let cardCornerRadius: CGFloat
    let preferredColorScheme: ColorScheme?

    init(
        appTheme: AppTheme,
        accentOverride: Color? = nil,
        foundationOverride: FoundationTheme? = nil
    ) {
        if let foundationOverride {
            accent = accentOverride ?? foundationOverride.primary
            secondaryAccent = foundationOverride.secondary
            background = foundationOverride.background
            primaryForeground = .primary
            secondaryForeground = .secondary
            surface = Color(uiColor: .secondarySystemGroupedBackground)
            elevatedSurface = Color(uiColor: .tertiarySystemGroupedBackground)
            border = Color.primary.opacity(0.10)
            shadow = Color.black.opacity(0.10)
            cardCornerRadius = foundationOverride.cardCornerRadius
            preferredColorScheme = nil
        } else {
            accent = accentOverride ?? appTheme.accentColor
            secondaryAccent = appTheme.appearance.gradientEnd.color
            background = appTheme.backgroundColor
            primaryForeground = appTheme.primaryForegroundColor
            secondaryForeground = appTheme.secondaryForegroundColor
            surface = appTheme.surfaceColor
            elevatedSurface = appTheme.elevatedSurfaceColor
            border = appTheme.borderColor
            shadow = appTheme.appearance.shadow.color
            cardCornerRadius = CGFloat(appTheme.appearance.cardCornerRadius)
            preferredColorScheme = appTheme.appearance.preferredColorScheme.colorScheme
        }
    }

    var foundationTheme: FoundationTheme {
        FoundationTheme(
            primary: accent,
            secondary: secondaryAccent,
            background: background,
            cardCornerRadius: cardCornerRadius
        )
    }
}

struct PaywallThemeBackground: View {
    let tokens: PaywallThemeTokens

    var body: some View {
        ZStack {
            tokens.background

            LinearGradient(
                colors: [
                    tokens.accent.opacity(0.24),
                    tokens.secondaryAccent.opacity(0.16),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 38)
            .scaleEffect(1.18)

            RadialGradient(
                colors: [tokens.accent.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
#endif
