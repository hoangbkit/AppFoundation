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

    public init(
        accentColor: Color,
        primaryTextColor: Color = .primary,
        secondaryTextColor: Color = .secondary,
        surfaceColor: Color = Color.primary.opacity(0.06),
        elevatedSurfaceColor: Color = Color.primary.opacity(0.1),
        borderColor: Color = Color.primary.opacity(0.12),
        backgroundColor: Color = .clear
    ) {
        self.accentColor = accentColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.surfaceColor = surfaceColor
        self.elevatedSurfaceColor = elevatedSurfaceColor
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
    }

    public static let standard = WidgetShowcaseStyle(accentColor: .accentColor)
}
#endif
