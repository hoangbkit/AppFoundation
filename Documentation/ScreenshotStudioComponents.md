# Screenshot Studio Components

Screenshot Studio includes two reusable layers:

1. strongly typed responsive template views that own complete screenshot positioning
2. lower-level visual primitives for custom compositions and template content

The engine renders and exports. Templates own geometry. The host app owns copy, colors, fixtures, brand identity, and the SwiftUI views placed into each slot.

## Template views

Use a concrete template when the screenshot matches a standard composition:

- `HeroScreenshotTemplate`
- `LayeredCardsScreenshotTemplate`
- `SplitFeatureScreenshotTemplate`
- `FloatingCardsScreenshotTemplate`
- `WidgetGalleryScreenshotTemplate`
- `BeforeAfterScreenshotTemplate`
- `FeatureStepsScreenshotTemplate`
- `DeviceFocusScreenshotTemplate`
- `ComparisonGridScreenshotTemplate`
- `ContinuousCampaignScreenshotTemplate`

Each type asks only for the content required by that layout and owns all frames, offsets, overlap, clipping, shadows, safe margins, and output-preset adaptation.

The optional standard slot views are:

- `ScreenshotTemplateBrand`
- `ScreenshotTemplateMessage`
- `ScreenshotTemplateFooter`

Apps may supply any custom SwiftUI view instead.

## Device frames

`ScreenshotDeviceFrame` clips any app-owned SwiftUI content into a reusable device presentation.

```swift
ScreenshotDeviceFrame(
  style: .clay,
  device: .iPhonePortrait,
  frameColor: theme.accent.opacity(0.32),
  rotation: .degrees(-4)
) {
  MiLoveHomeFixtureView()
}
```

Available frame styles:

- `frameless`
- `floating`
- `minimal`
- `realistic`
- `clay`

Available device profiles:

- `iPhonePortrait`
- `iPhoneLandscape`
- `iPadPortrait`

Inside a standard template, the template controls the final frame size. Inside a custom composition, the caller may use normal SwiftUI layout modifiers.

## Mock system chrome

The package provides lightweight promotional chrome for reconstructed fixture views:

- `ScreenshotStatusBar`
- `ScreenshotNavigationBar`
- `ScreenshotToolbarIcon`
- `ScreenshotToolbar`
- `ScreenshotTabBar`
- `ScreenshotHomeIndicator`

These are configurable visual approximations. Apps can use their real navigation and tab bars whenever exact UI fidelity matters.

```swift
VStack(spacing: 0) {
  ScreenshotStatusBar()
  ScreenshotNavigationBar(
    title: "Timeline",
    trailingItems: [
      ScreenshotToolbarItem(
        title: "Add",
        systemImage: "plus",
        isProminent: true
      )
    ],
    tint: theme.accent
  )

  TimelineFixtureView()

  ScreenshotTabBar(
    items: tabs,
    selectedID: "Timeline",
    tint: theme.accent
  )
  ScreenshotHomeIndicator()
}
```

## Background visuals

`ScreenshotBackground` accepts app-owned colors and one reusable visual style:

- `solid`
- `gradient`
- `aurora`
- `spotlight`
- `paper`
- `technicalGrid`
- `rings`
- `floatingShapes`

```swift
ScreenshotBackground(
  style: .aurora,
  colors: MiLoveScreenshotPalette.rose
)
```

A template accepts the background as a separate generic full-canvas view. It fills and clips the background without allowing it to affect foreground layout.

All generated details are deterministic. The backgrounds do not use random values, network assets, or runtime user data.

## Promotional elements

Small reusable pieces reduce repetitive screenshot-only SwiftUI:

- `ScreenshotHeadline`
- `ScreenshotFeatureBadge`
- `ScreenshotIconBadge`
- `ScreenshotMetric`
- `ScreenshotCallout`
- `ScreenshotPageIndicator`

```swift
ScreenshotHeadline(
  eyebrow: "BEAUTIFUL WIDGETS",
  title: "Love, at a glance",
  subtitle: "Choose the style that feels like you.",
  foreground: .white,
  secondaryForeground: .white.opacity(0.72),
  accent: theme.accent
)
```

## Effects

Reusable modifiers provide consistent high-quality rendering:

```swift
content
  .screenshotTilt(.degrees(-4))
  .screenshotPerspective(x: 2, y: -7)
  .screenshotShadow(.soft)
  .screenshotGlow(color: theme.accent)
```

Available helpers:

- `screenshotShadow(_:color:)`
- `screenshotTilt(_:)`
- `screenshotPerspective(x:y:perspective:)`
- `screenshotGlow(color:radius:intensity:)`
- `screenshotGlass(cornerRadius:borderColor:)`
- `screenshotClay(color:cornerRadius:)`

## Design boundary

AppFoundation owns:

- rendering quality
- exact output geometry
- responsive template positioning
- device geometry and reusable chrome
- deterministic backgrounds and effects
- generic promotional components

The host app owns:

- screenshot story and feature claims
- app-specific screens and fixtures
- brand typography and colors
- copy and localization
- selection of template type or a fully custom composition

This keeps every app visually distinct while removing repetitive layout and export work.
