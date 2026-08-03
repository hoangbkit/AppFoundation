#if canImport(SwiftUI)
import SwiftUI

struct ProCrownIcon: View {
    @Environment(\.appFoundationTheme) private var theme
    @Environment(\.appFoundationVisualStyle) private var visualStyle

    private let size: CGFloat

    init(size: CGFloat = 100) {
        self.size = size
    }

    var body: some View {
        Group {
            switch visualStyle.surface {
            case .automatic, .material:
                ornateIcon
            case .solid, .plain:
                restrainedIcon
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var ornateIcon: some View {
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
                    color: crownShadowColor,
                    radius: crownShadowRadius,
                    y: crownShadowOffset
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
    }

    private var restrainedIcon: some View {
        ZStack {
            if visualStyle.surface != .plain {
                Circle()
                    .fill(theme.accentColor.opacity(0.12))
                    .overlay {
                        Circle().strokeBorder(theme.borderColor.opacity(0.65))
                    }
                    .frame(width: size * 0.76, height: size * 0.76)
            }

            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.accentColor)
                .shadow(
                    color: crownShadowColor,
                    radius: crownShadowRadius,
                    y: crownShadowOffset
                )
        }
    }

    private var crownShadowColor: Color {
        switch visualStyle.elevation {
        case .none:
            .clear
        case .subtle:
            theme.accentColor.opacity(0.18)
        case .automatic, .floating:
            theme.accentColor.opacity(0.38)
        }
    }

    private var crownShadowRadius: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: size * 0.055
        case .automatic, .floating: size * 0.11
        }
    }

    private var crownShadowOffset: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: size * 0.022
        case .automatic, .floating: size * 0.045
        }
    }

    private var gradient: LinearGradient {
        theme.gradient
    }
}
#endif
