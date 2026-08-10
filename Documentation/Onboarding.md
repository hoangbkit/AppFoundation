# Onboarding

`FoundationOnboardingView` supports both the original icon-and-copy pages and fully app-owned SwiftUI pages.

## Standard pages

Existing call sites remain unchanged:

```swift
FoundationOnboardingView(
    pages: [
        FoundationOnboardingPage(
            id: "welcome",
            systemImage: "sparkles",
            eyebrow: "Welcome",
            title: "Ready to begin",
            message: "Continue to start using the app."
        )
    ]
) {
    hasCompletedOnboarding = true
}
```

## Custom pages

Pass any identifiable page model and build each page with SwiftUI:

```swift
enum OnboardingPage: String, CaseIterable, Identifiable {
    case scan
    case understand
    case travel

    var id: String { rawValue }
}

FoundationOnboardingView(
    pages: OnboardingPage.allCases,
    configuration: FoundationOnboardingConfiguration(
        completionTitle: "Start Scanning",
        centersPageContent: false,
        contentHorizontalPadding: 0
    )
) { page, context in
    switch page {
    case .scan:
        ScanOnboardingPage(isActive: context.isSelected)
    case .understand:
        TranslationOnboardingPage()
    case .travel:
        TravelOnboardingPage()
    }
} onCompletion: {
    hasCompletedOnboarding = true
}
```

AppFoundation continues to manage selection, paging, the page indicator, skip and continue behavior, theme resolution, and completion. The app owns the page layout and can use screenshots, animations, controls, or any other SwiftUI content.

`FoundationOnboardingPageContext` exposes the page index, page count, selected state, resolved theme, and foreground colors. Use `isSelected` to start or pause page-specific animation.

## Fixed onboarding chrome

The shared navigation chrome is intentionally visually stable across app themes:

- The header pill is always rendered. `headerTitle: nil` is accepted for source compatibility but renders the default `WELCOME` title instead of hiding the pill.
- The primary action button always uses the prominent white style with a black label, including Continue and the final completion action.
- `buttonAppearance` and its `.themed` value remain available for source compatibility, but they no longer alter the rendered action button.
- The page body, background, foreground colors, header tint, and page indicator can still follow the resolved app theme.

## Mixing standard and custom pages

The original layout is available as `FoundationOnboardingStandardPage`, so custom flows can reuse it selectively:

```swift
FoundationOnboardingView(pages: pages) { page, context in
    if page.usesStandardLayout {
        FoundationOnboardingStandardPage(
            page: page.standardPage,
            context: context
        )
    } else {
        AppSpecificOnboardingPage(page: page)
    }
} onCompletion: {
    hasCompletedOnboarding = true
}
```

## Configuration

`FoundationOnboardingConfiguration` controls:

- Header title and symbol; the pill itself is always visible
- Skip, continue, and completion labels
- Page indicator visibility
- Whether page content is vertically centered
- Horizontal and vertical content padding

The primary action button appearance is fixed by AppFoundation so themes cannot reduce its contrast or visual prominence.
