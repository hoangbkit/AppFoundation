# Promo Video Studio on macOS

Promo Video Studio supports macOS 15 and later through the standalone `AppFoundationPromoVideoStudio` product.

```swift
import AppFoundationPromoVideoStudio
```

The macOS implementation matches the iOS Studio workflow while using native desktop presentation:

- three-column video, preview, and inspector workspace
- multi-video switching
- registered-scene selection and thumbnails
- deterministic timeline playback and scrubbing
- Scene and Video control scopes with host-provided SwiftUI sections
- output preset, frame-rate, motion, and safe-area controls
- full-window preview
- exact frame-by-frame H.264 MP4 export through `AVAssetWriter`
- native save panel and Finder reveal
- the same seven reusable story templates available on iOS

The host app continues to own scene content, fixture data, copy, branding, backgrounds, and campaign controls. AppFoundation owns timing, responsive template layout, preview, and export.

## Present the Studio

```swift
PromoVideoStudio(project: project) { context in
    Section("Scene Controls") {
        Text(context.selectedSceneTitle)
    }
} videoConfigurationControls: { context in
    Section("Campaign") {
        Text(context.preset.title)
    }
}
```

## Demo target

The repository includes a separate `DemoMac` XcodeGen target. It links only `AppFoundationScreenshotStudio` and `AppFoundationPromoVideoStudio`, so the Mac demo exposes only features that are supported on macOS.
