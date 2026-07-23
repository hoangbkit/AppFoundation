# Screenshot Studio

## Goal

Give every app a native developer-only workspace for designing, previewing, rendering, and exporting App Store screenshots.

AppFoundation owns the renderer, Studio workflow, responsive template layouts, and reusable screenshot components. The host app owns branding, copy, deterministic fixture data, and the feature views placed into templates.

> The app supplies content. AppFoundation owns positioning and export.

## Package boundary

AppFoundation provides:

- exact pixel and point-size output presets
- screenshot registration and result-builder APIs
- live preview at the selected device aspect ratio
- appearance and locale overrides
- separate selected-screenshot and app-configuration controls
- deterministic opaque PNG rendering with `ImageRenderer`
- selected and batch export through the system share sheet
- a rendered full-set carousel preview
- stable filenames and pixel validation
- responsive strongly typed screenshot template views
- optional device frames, mock chrome, backgrounds, promotional elements, and effects

The host app provides:

- app icon and name
- marketing title, subtitle, and footer copy
- app-owned themes and background views
- deterministic feature views, cards, widgets, and screen fixtures
- registration order and filenames
- the decision to expose the Studio only in Debug or an internal build

AppFoundation templates are opinionated layout systems, not finished app-branded campaigns. Every template accepts normal SwiftUI views and completely owns canvas geometry.

## Studio presentation

Push `ScreenshotStudio` from the app's Settings navigation stack. The Studio does not create a nested `NavigationStack`, always uses an inline navigation title, and hides any host tab bar while open.

```swift
#if DEBUG
NavigationLink("Screenshot Studio") {
  ScreenshotStudio(
    catalog: MyScreenshotCatalog.make(settings: settings)
  ) { context in
    MySelectedScreenshotControls(settings: settings, context: context)
  } appConfigurationControls: { context in
    MyCampaignControls(settings: settings, context: context)
  }
}
#endif
```

The control center uses a segmented switch:

- **Screenshot** selects one registered screenshot and shows controls for that composition.
- **App Config** contains output preset, appearance, locale, and app-wide campaign controls.

The host builders may return normal SwiftUI `Section` views and may change sections dynamically based on `ScreenshotStudioControlContext.selectedScreenshotID`.

The trailing toolbar preview button renders the complete supported set at final dimensions and opens it as a swipeable carousel. Export remains separate.

## Registration

```swift
@MainActor
enum MyScreenshotCatalog {
  static func make(settings: MyScreenshotSettings) -> ScreenshotCatalog {
    ScreenshotCatalog(
      appName: "My App",
      presets: [.iPhone69Portrait, .iPhone65Portrait],
      locales: [.english]
    ) {
      ScreenshotDefinition(
        id: "hero",
        title: "Hero",
        filename: "The best way to focus"
      ) {
        MyHeroScreenshot(settings: settings)
      }
    }
  }
}
```

## Template architecture

Templates are independent strongly typed SwiftUI view types. There is no single template-style enum and no initializer filled with irrelevant optional arguments.

Each template requests only the visual slots its composition needs:

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

Every template owns:

- safe margins
- headline and content regions
- visual sizing and clipping
- overlap, rotation, and depth
- shadows
- footer placement
- adaptation between output presets

The host app does not provide raw offsets, rotations, canvas padding, or `GeometryReader` positioning when using a standard template.

## Four common content components

Most templates are composed from four app-supplied layers plus a background:

1. Brand
2. Message
3. One or more template-specific visuals
4. Footer

The package includes optional standard content views:

- `ScreenshotTemplateBrand`
- `ScreenshotTemplateMessage`
- `ScreenshotTemplateFooter`

Apps may replace any of them with custom SwiftUI views.

```swift
HeroScreenshotTemplate {
  MyStoreBackground()
} brand: {
  ScreenshotTemplateBrand(appName: "My App") {
    Image("AppIcon").resizable()
  }
} message: {
  ScreenshotTemplateMessage(
    title: "Focus on what matters.",
    subtitle: "A calm workspace for your daily priorities.",
    foreground: .white,
    secondaryForeground: .white.opacity(0.72)
  )
} visual: {
  MyDashboardFixture()
} footer: {
  ScreenshotTemplateFooter(
    "Today",
    systemImage: "checkmark.circle.fill",
    tint: .mint,
    foreground: .white
  )
}
```

## Background control

Background is a generic full-canvas SwiftUI layer independent from template positioning. Apps may provide:

- a custom app-owned background view
- `ScreenshotBackground`
- a solid color
- a gradient
- an image or deterministic pattern

The template fills and clips the background to the exact screenshot canvas. Background content never participates in foreground layout measurement.

```swift
LayeredCardsScreenshotTemplate {
  ScreenshotBackground(
    style: .technicalGrid,
    colors: [.black, .indigo, .cyan]
  )
} brand: {
  MyBrand()
} message: {
  MyMessage()
} primary: {
  MainCard()
} secondary: {
  SecondaryCard()
} tertiary: {
  ThirdCard()
} footer: {
  MyFooter()
}
```

## Rendering contract

The built-in 6.9-inch iPhone preset uses a 440 × 956 point canvas at 3× to create a 1320 × 2868 pixel PNG.

The renderer:

1. builds the registered SwiftUI view on the main actor
2. injects the selected locale, color scheme, and display scale
3. clips the view to the exact point canvas
4. renders with `ImageRenderer`
5. forces opaque output
6. validates the `CGImage` dimensions
7. writes an atomic PNG into a temporary batch folder
8. previews or shares the resulting files

Built-in presets:

- iPhone 6.9-inch: 1320 × 2868 at 3×
- iPhone 6.5-inch: 1242 × 2688 at 3×
- iPad 13-inch: 2064 × 2752 at 2×
- Mac 16:10 helper: 2880 × 1800 at 2×

Apps may register custom `ScreenshotDevicePreset` values.

## Deterministic screenshot rules

Registered screenshots should not depend directly on:

- current dates or time
- real user data
- random values
- network responses
- Photos or other permissions
- live StoreKit products or transactions
- asynchronous image loading
- physical device dimensions

Use fixed fixtures and observable screenshot settings so exports are reproducible.

## Source layout

```text
Sources/AppFoundation/ScreenshotStudio/
├── ScreenshotStudioModels.swift
├── ScreenshotStudioEngine.swift
├── ScreenshotStudioView.swift
├── Components/
└── Templates/
    ├── ScreenshotTemplateComponents.swift
    ├── HeroScreenshotTemplates.swift
    ├── LayeredScreenshotTemplates.swift
    ├── FeatureScreenshotTemplates.swift
    └── GalleryScreenshotTemplates.swift
```

The Demo pushes Screenshot Studio from Settings and registers template-based example compositions.
