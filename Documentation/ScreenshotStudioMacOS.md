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

Only the Screenshot Studio product is intended for macOS consumption in this release. Other AppFoundation features remain iOS-focused for now.

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

Present the same shared API used on iOS:

```swift
#if DEBUG
ScreenshotStudio(catalog: OnlinkScreenshotCatalog.make())
#endif
```

On macOS the studio uses a native split-view workspace. Export actions ask for a destination folder, write exact-size opaque PNG files there, and reveal the results in Finder.

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
