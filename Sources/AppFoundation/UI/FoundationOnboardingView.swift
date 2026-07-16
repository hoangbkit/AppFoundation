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
    private let pages: [FoundationOnboardingPage]
    private let theme: FoundationTheme
    private let completionTitle: String
    private let onCompletion: @MainActor () -> Void

    @State private var selectedPage = 0

    public init(
        pages: [FoundationOnboardingPage],
        theme: FoundationTheme = .indigo,
        completionTitle: String = "Get Started",
        onCompletion: @escaping @MainActor () -> Void
    ) {
        self.pages = pages.isEmpty
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
        self.theme = theme
        self.completionTitle = completionTitle
        self.onCompletion = onCompletion
    }

    public var body: some View {
        ZStack {
            FoundationBackground(theme: theme)

            VStack(spacing: 24) {
                HStack {
                    FoundationPill("WELCOME", systemImage: "sparkles", tint: theme.primary)
                    Spacer()
                    if selectedPage < pages.count - 1 {
                        Button("Skip") {
                            onCompletion()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
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
                .buttonStyle(FoundationPrimaryButtonStyle(theme: theme))
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
    }

    private func pageView(_ page: FoundationOnboardingPage) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.primary.opacity(0.24), theme.secondary.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 220)
                    .blur(radius: 1)

                Image(systemName: page.systemImage)
                    .font(.system(size: 78, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.primary)
                    .contentTransition(.symbolEffect(.replace))
            }

            FoundationCard(theme: theme) {
                VStack(spacing: 14) {
                    Text(page.eyebrow.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(theme.primary)

                    Text(page.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    Text(page.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 8)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? theme.primary : Color.secondary.opacity(0.22))
                    .frame(width: index == selectedPage ? 28 : 8, height: 8)
                    .animation(.snappy, value: selectedPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(selectedPage + 1) of \(pages.count)")
    }
}
#endif
