#if canImport(SwiftUI) && canImport(AppFoundationWidgetShowcase)
import AppFoundationWidgetShowcase
import SwiftUI

public extension WidgetShowcaseStyle {
    /// Creates widget showcase tokens from the app's active color theme and
    /// AppFoundation visual style.
    init(theme: AppTheme, visualStyle: FoundationVisualStyle) {
        let usesSystemGroupedColors = visualStyle.background == .systemGrouped
        let backgroundColor: Color
        let gradientStartColor: Color
        let gradientEndColor: Color

        switch visualStyle.background {
        case .automatic, .atmospheric:
            backgroundColor = theme.backgroundColor
            gradientStartColor = theme.appearance.gradientStart.color.opacity(0.30)
            gradientEndColor = theme.appearance.gradientEnd.color.opacity(0.08)
        case .solid:
            backgroundColor = theme.backgroundColor
            gradientStartColor = .clear
            gradientEndColor = .clear
        case .systemGrouped:
            #if os(iOS) || os(tvOS) || os(visionOS)
            backgroundColor = Color(uiColor: .systemGroupedBackground)
            #elseif os(macOS)
            backgroundColor = Color(nsColor: .windowBackgroundColor)
            #else
            backgroundColor = theme.backgroundColor
            #endif
            gradientStartColor = .clear
            gradientEndColor = .clear
        }

        let surfaceColor: Color
        let elevatedSurfaceColor: Color
        switch visualStyle.surface {
        case .automatic, .solid:
            if usesSystemGroupedColors {
                surfaceColor = Self.systemGroupedSurface
                elevatedSurfaceColor = Self.systemGroupedElevatedSurface
            } else {
                surfaceColor = theme.surfaceColor
                elevatedSurfaceColor = theme.elevatedSurfaceColor
            }
        case .material:
            // WidgetShowcaseStyle stores concrete colors rather than ShapeStyle,
            // so use translucent theme surfaces as the closest portable mapping.
            surfaceColor = theme.surfaceColor.opacity(0.72)
            elevatedSurfaceColor = theme.elevatedSurfaceColor.opacity(0.78)
        case .plain:
            surfaceColor = .clear
            elevatedSurfaceColor = .clear
        }

        let shadowColor: Color
        switch visualStyle.elevation {
        case .none:
            shadowColor = .clear
        case .subtle:
            shadowColor = theme.appearance.shadow.color.opacity(0.45)
        case .automatic, .floating:
            shadowColor = theme.appearance.shadow.color
        }

        self.init(
            accentColor: theme.accentColor,
            primaryTextColor: usesSystemGroupedColors ? .primary : theme.primaryForegroundColor,
            secondaryTextColor: usesSystemGroupedColors ? .secondary : theme.secondaryForegroundColor,
            surfaceColor: surfaceColor,
            elevatedSurfaceColor: elevatedSurfaceColor,
            borderColor: visualStyle.surface == .plain
                ? .clear
                : (usesSystemGroupedColors ? Color.primary.opacity(0.10) : theme.borderColor),
            backgroundColor: backgroundColor,
            gradientStartColor: gradientStartColor,
            gradientEndColor: gradientEndColor,
            shadowColor: shadowColor
        )
    }

    private static var systemGroupedSurface: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.primary.opacity(0.06)
        #endif
    }

    private static var systemGroupedElevatedSurface: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(uiColor: .tertiarySystemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color.primary.opacity(0.10)
        #endif
    }
}
#endif
