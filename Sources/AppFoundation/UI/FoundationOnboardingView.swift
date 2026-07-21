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
                .buttonStyle(FoundationPrimaryButtonStyle(theme: resolvedTheme))
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
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [resolvedTheme.primary.opacity(0.24), resolvedTheme.secondary.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 220)
                    .blur(radius: 1)

                Image(systemName: page.systemImage)
                    .font(.system(size: 78, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(resolvedTheme.primary)
                    .contentTransition(.symbolEffect(.replace))
            }

            pageCard(page)

            Spacer(minLength: 8)
        }
    }

    @ViewBuilder
    private func pageCard(_ page: FoundationOnboardingPage) -> some View {
        if fixedTheme == nil {
            AppThemeCard(theme: environmentTheme) {
                pageCardContent(page)
            }
        } else {
            FoundationCard(theme: resolvedTheme) {
                pageCardContent(page)
            }
        }
    }

    private func pageCardContent(_ page: FoundationOnboardingPage) -> some View {
        VStack(spacing: 14) {
            Text(page.eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(resolvedTheme.primary)

            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryForeground)

            Text(page.message)
                .font(.body)
                .foregroundStyle(secondaryForeground)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
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
#endif