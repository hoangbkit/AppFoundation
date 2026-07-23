#if canImport(SwiftUI)
import SwiftUI

public struct FoundationOnboardingPage: Identifiable {
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
                .buttonStyle(FoundationOnboardingButtonStyle())
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

                Circle()
                    .strokeBorder(resolvedTheme.primary.opacity(0.18))

                Image(systemName: page.systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(resolvedTheme.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 88, height: 88)
            .shadow(color: resolvedTheme.primary.opacity(0.14), radius: 16, y: 8)
            .padding(.bottom, 24)

            Text(page.eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(resolvedTheme.primary)
                .padding(.bottom, 9)

            Text(page.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
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
        fixedTheme == nil ? environmentTheme.primaryForegroundColor : .primary
    }

    private var secondaryForeground: Color {
        fixedTheme == nil ? environmentTheme.secondaryForegroundColor : .secondary
    }

    private var preferredColorScheme: ColorScheme? {
        fixedTheme == nil ? environmentTheme.appearance.preferredColorScheme.colorScheme : nil
    }

    private var animationThemeID: String {
        fixedTheme == nil ? environmentTheme.id : "fixed"
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.14), radius: 14, y: 7)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
#endif
