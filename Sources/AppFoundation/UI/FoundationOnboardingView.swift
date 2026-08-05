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

public enum FoundationOnboardingButtonAppearance: Sendable {
    /// Preserves the original white onboarding button.
    case legacyLight

    /// Uses the shared theme gradient button style.
    case themed
}

public struct FoundationOnboardingConfiguration {
    public var headerTitle: String?
    public var headerSystemImage: String?
    public var showsSkipButton: Bool
    public var skipTitle: String
    public var continueTitle: String
    public var completionTitle: String
    public var showsPageIndicator: Bool
    public var centersPageContent: Bool
    public var contentHorizontalPadding: CGFloat
    public var contentVerticalPadding: CGFloat
    public var buttonAppearance: FoundationOnboardingButtonAppearance

    public init(
        headerTitle: String? = "WELCOME",
        headerSystemImage: String? = "sparkles",
        showsSkipButton: Bool = true,
        skipTitle: String = "Skip",
        continueTitle: String = "Continue",
        completionTitle: String = "Get Started",
        showsPageIndicator: Bool = true,
        centersPageContent: Bool = true,
        contentHorizontalPadding: CGFloat = 24,
        contentVerticalPadding: CGFloat = 8,
        buttonAppearance: FoundationOnboardingButtonAppearance = .legacyLight
    ) {
        self.headerTitle = headerTitle
        self.headerSystemImage = headerSystemImage
        self.showsSkipButton = showsSkipButton
        self.skipTitle = skipTitle
        self.continueTitle = continueTitle
        self.completionTitle = completionTitle
        self.showsPageIndicator = showsPageIndicator
        self.centersPageContent = centersPageContent
        self.contentHorizontalPadding = max(0, contentHorizontalPadding)
        self.contentVerticalPadding = max(0, contentVerticalPadding)
        self.buttonAppearance = buttonAppearance
    }
}

public struct FoundationOnboardingPageContext {
    public let index: Int
    public let pageCount: Int
    public let isSelected: Bool
    public let theme: FoundationTheme
    public let primaryForeground: Color
    public let secondaryForeground: Color

    public var isFirstPage: Bool { index == 0 }
    public var isLastPage: Bool { index == pageCount - 1 }

    fileprivate init(
        index: Int,
        pageCount: Int,
        isSelected: Bool,
        theme: FoundationTheme,
        primaryForeground: Color,
        secondaryForeground: Color
    ) {
        self.index = index
        self.pageCount = pageCount
        self.isSelected = isSelected
        self.theme = theme
        self.primaryForeground = primaryForeground
        self.secondaryForeground = secondaryForeground
    }
}

/// The original icon-and-copy onboarding page, exposed as a reusable component.
/// Apps can mix this with completely custom pages in the builder initializer.
public struct FoundationOnboardingStandardPage: View {
    private let page: FoundationOnboardingPage
    private let context: FoundationOnboardingPageContext

    public init(
        page: FoundationOnboardingPage,
        context: FoundationOnboardingPageContext
    ) {
        self.page = page
        self.context = context
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                context.theme.primary.opacity(0.20),
                                context.theme.secondary.opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .strokeBorder(context.theme.primary.opacity(0.18))

                Image(systemName: page.systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(context.theme.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 88, height: 88)
            .shadow(color: context.theme.primary.opacity(0.14), radius: 16, y: 8)
            .padding(.bottom, 24)

            Text(page.eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(context.theme.primary)
                .padding(.bottom, 9)

            Text(page.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(context.primaryForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            Text(page.message)
                .font(.body)
                .foregroundStyle(context.secondaryForeground)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
    }
}

public struct FoundationOnboardingView: View {
    @Environment(\.appFoundationTheme) private var environmentTheme

    private struct PageEntry: Identifiable {
        let id: AnyHashable
        let content: (FoundationOnboardingPageContext) -> AnyView
    }

    private let pageEntries: [PageEntry]
    private let fixedTheme: FoundationTheme?
    private let configuration: FoundationOnboardingConfiguration
    private let onCompletion: @MainActor () -> Void

    @State private var selectedPage = 0

    /// Creates the original icon-and-copy onboarding that follows the active
    /// theme installed with `.appFoundationTheme(_:)`.
    public init(
        pages: [FoundationOnboardingPage],
        completionTitle: String = "Get Started",
        onCompletion: @escaping @MainActor () -> Void
    ) {
        var configuration = FoundationOnboardingConfiguration()
        configuration.completionTitle = completionTitle

        self.pageEntries = Self.standardEntries(from: Self.normalizedPages(pages))
        self.fixedTheme = nil
        self.configuration = configuration
        self.onCompletion = onCompletion
    }

    /// Creates the original icon-and-copy onboarding with a fixed legacy
    /// `FoundationTheme` override.
    public init(
        pages: [FoundationOnboardingPage],
        theme: FoundationTheme,
        completionTitle: String = "Get Started",
        onCompletion: @escaping @MainActor () -> Void
    ) {
        var configuration = FoundationOnboardingConfiguration()
        configuration.completionTitle = completionTitle

        self.pageEntries = Self.standardEntries(from: Self.normalizedPages(pages))
        self.fixedTheme = theme
        self.configuration = configuration
        self.onCompletion = onCompletion
    }

    /// Creates onboarding whose page content is completely owned by the app.
    /// AppFoundation still manages paging, navigation chrome, theming, and
    /// completion behavior.
    public init<Page: Identifiable, PageContent: View>(
        pages: [Page],
        configuration: FoundationOnboardingConfiguration = .init(),
        @ViewBuilder pageContent: @escaping (
            Page,
            FoundationOnboardingPageContext
        ) -> PageContent,
        onCompletion: @escaping @MainActor () -> Void
    ) {
        self.pageEntries = Self.customEntries(
            from: pages,
            pageContent: pageContent
        )
        self.fixedTheme = nil
        self.configuration = configuration
        self.onCompletion = onCompletion
    }

    /// Creates custom app-owned onboarding pages with a fixed legacy theme.
    public init<Page: Identifiable, PageContent: View>(
        pages: [Page],
        theme: FoundationTheme,
        configuration: FoundationOnboardingConfiguration = .init(),
        @ViewBuilder pageContent: @escaping (
            Page,
            FoundationOnboardingPageContext
        ) -> PageContent,
        onCompletion: @escaping @MainActor () -> Void
    ) {
        self.pageEntries = Self.customEntries(
            from: pages,
            pageContent: pageContent
        )
        self.fixedTheme = theme
        self.configuration = configuration
        self.onCompletion = onCompletion
    }

    public var body: some View {
        ZStack {
            background

            VStack(spacing: 24) {
                if showsHeader {
                    header
                }

                TabView(selection: $selectedPage) {
                    ForEach(Array(pageEntries.enumerated()), id: \.element.id) { index, entry in
                        pageView(entry, index: index)
                            .tag(index)
                            .padding(.horizontal, configuration.contentHorizontalPadding)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if configuration.showsPageIndicator {
                    pageIndicator
                }

                actionButton
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

    private var showsHeader: Bool {
        configuration.headerTitle != nil
            || (configuration.showsSkipButton && selectedPage < pageEntries.count - 1)
    }

    private var header: some View {
        HStack {
            if let headerTitle = configuration.headerTitle {
                FoundationPill(
                    headerTitle,
                    systemImage: configuration.headerSystemImage,
                    tint: resolvedTheme.primary
                )
            }

            Spacer()

            if configuration.showsSkipButton && selectedPage < pageEntries.count - 1 {
                Button(configuration.skipTitle) {
                    onCompletion()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(secondaryForeground)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func pageView(_ entry: PageEntry, index: Int) -> some View {
        let content = entry.content(pageContext(for: index))

        if configuration.centersPageContent {
            VStack {
                Spacer(minLength: 8)
                content
                Spacer(minLength: 8)
            }
            .padding(.vertical, configuration.contentVerticalPadding)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, configuration.contentVerticalPadding)
        }
    }

    private func pageContext(for index: Int) -> FoundationOnboardingPageContext {
        FoundationOnboardingPageContext(
            index: index,
            pageCount: pageEntries.count,
            isSelected: selectedPage == index,
            theme: resolvedTheme,
            primaryForeground: primaryForeground,
            secondaryForeground: secondaryForeground
        )
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pageEntries.indices, id: \.self) { index in
                Capsule()
                    .fill(
                        index == selectedPage
                            ? resolvedTheme.primary
                            : secondaryForeground.opacity(0.22)
                    )
                    .frame(width: index == selectedPage ? 28 : 8, height: 8)
                    .animation(.snappy, value: selectedPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(selectedPage + 1) of \(pageEntries.count)")
    }

    @ViewBuilder
    private var actionButton: some View {
        switch configuration.buttonAppearance {
        case .legacyLight:
            Button(actionTitle, action: advance)
                .buttonStyle(FoundationOnboardingButtonStyle())

        case .themed:
            Button(actionTitle, action: advance)
                .buttonStyle(FoundationPrimaryButtonStyle(theme: resolvedTheme))
        }
    }

    private var actionTitle: String {
        selectedPage == pageEntries.count - 1
            ? configuration.completionTitle
            : configuration.continueTitle
    }

    private func advance() {
        if selectedPage == pageEntries.count - 1 {
            onCompletion()
        } else {
            withAnimation(.snappy) {
                selectedPage += 1
            }
        }
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

    private static func standardEntries(
        from pages: [FoundationOnboardingPage]
    ) -> [PageEntry] {
        pages.map { page in
            PageEntry(id: AnyHashable(page.id)) { context in
                AnyView(
                    FoundationOnboardingStandardPage(
                        page: page,
                        context: context
                    )
                )
            }
        }
    }

    private static func customEntries<Page: Identifiable, PageContent: View>(
        from pages: [Page],
        @ViewBuilder pageContent: @escaping (
            Page,
            FoundationOnboardingPageContext
        ) -> PageContent
    ) -> [PageEntry] {
        guard !pages.isEmpty else {
            return standardEntries(from: normalizedPages([]))
        }

        return pages.map { page in
            PageEntry(id: AnyHashable(page.id)) { context in
                AnyView(pageContent(page, context))
            }
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
