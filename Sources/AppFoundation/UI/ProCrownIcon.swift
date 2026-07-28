#if canImport(SwiftUI)
import SwiftUI

struct ProCrownIcon: View {
    @Environment(\.appFoundationTheme) private var theme

    private let size: CGFloat

    init(size: CGFloat = 100) {
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.accentColor.opacity(0.24))
                .frame(width: size * 0.56, height: size * 0.56)
                .blur(radius: size * 0.2)

            Circle()
                .trim(from: 0.04, to: 0.34)
                .stroke(
                    gradient,
                    style: StrokeStyle(
                        lineWidth: max(1.5, size * 0.022),
                        lineCap: .round
                    )
                )
                .frame(width: size * 0.82, height: size * 0.82)
                .rotationEffect(.degrees(-22))

            Circle()
                .trim(from: 0.50, to: 0.88)
                .stroke(
                    gradient,
                    style: StrokeStyle(
                        lineWidth: max(1.5, size * 0.022),
                        lineCap: .round
                    )
                )
                .frame(width: size * 0.82, height: size * 0.82)
                .rotationEffect(.degrees(14))

            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.gradient)
                .shadow(
                    color: theme.accentColor.opacity(0.38),
                    radius: size * 0.11,
                    y: size * 0.045
                )

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.18, weight: .semibold))
                .foregroundStyle(theme.gradient)
                .offset(x: size * 0.34, y: -size * 0.28)

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.13, weight: .semibold))
                .foregroundStyle(theme.accentColor.opacity(0.82))
                .offset(x: -size * 0.34, y: -size * 0.10)

            Image(systemName: "diamond.fill")
                .font(.system(size: size * 0.08, weight: .semibold))
                .foregroundStyle(theme.accentColor.opacity(0.72))
                .offset(x: size * 0.30, y: size * 0.25)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var gradient: LinearGradient {
        theme.gradient
    }
}
#endif
