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
    private let theme: FoundationTheme

    public init(theme: FoundationTheme = .indigo) {
        self.theme = theme
    }

    public var body: some View {
        theme.background
            .ignoresSafeArea()
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
            .accessibilityHidden(true)
    }
}

public struct FoundationCard<Content: View>: View {
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
        content
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .stroke(.white.opacity(0.20), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
    }
}

public struct FoundationPill: View {
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
        .background(tint.opacity(0.12), in: Capsule())
    }
}

public struct FoundationPrimaryButtonStyle: ButtonStyle {
    private let theme: FoundationTheme

    public init(theme: FoundationTheme = .indigo) {
        self.theme = theme
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [theme.primary, theme.secondary],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .shadow(color: theme.primary.opacity(0.28), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
#endif
