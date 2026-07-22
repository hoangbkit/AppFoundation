# Screenshot Studio

## Goal

Give every app a native developer-only workspace for designing and exporting App Store screenshots without moving app-specific visual design into AppFoundation.

The package owns the engine and control surface. Each app owns the screenshot compositions, fixture data, copy, themes, and optional controls.

> The engine renders and exports. The app composes and registers.

## Package boundary

AppFoundation provides:

- exact pixel and point-size device presets
- a screenshot registration model and result builder
- live preview at the selected device aspect ratio
- appearance and locale overrides
- app-defined control injection
- deterministic opaque PNG rendering with `ImageRenderer`
- selected and batch export through the system share sheet
- stable filenames and output validation

The host app provides:

- every screenshot SwiftUI view
- promotional layout and copy
- screenshots of app screens, widgets, cards, and device frames
- deterministic fixtures and sample data
- app theme and state controls
- registration order and filenames
- the decision to expose the studio only in Debug or an internal build

AppFoundation must not ship a portfolio-wide screenshot visual style. Reusing the engine is encouraged; making every app's screenshots look identical is not.

## Registration API

An app creates a catalog and registers app-owned views:

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

The app then presents the shared studio and injects any app-specific controls:

```swift
#if DEBUG
ScreenshotStudio(
    catalog: MiLoveScreenshotCatalog.make(settings: settings)
) {
    MiLoveScreenshotControls(settings: settings)
}
#endif
```

A dedicated internal build may use a custom compilation condition instead of `DEBUG`:

```swift
#if DEBUG || SCREENSHOT_STUDIO
ScreenshotStudio(...)
#endif
```

The package APIs remain available in all builds so the host app controls release safety and can create an internal Release-quality screenshot configuration.

## Rendering contract

Each registered screenshot is rendered at the preset's point size and output scale. For example, the built-in 6.9-inch iPhone preset uses a 440 × 956 point canvas at 3× to create a 1320 × 2868 pixel PNG.

The renderer:

1. builds the registered SwiftUI view on the main actor
2. injects the selected locale, color scheme, and display scale
3. clips the view to the exact point canvas
4. renders with `ImageRenderer`
5. forces opaque output because App Store screenshots cannot contain alpha
6. verifies the produced `CGImage` dimensions
7. writes an atomic PNG into a temporary batch folder
8. shares one or multiple output files using the system share sheet

The built-in sizes are convenience presets, not hard-coded policy. Apps can register custom `ScreenshotDevicePreset` values whenever Apple accepts additional dimensions or a non-App-Store export is needed.

Current built-in presets:

- iPhone 6.9-inch: 1320 × 2868 at 3×
- iPhone 6.5-inch: 1242 × 2688 at 3×
- iPad 13-inch: 2064 × 2752 at 2×
- Mac 16:10 helper: 2880 × 1800 at 2×

Apple's current accepted screenshot sizes remain the source of truth:

<https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/>

## Deterministic screenshot rules

Registered screenshot views should not depend directly on:

- the current date or time
- real user data
- random values
- the network
- Photos permission or the Photos library
- live StoreKit products or transactions
- asynchronous image loading
- the current physical device dimensions

Use fixed fixtures and observable screenshot settings instead:

```swift
@Observable
@MainActor
final class MiLoveScreenshotSettings {
    var theme: MiLoveTheme = .paper
    var relationshipFixture: RelationshipFixture = .threeYears
    var avatarSet: AvatarFixture = .storePreview
}
```

This makes screenshot generation reproducible and allows intentional design changes to be reviewed in source control.

## Control view responsibilities

The shared `ScreenshotStudio` control surface includes:

- registered screenshot selection
- live scaled preview
- output preset selection
- exact pixel dimensions and render scale
- light and dark appearance override
- locale selection
- app-defined control section
- export selected screenshot
- export all compatible screenshots
- progress, errors, and system sharing

The shared UI does not understand app themes or app data. The app's injected control view can expose any settings that its screenshot views observe.

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
└── ScreenshotStudioView.swift

Examples/Demo/Demo/
└── ScreenshotStudioDemoView.swift

Tests/AppFoundationTests/
└── ScreenshotStudioTests.swift
```

The package remains one Swift Package target for simple adoption, while the source layout keeps models, rendering, and UI separated.

## Demo

The Demo app includes a dedicated **Screenshots** tab. It proves that:

- the Demo app owns three distinct promotional screenshot designs
- the app registers those views with the package
- app-defined controls update previews and exports
- English and Vietnamese locale overrides work
- 6.9-inch and 6.5-inch output presets work
- selected and batch PNG export use the shared engine

The Demo compositions are examples only and are not reusable screenshot templates for other apps.

## Validation

Portable Swift 6.2 tests cover:

- built-in pixel and point dimensions
- landscape preset conversion
- stable safe export filenames

The repository's existing GitHub Actions workflow runs `swift test` on every push to `develop`. Final iOS rendering and Demo interaction still require Xcode 26 on macOS because SwiftUI and UIKit are unavailable in the Linux workflow.

## Completion status

- [x] Document package/app ownership boundary
- [x] Add extensible device preset model
- [x] Add locale model and filename utilities
- [x] Add screenshot definition registration result builder
- [x] Add catalog defaults and per-screenshot preset support
- [x] Add exact-dimension `ImageRenderer` engine
- [x] Force opaque PNG output and validate pixel dimensions
- [x] Add selected and batch export
- [x] Add reusable developer control interface
- [x] Support app-defined controls
- [x] Add Demo-owned screenshot catalog and compositions
- [x] Add Demo tab
- [x] Add portable tests
