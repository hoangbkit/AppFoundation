# Screenshot Studio on macOS

Screenshot Studio is available as a standalone cross-platform product inside the AppFoundation package.

## Add the product

For a macOS app, select the `AppFoundationScreenshotStudio` library product and import it directly:

```swift
import AppFoundationScreenshotStudio
```

The main `AppFoundation` product continues to re-export Screenshot Studio for existing iOS apps, so current iOS integrations can keep using:

```swift
import AppFoundation
```

Screenshot Studio and Promo Video Studio are both supported on macOS in this release. Apps that need promo-video creation can also link `AppFoundationPromoVideoStudio` directly.

## Register Mac screenshots

Use the built-in 16:10 preset explicitly when creating a Mac catalog:

```swift
@MainActor
enum OnlinkScreenshotCatalog {
  static func make() -> ScreenshotCatalog {
    ScreenshotCatalog(
      appName: "Onlink",
      presets: [.mac16x10]
    ) {
      ScreenshotDefinition(
        id: "overview",
        title: "Network Overview",
        filename: "Know your connection at a glance"
      ) {
        OnlinkOverviewScreenshot()
      }
    }
  }
}
```

Present the same contextual API used on iOS:

```swift
#if DEBUG
ScreenshotStudio(
  catalog: OnlinkScreenshotCatalog.make()
) { context in
  Section("Screenshot") {
    Text(context.selectedScreenshotTitle)
  }
} appConfigurationControls: { context in
  Section("Campaign") {
    Text(context.preset.title)
  }
}
#endif
```

On macOS the Studio uses a native three-column workspace with registered screenshots, a large live preview, and contextual Screenshot/App Config inspectors. The complete set can be rendered and reviewed inside the Studio before export. Export actions ask for a destination folder, write exact-size opaque PNG files there, and reveal the results in Finder.

## Mac window frame

`ScreenshotMacWindowFrame` provides an optional reusable desktop window treatment:

```swift
ScreenshotMacWindowFrame(
  title: "Onlink",
  style: .floating
) {
  OnlinkMainScreenFixture()
}
```

Available styles are `standard`, `floating`, and `minimal`. The host app still owns the screenshot composition, fixture data, colors, copy, and final art direction.
