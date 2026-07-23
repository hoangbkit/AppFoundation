#if canImport(SwiftUI)
import SwiftUI

public struct WidgetShowcaseStyle: Sendable {
    public let accentColor: Color
    public let primaryTextColor: Color
    public let secondaryTextColor: Color
    public let surfaceColor: Color
    public let elevatedSurfaceColor: Color
    public let borderColor: Color
    public let backgroundColor: Color
    public let gradientStartColor: Color
    public let gradientEndColor: Color
    public let shadowColor: Color

    public init(
        accentColor: Color,
        primaryTextColor: Color = .primary,
        secondaryTextColor: Color = .secondary,
        surfaceColor: Color = Color.primary.opacity(0.06),
        elevatedSurfaceColor: Color = Color.primary.opacity(0.10),
        borderColor: Color = Color.primary.opacity(0.12),
        backgroundColor: Color = .clear,
        gradientStartColor: Color? = nil,
        gradientEndColor: Color? = nil,
        shadowColor: Color = .black.opacity(0.10)
    ) {
        self.accentColor = accentColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.surfaceColor = surfaceColor
        self.elevatedSurfaceColor = elevatedSurfaceColor
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
        self.gradientStartColor = gradientStartColor ?? accentColor.opacity(0.30)
        self.gradientEndColor = gradientEndColor ?? accentColor.opacity(0.06)
        self.shadowColor = shadowColor
    }

    public static let standard = WidgetShowcaseStyle(accentColor: .accentColor)
}
#endif
