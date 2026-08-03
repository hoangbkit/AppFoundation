# Built-in View Visual Styles

`AppTheme` controls semantic colors. `FoundationVisualStyle` independently controls the presentation language used by AppFoundation's built-in SwiftUI views: backgrounds, surfaces, elevation, primary actions, corner radius, typography treatment, and navigation chrome.

Existing apps remain source- and appearance-compatible because `.signature` is the default.

## Install a style

Apply the style beside the theme manager near the app root:

```swift
RootView()
    .appFoundationTheme(themeManager)
    .appFoundationStyle(.native)
```

Every built-in view below that point inherits the style.

## Adopted built-in views

The portfolio-facing components fully adopt the active visual style:

- `ProPaywallView`
- `ProUpsellView`
- `ProCelebrationView`
- `ProPlanSettingsSection` (the reusable Pro section)
- `ThemePickerView`
- `FoundationOnboardingView`
- `FoundationSettingsView`

The shared `ProCrownIcon`, backgrounds, cards, pills, primary buttons, plan options, comparison tables, settings rows, and navigation chrome also inherit the style. Native mode substitutes system foreground and grouped-surface colors where app theme colors would have insufficient contrast.

## Presets

### Signature

```swift
.appFoundationStyle(.signature)
```

Preserves the previous AppFoundation appearance. Components use their historical gradients, materials, shadows, corners, typography, and toolbar treatment.

### Native

```swift
.appFoundationStyle(.native)
```

Uses grouped system backgrounds, solid restrained surfaces, 12-point corners, visible system navigation chrome, system-like primary actions, simplified Pro artwork, and no floating shadows. This is the recommended default for utility and productivity apps.

### Flat

```swift
.appFoundationStyle(.flat)
```

Uses the active theme's solid background and surfaces, compact 10-point corners, filled actions, simplified Pro artwork, and no elevation. This works well for editors and content-focused apps that should carry stronger app colors without looking glassy.

### Glass

```swift
.appFoundationStyle(.glass)
```

Uses atmospheric backgrounds, material surfaces, subtle elevation, monochrome actions, ornate Pro artwork, rounded typography, and larger corners.

## Custom styles

```swift
let compactEditorial = FoundationVisualStyle(
    background: .solid,
    surface: .plain,
    elevation: .none,
    primaryAction: .filled,
    navigationChrome: .system,
    cornerRadius: 6
)

RootView()
    .appFoundationTheme(themeManager)
    .appFoundationStyle(compactEditorial)
```

A custom style is a value type and can be stored or encoded if the app allows users to choose a presentation mode.

## Demo

Open the Demo app and go to **Settings → Visual Style → Built-in views**. Switching Signature, Native, Flat, or Glass updates the package screens live and persists across launches.

## Widget Showcase

`AppFoundationWidgetShowcase` remains a separate package product. Create its existing style tokens from the same app theme and visual style:

```swift
let showcaseStyle = WidgetShowcaseStyle(
    theme: themeManager.effectiveTheme,
    visualStyle: .native
)

WidgetShowcaseView(
    catalog: catalog,
    guide: guide,
    style: showcaseStyle
)
```

The Widget Showcase style uses concrete colors, so `.material` is represented by translucent theme surfaces rather than a live SwiftUI material.
