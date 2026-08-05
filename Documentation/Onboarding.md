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
        headerTitle: nil,
        completionTitle: "Start Scanning",
        centersPageContent: false,
        contentHorizontalPadding: 0,
        buttonAppearance: .themed
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

- Header title and symbol
- Skip, continue, and completion labels
- Page indicator visibility
- Whether page content is vertically centered
- Horizontal and vertical content padding
- Legacy light or theme-gradient action button appearance

Defaults preserve the previous onboarding behavior and appearance.
