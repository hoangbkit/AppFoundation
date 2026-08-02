#if canImport(SwiftUI)
import SwiftUI

public struct FoundationTheme: Sendable {
    public let primary: Color
    public let secondary: Color
    public let background: Color
    public let cardCornerRadius: CGFloat

    public init(
        primary: Color,
        secondary: Color,
        background: Color = Color(uiColor: .systemGroupedBackground),
        cardCornerRadius: CGFloat = 28
    ) {
        self.primary = primary
        self.secondary = secondary
        self.background = background
        self.cardCornerRadius = cardCornerRadius
    }

    public static let indigo = FoundationTheme(
        primary: Color(red: 0.30, green: 0.25, blue: 0.95),
        secondary: Color(red: 0.78, green: 0.30, blue: 0.95)
    )
}

public struct FoundationBackground: View {
    @Environment(\.appFoundationVisualStyle) private var visualStyle

    private let theme: FoundationTheme

    public init(theme: FoundationTheme = .indigo) {
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
            theme.background
        case .systemGrouped:
            systemGroupedBackground
        }
    }

    private var atmosphericBackground: some View {
        theme.background
            .overlay {
                ZStack {
                    Circle()
                        .fill(theme.primary.opacity(0.20))
                        .frame(width: 360, height: 360)
                        .blur(radius: 80)
                        .offset(x: -180, y: -300)

                    Circle()
                        .fill(theme.secondary.opacity(0.16))
                        .frame(width: 420, height: 420)
                        .blur(radius: 100)
                        .offset(x: 180, y: 340)
                }
            }
    }

    private var systemGroupedBackground: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(uiColor: .systemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        theme.background
        #endif
    }
}

public struct FoundationCard<Content: View>: View {
    @Environment(\.appFoundationVisualStyle) private var visualStyle

    private let theme: FoundationTheme
    private let content: Content

    public init(
        theme: FoundationTheme = .indigo,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        self.content = content()
    }

    public var body: some View {
        let radius = visualStyle.resolvedCornerRadius(fallback: theme.cardCornerRadius)

        content
            .padding(20)
            .background { cardBackground(radius: radius) }
            .overlay { cardBorder(radius: radius) }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffset)
    }

    @ViewBuilder
    private func cardBackground(radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        switch visualStyle.surface {
        case .automatic, .material:
            shape.fill(.regularMaterial)
        case .solid:
            shape.fill(theme.background)
        case .plain:
            shape.fill(.clear)
        }
    }

    @ViewBuilder
    private func cardBorder(radius: CGFloat) -> some View {
        if visualStyle.surface != .plain {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
    }

    private var borderColor: Color {
        switch visualStyle.surface {
        case .automatic, .material:
            .white.opacity(0.20)
        case .solid:
            .primary.opacity(0.10)
        case .plain:
            .clear
        }
    }

    private var shadowColor: Color {
        switch visualStyle.elevation {
        case .none:
            .clear
        case .subtle:
            .black.opacity(0.05)
        case .automatic, .floating:
            .black.opacity(0.08)
        }
    }

    private var shadowRadius: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: 8
        case .automatic, .floating: 24
        }
    }

    private var shadowOffset: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: 4
        case .automatic, .floating: 12
        }
    }
}

public struct FoundationPill: View {
    @Environment(\.appFoundationVisualStyle) private var visualStyle

    private let text: String
    private let systemImage: String?
    private let tint: Color

    public init(_ text: String, systemImage: String? = nil, tint: Color) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        Label {
            Text(text)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            tint.opacity(backgroundOpacity),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    private var cornerRadius: CGFloat {
        switch visualStyle.surface {
        case .automatic, .material: 999
        case .solid, .plain: 7
        }
    }

    private var backgroundOpacity: Double {
        visualStyle.surface == .plain ? 0.07 : 0.12
    }
}

public struct FoundationPrimaryButtonStyle: ButtonStyle {
    @Environment(\.appFoundationVisualStyle) private var visualStyle

    private let theme: FoundationTheme

    public init(theme: FoundationTheme = .indigo) {
        self.theme = theme
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background { buttonBackground(isPressed: configuration.isPressed) }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffset)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }

    @ViewBuilder
    private func buttonBackground(isPressed: Bool) -> some View {
        let radius = buttonCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        switch visualStyle.primaryAction {
        case .automatic, .gradient:
            shape.fill(
                LinearGradient(
                    colors: [theme.primary, theme.secondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .system, .filled:
            shape.fill(theme.primary.opacity(isPressed ? 0.82 : 1))
        case .monochrome:
            shape.fill(Color.white.opacity(isPressed ? 0.84 : 1))
        }
    }

    private var foregroundColor: Color {
        visualStyle.primaryAction == .monochrome ? .black : .white
    }

    private var buttonCornerRadius: CGFloat {
        let fallback: CGFloat
        switch visualStyle.primaryAction {
        case .system: fallback = 12
        case .filled: fallback = 14
        case .automatic, .gradient, .monochrome: fallback = 18
        }
        return visualStyle.resolvedCornerRadius(fallback: fallback)
    }

    private var shadowColor: Color {
        switch visualStyle.elevation {
        case .none:
            .clear
        case .subtle:
            theme.primary.opacity(0.14)
        case .automatic, .floating:
            theme.primary.opacity(0.28)
        }
    }

    private var shadowRadius: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: 7
        case .automatic, .floating: 16
        }
    }

    private var shadowOffset: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: 3
        case .automatic, .floating: 8
        }
    }
}
#endif
