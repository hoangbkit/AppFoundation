# Widget Showcase

`AppFoundationWidgetShowcase` provides the reusable in-app experience around WidgetKit widgets. The host app still owns its widget extension, timeline provider, intents, App Group data, and production widget views.

The package owns:

- A normalized widget catalog grouped by small, medium, and large families.
- Responsive preview sizing and widget-shaped clipping.
- Free and Pro presentation with an app-owned upgrade action.
- A gallery, detail view, and generated Home Screen setup instructions.
- App-owned backgrounds, colors, copy, preview data, and SwiftUI widget views.

## Register previews

```swift
let catalog = WidgetShowcaseCatalog(items: [
    WidgetShowcaseItem(
        id: "summary-small",
        title: "Daily Summary",
        subtitle: "Your key numbers at a glance",
        detail: "A compact summary for the Home Screen.",
        family: .small,
        configurationName: "Daily Summary",
        tags: ["Overview", "Live data"]
    ) {
        DailySummaryWidgetPreview(model: previewModel)
    }
])
```

## Present the gallery

```swift
WidgetShowcaseView(
    catalog: catalog,
    guide: WidgetInstallGuideConfiguration(appName: "My App"),
    hasPro: purchaseManager.hasPro,
    style: WidgetShowcaseStyle(accentColor: theme.accentColor),
    onRequestUpgrade: { showPaywall = true }
) {
    AppBackground(theme: theme)
}
```

The preview closure may reuse the exact SwiftUI view used by the WidgetKit extension, supplied with app-owned sample or live data. AppFoundation does not depend on the host app's model types.
