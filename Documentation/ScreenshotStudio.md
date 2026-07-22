# Screenshot Studio

## Goal

Give every app a native developer-only workspace for designing and exporting App Store screenshots without moving app-specific visual design into AppFoundation.

The package owns the engine, control surface, and optional reusable canvas primitives. Each app owns the compositions, fixture data, copy, colors, themes, and final art direction.

> The engine renders and exports. The app composes and registers.

## Package boundary

AppFoundation provides:

- exact pixel and point-size output presets
- screenshot registration and result-builder APIs
- live preview at the selected device aspect ratio
- appearance and locale overrides
- app-defined control injection
- deterministic opaque PNG rendering with `ImageRenderer`
- selected and batch export through the system share sheet
- stable filenames and pixel validation
- optional device frames, mock chrome, backgrounds, promotional elements, and visual effects

The host app provides:

- every screenshot SwiftUI composition
- app screens, cards, widgets, and deterministic fixtures
- promotional hierarchy and copy
- app-specific typography, colors, and brand identity
- registration order and filenames
- the decision to expose the studio only in Debug or an internal build

AppFoundation must not ship portfolio-wide finished templates. The reusable component layer supplies canvas pieces that remain fully app-configurable.

## Registration API

```swift
@MainActor
enum MiLoveScreenshotCatalog {
    static func make(settings: MiLoveScreenshotSettings) -> ScreenshotCatalog {
        ScreenshotCatalog(
            appName: "MiLove",
            presets: [.iPhone69Portrait, .iPhone65Portrait],
            locales: [
                .english,
                ScreenshotStudioLocale(
                    title: "Tiếng Việt",
                    localeIdentifier: "vi-VN"
                ),
            ]
        ) {
            ScreenshotDefinition(
                id: "hero",
                title: "Relationship Hero",
                filename: "Every day together matters"
            ) {
                MiLoveHeroStoreScreenshot(settings: settings)
            }

            ScreenshotDefinition(
                id: "widgets",
                title: "Widgets",
                filename: "Beautiful relationship widgets"
            ) {
                MiLoveWidgetStoreScreenshot(settings: settings)
            }
        }
    }
}
```

Present the shared studio and inject app-specific controls:

```swift
#if DEBUG
ScreenshotStudio(
    catalog: MiLoveScreenshotCatalog.make(settings: settings)
) {
    MiLoveScreenshotControls(settings: settings)
}
#endif
```

A dedicated internal build can use a custom compilation condition:

```swift
#if DEBUG || SCREENSHOT_STUDIO
ScreenshotStudio(...)
#endif
```

The APIs remain available in all builds so the host can create an internal Release-quality screenshot configuration while keeping the studio out of its App Store build.

## Reusable visual components

The optional component layer includes:

- `ScreenshotDeviceFrame` with frameless, floating, minimal, realistic, and clay styles
- iPhone portrait, iPhone landscape, and iPad portrait device profiles
- `ScreenshotStatusBar`, `ScreenshotNavigationBar`, `ScreenshotToolbarIcon`, `ScreenshotToolbar`, `ScreenshotTabBar`, and `ScreenshotHomeIndicator`
- solid, gradient, aurora, spotlight, paper, technical-grid, rings, and floating-shapes backgrounds
- `ScreenshotHeadline`, badges, metrics, callouts, and page indicators
- reusable shadow, tilt, perspective, glow, glass, and clay modifiers

These components accept app-owned content and colors. They do not decide the final screenshot composition.

See [ScreenshotStudioComponents.md](ScreenshotStudioComponents.md) for the complete API and examples.

## Rendering contract

Each registered screenshot is rendered at the preset's point size and output scale. The built-in 6.9-inch iPhone preset uses a 440 × 956 point canvas at 3× to create a 1320 × 2868 pixel PNG.

The renderer:

1. builds the registered SwiftUI view on the main actor
2. injects the selected locale, color scheme, and display scale
3. clips the view to the exact point canvas
4. renders with `ImageRenderer`
5. forces opaque output
6. verifies the produced `CGImage` dimensions
7. writes an atomic PNG into a temporary batch folder
8. shares one or multiple output files using the system share sheet

Built-in presets:

- iPhone 6.9-inch: 1320 × 2868 at 3×
- iPhone 6.5-inch: 1242 × 2688 at 3×
- iPad 13-inch: 2064 × 2752 at 2×
- Mac 16:10 helper: 2880 × 1800 at 2×

The built-in sizes are convenience presets rather than hard-coded policy. Apps can register custom `ScreenshotDevicePreset` values when additional dimensions are needed.

Apple's accepted screenshot sizes remain the source of truth:

<https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/>

## Deterministic screenshot rules

Registered screenshot views should not depend directly on:

- current dates or time
- real user data
- random values
- network responses
- Photos permission or the Photos library
- live StoreKit products or transactions
- asynchronous image loading
- physical device dimensions

Use fixed fixtures and observable screenshot settings instead:

```swift
@Observable
@MainActor
final class MiLoveScreenshotSettings {
    var theme: MiLoveTheme = .paper
    var relationshipFixture: RelationshipFixture = .threeYears
    var avatarSet: AvatarFixture = .storePreview
    var backgroundStyle: ScreenshotBackgroundStyle = .aurora
    var frameStyle: ScreenshotDeviceFrameStyle = .clay
}
```

This makes exports reproducible and lets intentional design changes be reviewed in source control.

## Control view responsibilities

The shared `ScreenshotStudio` interface includes:

- registered screenshot selection
- live scaled preview
- output preset selection
- exact pixel dimensions and render scale
- light and dark appearance override
- locale selection
- app-defined controls
- selected and batch export
- progress, errors, and system sharing

The shared interface does not understand app themes or app data. The injected app control view can expose any settings observed by its screenshot compositions.

## File naming

Exports use stable sortable names:

```text
01-every-day-together-matters-iphone-6-9-1320x2868.png
02-beautiful-relationship-widgets-iphone-6-9-1320x2868.png
```

`ScreenshotFileName` removes unsafe characters, collapses separators, preserves export order, and includes the selected preset identifier.

## Source layout

```text
Sources/AppFoundation/ScreenshotStudio/
├── ScreenshotStudioModels.swift
├── ScreenshotStudioEngine.swift
├── ScreenshotStudioView.swift
└── Components/
    ├── ScreenshotBackground.swift
    ├── ScreenshotDeviceFrame.swift
    ├── ScreenshotEffects.swift
    ├── ScreenshotPromotionalComponents.swift
    └── ScreenshotSystemChrome.swift

Examples/Demo/Demo/
└── ScreenshotStudioDemoView.swift

Tests/AppFoundationTests/
└── ScreenshotStudioTests.swift
```

The package remains one Swift Package target for simple adoption while the source layout keeps models, rendering, controls, and visual primitives separated.

## Demo

The Demo app includes a dedicated **Screenshots** tab. It proves that:

- the Demo owns four distinct promotional screenshot compositions
- the app registers those views with the package
- app-defined controls update previews and exports
- background and device-frame styles can be changed live
- mock system chrome can be enabled or hidden
- English and Vietnamese locale overrides work
- 6.9-inch and 6.5-inch output presets work
- selected and batch PNG export use the shared engine

The Demo compositions are examples only and are not reusable templates for other apps.

## Validation

Portable Swift 6.2 tests cover built-in dimensions, landscape conversion, and stable filenames. GitHub Actions runs `swift test` on pushes to `develop`.

Final iOS rendering and Demo interaction require Xcode 26 on macOS because SwiftUI and UIKit are unavailable in the Linux workflow.

## Completion status

- [x] Document package/app ownership boundary
- [x] Add extensible output preset and locale models
- [x] Add screenshot registration result builder
- [x] Add exact-dimension `ImageRenderer` engine
- [x] Add opaque PNG validation and batch export
- [x] Add reusable developer control interface
- [x] Support app-defined controls
- [x] Add reusable device and clay frames
- [x] Add mock system chrome and toolbar icons
- [x] Add configurable background visuals
- [x] Add promotional components and effects
- [x] Add Demo-owned component showcase
- [x] Add portable tests
