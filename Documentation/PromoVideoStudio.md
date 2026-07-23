# Promo Video Studio

Promo Video Studio lets an app register deterministic SwiftUI scenes and export them as a precise silent MP4. It adapts the AppReel editor workflow for developer-owned promotional stories rather than imported consumer media.

## Ownership

AppFoundation owns:

- the AppReel-style preview, scrubber, scene strip, Scene / Video segmented editor, safe-area overlay, and export workflow
- scene timing and overlapping transitions
- deterministic frame evaluation
- H.264 MP4 rendering at exact output dimensions
- reusable animated scene templates

The host app owns:

- scene order and duration
- deterministic fixtures and real SwiftUI views
- marketing copy and branding
- backgrounds and campaign style
- scene-specific and video-wide configuration sections

Promo Video Studio does not import Photos, Files, or screen recordings. Registered scenes are selection-first and cannot be deleted or duplicated from the Studio.

## Basic project

```swift
let project = PromoVideoProject(
  name: "My App Promo",
  presets: [.verticalFullHD, .socialPortrait]
) {
  PromoVideoSceneDefinition(
    id: "intro",
    title: "Intro",
    duration: 2.6,
    transition: .crossfade
  ) { context in
    HeroIntroPromoVideoScene(context: context) {
      CampaignBackground()
    } brand: {
      AppBrand()
    } message: {
      PromoVideoTemplateMessage(
        eyebrow: "NEW",
        title: "Show one clear benefit.",
        subtitle: "Rendered from the real app view."
      )
    } visual: {
      HomeScreenFixture()
    }
  }
}
```

## Studio controls

The app can inject normal SwiftUI `Section` views into both sides of the editor:

```swift
PromoVideoStudio(project: project) { context in
  Section("App Scene Controls") {
    Toggle("Show labels", isOn: $settings.showLabels)
  }
} videoConfigurationControls: { context in
  Section("Campaign Style") {
    Picker("Theme", selection: $settings.theme) {
      // App-owned themes
    }
  }
}
```

The Scene side contains the registered scene strip, selected-scene metadata, playback action, and app-injected scene sections. The Video side contains output format, frame rate, motion intensity, safe-area preview, duration, export controls, and app-injected campaign sections.

## Included templates

- `HeroIntroPromoVideoScene`
- `DeviceRevealPromoVideoScene`
- `FeatureFocusPromoVideoScene`
- `LayeredScreensPromoVideoScene`
- `AppFlowPromoVideoScene`
- `OutroCallToActionPromoVideoScene`
- `ContinuousCanvasPromoVideoScene`

Templates receive `PromoVideoSceneContext`, including local scene progress, global progress, output dimensions, frame rate, and motion intensity. The same context is evaluated by interactive preview and exact export.

## Export

The initial exporter produces:

- H.264 MP4
- 30 or 60 fps
- vertical 9:16, portrait 4:5, square 1:1, or landscape 16:9 output
- silent video only
- deterministic frame-by-frame SwiftUI rendering

Audio, narration, and imported media remain outside the initial package scope.
