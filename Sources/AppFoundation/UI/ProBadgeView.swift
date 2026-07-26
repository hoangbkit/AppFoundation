#if canImport(SwiftUI)
import SwiftUI

/// A compact, reusable label for content that requires Pro access.
///
/// AppFoundation uses this view throughout its pickers, and apps can use the
/// same component in their own settings rows, cards, and feature labels.
public struct ProBadgeView: View {
    @Environment(\.appFoundationTheme) private var theme

    private let tint: Color?

    public init(tint: Color? = nil) {
        self.tint = tint
    }

    public var body: some View {
        Text("PRO")
            .font(.caption2.weight(.black))
            .foregroundStyle(tint ?? theme.accentColor)
            .accessibilityLabel("Pro")
    }
}

public typealias ProBadge = ProBadgeView
#endif
