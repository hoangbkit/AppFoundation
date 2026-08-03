import Foundation

/// Controls the shared visual language used by AppFoundation's built-in SwiftUI views.
///
/// `AppTheme` continues to own semantic colors. `FoundationVisualStyle` controls
/// presentation decisions such as background treatment, materials, elevation,
/// control shape, and navigation chrome.
public struct FoundationVisualStyle: Codable, Hashable, Sendable {
    public enum Background: String, Codable, CaseIterable, Hashable, Sendable {
        /// Preserve the built-in view's historical background treatment.
        case automatic
        case atmospheric
        case solid
        case systemGrouped
    }

    public enum Surface: String, Codable, CaseIterable, Hashable, Sendable {
        /// Preserve the built-in component's historical surface treatment.
        case automatic
        case solid
        case material
        case plain
    }

    public enum Elevation: String, Codable, CaseIterable, Hashable, Sendable {
        /// Preserve the built-in component's historical shadow treatment.
        case automatic
        case none
        case subtle
        case floating
    }

    public enum PrimaryAction: String, Codable, CaseIterable, Hashable, Sendable {
        /// Preserve the built-in component's historical primary action treatment.
        case automatic
        case system
        case filled
        case gradient
        case monochrome
    }

    public enum NavigationChrome: String, Codable, CaseIterable, Hashable, Sendable {
        /// Preserve the built-in view's historical toolbar treatment.
        case automatic
        case system
        case transparent
    }

    public let background: Background
    public let surface: Surface
    public let elevation: Elevation
    public let primaryAction: PrimaryAction
    public let navigationChrome: NavigationChrome

    /// Overrides the theme's component corner radius when non-nil.
    public let cornerRadius: Double?

    public init(
        background: Background = .automatic,
        surface: Surface = .automatic,
        elevation: Elevation = .automatic,
        primaryAction: PrimaryAction = .automatic,
        navigationChrome: NavigationChrome = .automatic,
        cornerRadius: Double? = nil
    ) {
        self.background = background
        self.surface = surface
        self.elevation = elevation
        self.primaryAction = primaryAction
        self.navigationChrome = navigationChrome
        self.cornerRadius = cornerRadius.map { max(0, $0) }
    }

    /// The original AppFoundation visual language. This is the default so
    /// existing apps retain their current appearance after upgrading.
    public static let signature = FoundationVisualStyle()

    /// Native grouped backgrounds, restrained corners, system-like actions,
    /// and no floating card shadows.
    public static let native = FoundationVisualStyle(
        background: .systemGrouped,
        surface: .solid,
        elevation: .none,
        primaryAction: .system,
        navigationChrome: .system,
        cornerRadius: 12
    )

    /// Solid app colors with compact cards and no atmospheric glow or elevation.
    public static let flat = FoundationVisualStyle(
        background: .solid,
        surface: .solid,
        elevation: .none,
        primaryAction: .filled,
        navigationChrome: .system,
        cornerRadius: 10
    )

    /// Material surfaces over the existing atmospheric background treatment.
    public static let glass = FoundationVisualStyle(
        background: .atmospheric,
        surface: .material,
        elevation: .subtle,
        primaryAction: .monochrome,
        navigationChrome: .transparent,
        cornerRadius: 26
    )
}

#if canImport(SwiftUI)
import SwiftUI

private struct AppFoundationVisualStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue = FoundationVisualStyle.signature
}

public extension EnvironmentValues {
    var appFoundationVisualStyle: FoundationVisualStyle {
        get { self[AppFoundationVisualStyleEnvironmentKey.self] }
        set { self[AppFoundationVisualStyleEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// Installs a visual style for every AppFoundation built-in view below this view.
    func appFoundationStyle(_ style: FoundationVisualStyle) -> some View {
        environment(\.appFoundationVisualStyle, style)
    }
}

extension FoundationVisualStyle {
    func resolvedCornerRadius(fallback: CGFloat) -> CGFloat {
        cornerRadius.map { CGFloat($0) } ?? fallback
    }

    var usesVisibleNavigationChrome: Bool {
        navigationChrome == .system
    }

    var toolbarVisibility: Visibility {
        usesVisibleNavigationChrome ? .visible : .hidden
    }

    var preservesLegacyPresentation: Bool {
        self == .signature
    }

    func resolvedFontDesign(fallback: Font.Design) -> Font.Design {
        switch surface {
        case .automatic:
            fallback
        case .material:
            .rounded
        case .solid, .plain:
            .default
        }
    }
}

extension View {
    /// Applies the selected AppFoundation surface, border, radius, and elevation
    /// while allowing each component to supply its semantic theme colors.
    func foundationVisualSurface(
        solidColor: Color,
        borderColor: Color,
        shadowColor: Color,
        fallbackCornerRadius: CGFloat,
        borderLineWidth: CGFloat = 1,
        fallbackShadowRadius: CGFloat = 18,
        fallbackShadowOffset: CGFloat = 10
    ) -> some View {
        modifier(
            FoundationVisualSurfaceModifier(
                solidColor: solidColor,
                borderColor: borderColor,
                shadowColor: shadowColor,
                fallbackCornerRadius: fallbackCornerRadius,
                borderLineWidth: borderLineWidth,
                fallbackShadowRadius: fallbackShadowRadius,
                fallbackShadowOffset: fallbackShadowOffset
            )
        )
    }
}

private struct FoundationVisualSurfaceModifier: ViewModifier {
    @Environment(\.appFoundationVisualStyle) private var visualStyle

    let solidColor: Color
    let borderColor: Color
    let shadowColor: Color
    let fallbackCornerRadius: CGFloat
    let borderLineWidth: CGFloat
    let fallbackShadowRadius: CGFloat
    let fallbackShadowOffset: CGFloat

    func body(content: Content) -> some View {
        let radius = visualStyle.resolvedCornerRadius(fallback: fallbackCornerRadius)

        content
            .background { surfaceBackground(radius: radius) }
            .overlay { surfaceBorder(radius: radius) }
            .shadow(
                color: resolvedShadowColor,
                radius: resolvedShadowRadius,
                y: resolvedShadowOffset
            )
    }

    @ViewBuilder
    private func surfaceBackground(radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        switch visualStyle.surface {
        case .automatic, .solid:
            shape.fill(solidColor)
        case .material:
            shape.fill(.regularMaterial)
        case .plain:
            shape.fill(.clear)
        }
    }

    @ViewBuilder
    private func surfaceBorder(radius: CGFloat) -> some View {
        if visualStyle.surface != .plain {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: borderLineWidth)
        }
    }

    private var resolvedShadowColor: Color {
        guard visualStyle.surface != .plain else { return Color.clear }

        switch visualStyle.elevation {
        case .none:
            return Color.clear
        case .subtle:
            return shadowColor.opacity(0.5)
        case .automatic, .floating:
            return shadowColor
        }
    }

    private var resolvedShadowRadius: CGFloat {
        switch visualStyle.elevation {
        case .automatic:
            fallbackShadowRadius
        case .none:
            0
        case .subtle:
            fallbackShadowRadius > 0 ? max(4, fallbackShadowRadius * 0.5) : 6
        case .floating:
            max(14, fallbackShadowRadius)
        }
    }

    private var resolvedShadowOffset: CGFloat {
        switch visualStyle.elevation {
        case .automatic:
            fallbackShadowOffset
        case .none:
            0
        case .subtle:
            fallbackShadowOffset > 0 ? max(2, fallbackShadowOffset * 0.5) : 3
        case .floating:
            max(7, fallbackShadowOffset)
        }
    }
}
#endif
