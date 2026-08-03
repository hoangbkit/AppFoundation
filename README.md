# AppFoundation

AppFoundation is a shared Swift package for App Store apps, including purchases, themes, settings, onboarding, paywalls, Pro flows, widgets, and reusable presentation tools.

## Built-in visual styles

Install a theme and visual style once near the app root:

```swift
RootView()
    .appFoundationTheme(themeManager)
    .appFoundationStyle(.native)
```

Available presets are `.signature`, `.native`, `.flat`, and `.glass`. The style automatically reaches `ProPaywallView`, `ProUpsellView`, `ProCelebrationView`, `ProPlanSettingsSection`, `ThemePickerView`, `FoundationOnboardingView`, and other shared visual primitives.

See `Documentation/VisualStyles.md` for preset behavior, custom styles, Demo controls, and Widget Showcase integration.
