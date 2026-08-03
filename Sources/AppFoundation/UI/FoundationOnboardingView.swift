#if canImport(SwiftUI)
import SwiftUI

public struct FoundationOnboardingPage: Identifiable, Hashable, Sendable {
    public let id: String
    public let systemImage: String
    public let eyebrow: String
    public let title: String
    public let message: String

    public init(
        id: String,
        systemImage: String,
        eyebrow: String,
        title: String,
        message: String
    ) {
        self.id = id
        self.systemImage = systemImage
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
    }
}

public struct FoundationOnboardingView: View {
    @Environment(\.appFoundationTheme) private var environmentTheme
    @Environment(\.appFoundationVisualStyle) private var visualStyle

    private let pages: [FoundationOnboardingPage]
    private let fixedTheme: FoundationTheme?
    private let completionTitle: String
    private let onCompletion: @MainActor () -> Void

    @State private var selectedPage = 0

    /// Creates onboarding that follows the active theme installed with
    /// `.appFoundationTheme(_:)`.
    public init(
        pages: [FoundationOnboardingPage],
        completionTitle: String = "Get Started",
        onCompletion: @escaping @MainActor () -> Void
    ) {
        self.pages = Self.normalizedPages(pages)
        self.fixedTheme = nil
        self.completionTitle = completionTitle
        self.onCompletion = onCompletion
    }

    /// Creates onboarding with a fixed legacy `FoundationTheme` override.
    public init(
        pages: [FoundationOnboardingPage],
        theme: FoundationTheme,
        completionTitle: String = "Get Started",
        onCompletion: @escaping @MainActor () -> Void
    ) {
        self.pages = Self.normalizedPages(pages)
        self.fixedTheme = theme
        self.completionTitle = completionTitle
        self.onCompletion = onCompletion
    }

    public var body: some View {
        ZStack {
            background

            VStack(spacing: 24) {
                HStack {
                    FoundationPill("WELCOME", systemImage: "sparkles", tint: resolvedTheme.primary)
                    Spacer()
                    if selectedPage < pages.count - 1 {
                        Button("Skip") {
                            onCompletion()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(secondaryForeground)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        pageView(page)
                            .tag(index)
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator

                Button(selectedPage == pages.count - 1 ? completionTitle : "Continue") {
                    if selectedPage == pages.count - 1 {
                        onCompletion()
                    } else {
                        withAnimation(.snappy) {
                            selectedPage += 1
                        }
                    }
                }
                .buttonStyle(
                    FoundationOnboardingButtonStyle(
                        theme: resolvedTheme,
                        accentForeground: actionAccentForeground
                    )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
        .foregroundStyle(primaryForeground)
        .tint(resolvedTheme.primary)
        .preferredColorScheme(preferredColorScheme)
        .animation(.smooth, value: animationThemeID)
    }

    @ViewBuilder
    private var background: some View {
        if fixedTheme == nil {
            AppThemeBackground(theme: environmentTheme)
        } else {
            FoundationBackground(theme: resolvedTheme)
        }
    }

    private func pageView(_ page: FoundationOnboardingPage) -> some View {
        VStack {
            Spacer(minLength: 8)
            pageContent(page)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 8)
    }

    private func pageContent(_ page: FoundationOnboardingPage) -> some View {
        VStack(spacing: 0) {
            ZStack {
                iconBackground

                Circle()
                    .strokeBorder(resolvedTheme.primary.opacity(iconBorderOpacity))

                Image(systemName: page.systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(resolvedTheme.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 88, height: 88)
            .shadow(
                color: iconShadowColor,
                radius: iconShadowRadius,
                y: iconShadowOffset
            )
            .padding(.bottom, 24)

            Text(page.eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(resolvedTheme.primary)
                .padding(.bottom, 9)

            Text(page.title)
                .font(.system(size: 30, weight: .bold, design: titleFontDesign))
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            Text(page.message)
                .font(.body)
                .foregroundStyle(secondaryForeground)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var iconBackground: some View {
        switch visualStyle.surface {
        case .automatic, .material:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            resolvedTheme.primary.opacity(0.20),
                            resolvedTheme.secondary.opacity(0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .solid:
            Circle().fill(resolvedTheme.primary.opacity(0.12))
        case .plain:
            Circle().fill(.clear)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? resolvedTheme.primary : secondaryForeground.opacity(0.22))
                    .frame(width: index == selectedPage ? 28 : 8, height: 8)
                    .animation(.snappy, value: selectedPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(selectedPage + 1) of \(pages.count)")
    }

    private var resolvedTheme: FoundationTheme {
        fixedTheme ?? FoundationTheme(environmentTheme)
    }

    private var primaryForeground: Color {
        if visualStyle.background == .systemGrouped {
            return .primary
        }
        return fixedTheme == nil ? environmentTheme.primaryForegroundColor : .primary
    }

    private var secondaryForeground: Color {
        if visualStyle.background == .systemGrouped {
            return .secondary
        }
        return fixedTheme == nil ? environmentTheme.secondaryForegroundColor : .secondary
    }

    private var actionAccentForeground: Color {
        guard fixedTheme == nil else { return .white }
        let accent = environmentTheme.appearance.accent
        let luminance = 0.2126 * accent.red + 0.7152 * accent.green + 0.0722 * accent.blue
        return luminance > 0.58 ? .black : .white
    }

    private var preferredColorScheme: ColorScheme? {
        fixedTheme == nil ? environmentTheme.appearance.preferredColorScheme.colorScheme : nil
    }

    private var animationThemeID: String {
        fixedTheme == nil ? environmentTheme.id : "fixed"
    }

    private var titleFontDesign: Font.Design {
        visualStyle.resolvedFontDesign(fallback: .rounded)
    }

    private var iconBorderOpacity: Double {
        visualStyle.surface == .plain ? 0 : 0.18
    }

    private var iconShadowColor: Color {
        switch visualStyle.elevation {
        case .none:
            .clear
        case .subtle:
            resolvedTheme.primary.opacity(0.08)
        case .automatic, .floating:
            resolvedTheme.primary.opacity(0.14)
        }
    }

    private var iconShadowRadius: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: 7
        case .automatic, .floating: 16
        }
    }

    private var iconShadowOffset: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: 3
        case .automatic, .floating: 8
        }
    }

    private static func normalizedPages(
        _ pages: [FoundationOnboardingPage]
    ) -> [FoundationOnboardingPage] {
        pages.isEmpty
            ? [
                FoundationOnboardingPage(
                    id: "welcome",
                    systemImage: "sparkles",
                    eyebrow: "Welcome",
                    title: "Ready to begin",
                    message: "Continue to start using the app."
                )
            ]
            : pages
    }
}

private struct FoundationOnboardingButtonStyle: ButtonStyle {
    @Environment(\.appFoundationVisualStyle) private var visualStyle

    let theme: FoundationTheme
    let accentForeground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background { buttonBackground(isPressed: configuration.isPressed) }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffset)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }

    @ViewBuilder
    private func buttonBackground(isPressed: Bool) -> some View {
        let radius = visualStyle.resolvedCornerRadius(fallback: 18)

        switch visualStyle.primaryAction {
        case .automatic:
            RoundedRectangle(cornerRadius: radius)
                .fill(Color.white)
        case .monochrome:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(isPressed ? 0.84 : 1))
        case .system, .filled:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(theme.primary.opacity(isPressed ? 0.82 : 1))
        case .gradient:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.primary, theme.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(isPressed ? 0.84 : 1)
        }
    }

    private var foregroundColor: Color {
        switch visualStyle.primaryAction {
        case .automatic, .monochrome:
            .black
        case .system, .filled, .gradient:
            accentForeground
        }
    }

    private var shadowColor: Color {
        switch visualStyle.elevation {
        case .none:
            .clear
        case .subtle:
            .black.opacity(0.07)
        case .automatic, .floating:
            .black.opacity(0.14)
        }
    }

    private var shadowRadius: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: 7
        case .automatic, .floating: 14
        }
    }

    private var shadowOffset: CGFloat {
        switch visualStyle.elevation {
        case .none: 0
        case .subtle: 3
        case .automatic, .floating: 7
        }
    }
}
#endif
