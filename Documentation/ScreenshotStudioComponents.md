# Screenshot Studio Components

Screenshot Studio includes optional visual primitives for building App Store screenshots quickly without forcing every app into the same template.

The engine still renders and exports. The host app still owns the composition, copy, colors, fixtures, and brand identity.

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

The caller controls the final frame size with normal SwiftUI layout modifiers. Content is clipped into the device screen rather than resized independently of the frame.

## Mock system chrome

The package provides lightweight promotional chrome for reconstructed fixture views:

- `ScreenshotStatusBar`
- `ScreenshotNavigationBar`
- `ScreenshotToolbarIcon`
- `ScreenshotToolbar`
- `ScreenshotTabBar`
- `ScreenshotHomeIndicator`

These are intentionally configurable visual approximations. Apps can use their real navigation and tab bars whenever exact UI fidelity matters.

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
) {
    MiLoveStoreComposition()
}
```

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

Use these APIs as canvas pieces, not finished templates.

Good package responsibility:

- rendering quality
- device geometry
- reusable chrome
- deterministic visual effects
- generic promotional components

Host app responsibility:

- screenshot story and hierarchy
- app-specific screens and fixtures
- typography choices
- colors and brand identity
- feature claims and marketing copy
- final composition

This keeps every app visually distinct while removing the repetitive work that previously required an external design tool.
