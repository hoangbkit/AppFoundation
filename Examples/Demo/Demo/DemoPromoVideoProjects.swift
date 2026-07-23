import AppFoundation
import SwiftUI

@MainActor
enum DemoPromoVideoProject {
    static func makeAll(settings: DemoPromoVideoSettings) -> [PromoVideoProject] {
        [
            foundationStory(settings: settings),
            widgetStory(settings: settings),
            screenshotStory(settings: settings),
        ]
    }

    private static func foundationStory(settings: DemoPromoVideoSettings) -> PromoVideoProject {
        PromoVideoProject(
            name: "Promo Video Studio",
            presets: [.verticalFullHD, .socialPortrait, .square],
            defaultPresetID: PromoVideoOutputPreset.verticalFullHD.id,
            defaultFrameRate: .fps30,
            defaultMotionIntensity: .balanced
        ) {
            PromoVideoSceneDefinition(
                id: "hero-intro",
                title: "Hero Intro",
                duration: 2.8,
                transition: .crossfade
            ) { context in
                HeroIntroPromoVideoScene(context: context) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("AppFoundation", systemImage: "swift", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "PROMO VIDEO STUDIO",
                        title: "Turn real SwiftUI\ninto a beautiful story.",
                        subtitle: "Register the scenes. AppFoundation owns the motion and export.",
                        accent: settings.mood.accent
                    )
                } visual: {
                    TemplateDashboardFixture(
                        accent: settings.mood.accent,
                        showsDetails: settings.showDetails
                    )
                }
            }

            PromoVideoSceneDefinition(
                id: "device-reveal",
                title: "Device Reveal",
                duration: 2.6,
                transition: .slide
            ) { context in
                DeviceRevealPromoVideoScene(context: context) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("AppFoundation", systemImage: "swift", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "REAL APP VIEWS",
                        title: "Let the interface\ndo the selling.",
                        subtitle: "The preview and final MP4 use the same deterministic scene.",
                        accent: settings.mood.accent
                    )
                } device: {
                    TemplatePhoneScreenFixture(
                        accent: settings.mood.accent,
                        showsDetails: settings.showDetails
                    )
                } footer: {
                    Label("Exact SwiftUI rendering", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            PromoVideoSceneDefinition(
                id: "feature-focus",
                title: "Feature Focus",
                duration: 2.7,
                transition: .zoom
            ) { context in
                FeatureFocusPromoVideoScene(context: context) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("AppFoundation", systemImage: "swift", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "EDITOR WORKFLOW",
                        title: "Scene controls\nand video controls.",
                        subtitle: "The AppReel editor flow, adapted for registered developer scenes.",
                        accent: settings.mood.accent
                    )
                } visual: {
                    TemplateEditorFixture(
                        accent: settings.mood.accent,
                        showsDetails: settings.showDetails
                    )
                } callout: {
                    TemplateMetricFixture(
                        value: settings.emphasizeExport ? "1080p" : "30 fps",
                        label: settings.emphasizeExport ? "Exact MP4 export" : "Smooth preview",
                        systemImage: settings.emphasizeExport ? "square.and.arrow.up.fill" : "play.fill",
                        accent: settings.mood.accent
                    )
                    .frame(width: 190, height: 86)
                }
            }

            PromoVideoSceneDefinition(
                id: "layered-screens",
                title: "Layered Screens",
                duration: 2.8,
                transition: .crossfade
            ) { context in
                LayeredScreensPromoVideoScene(context: context) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("AppFoundation", systemImage: "swift", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "TEMPLATE MOTION",
                        title: "Depth, timing,\nand hierarchy included.",
                        subtitle: "Apps provide content without manually positioning every frame.",
                        accent: settings.mood.accent
                    )
                } primary: {
                    promoFeatureCard(
                        "Studio",
                        value: "Scene + Video",
                        systemImage: "slider.horizontal.3",
                        settings: settings
                    )
                } secondary: {
                    promoFeatureCard(
                        "Templates",
                        value: "6 included",
                        systemImage: "rectangle.3.group.fill",
                        settings: settings
                    )
                } tertiary: {
                    promoFeatureCard(
                        "Export",
                        value: "Silent MP4",
                        systemImage: "film.stack.fill",
                        settings: settings
                    )
                }
            }

            PromoVideoSceneDefinition(
                id: "app-flow",
                title: "App Flow",
                duration: 3.3,
                transition: .slide
            ) { context in
                AppFlowPromoVideoScene(
                    context: context,
                    stepTitles: ["Register", "Preview", "Export"],
                    accent: settings.mood.accent
                ) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("AppFoundation", systemImage: "swift", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "GUIDED STORY",
                        title: "Show the correct flow\nscene by scene.",
                        subtitle: "A focused sequence communicates the app faster than random motion.",
                        accent: settings.mood.accent
                    )
                } first: {
                    promoFlowCard(
                        title: "Register views",
                        subtitle: "Use deterministic fixtures",
                        systemImage: "plus.rectangle.on.rectangle",
                        settings: settings
                    )
                } second: {
                    promoFlowCard(
                        title: "Preview motion",
                        subtitle: "Scrub the exact timeline",
                        systemImage: "play.rectangle.fill",
                        settings: settings
                    )
                } third: {
                    promoFlowCard(
                        title: "Export MP4",
                        subtitle: "Render every frame precisely",
                        systemImage: "square.and.arrow.up.fill",
                        settings: settings
                    )
                }
            }

            outroScene(
                id: "outro",
                appName: "AppFoundation",
                systemImage: "swift",
                title: "Build the app.\nShow it beautifully.",
                subtitle: "Promo Video Studio is now part of AppFoundation.",
                settings: settings
            )
        }
    }

    private static func widgetStory(settings: DemoPromoVideoSettings) -> PromoVideoProject {
        PromoVideoProject(
            name: "Widget Showcase",
            presets: [.verticalFullHD, .square],
            defaultPresetID: PromoVideoOutputPreset.verticalFullHD.id,
            defaultFrameRate: .fps30,
            defaultMotionIntensity: .cinematic
        ) {
            PromoVideoSceneDefinition(
                id: "widgets-hero",
                title: "Widget Hero",
                duration: 2.6,
                transition: .crossfade
            ) { context in
                HeroIntroPromoVideoScene(context: context) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("Widget Showcase", systemImage: "square.grid.2x2.fill", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "HOME SCREEN READY",
                        title: "Make every glance\nfeel intentional.",
                        subtitle: "Show small, medium, and large widgets as one focused campaign.",
                        accent: settings.mood.accent
                    )
                } visual: {
                    TemplateDashboardFixture(
                        accent: settings.mood.accent,
                        showsDetails: settings.showDetails
                    )
                }
            }

            PromoVideoSceneDefinition(
                id: "widgets-sizes",
                title: "Widget Sizes",
                duration: 3.0,
                transition: .zoom
            ) { context in
                LayeredScreensPromoVideoScene(context: context) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("Widget Showcase", systemImage: "square.grid.2x2.fill", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "ONE DESIGN SYSTEM",
                        title: "Three sizes.\nOne visual language.",
                        subtitle: "Use the same content hierarchy across the entire widget family.",
                        accent: settings.mood.accent
                    )
                } primary: {
                    promoFeatureCard("Small", value: "Quick glance", systemImage: "square.fill", settings: settings)
                } secondary: {
                    promoFeatureCard("Medium", value: "More context", systemImage: "rectangle.fill", settings: settings)
                } tertiary: {
                    promoFeatureCard("Large", value: "Full story", systemImage: "square.grid.2x2.fill", settings: settings)
                }
            }

            PromoVideoSceneDefinition(
                id: "widgets-install",
                title: "Install Flow",
                duration: 3.1,
                transition: .slide
            ) { context in
                AppFlowPromoVideoScene(
                    context: context,
                    stepTitles: ["Choose", "Add", "Enjoy"],
                    accent: settings.mood.accent
                ) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("Widget Showcase", systemImage: "square.grid.2x2.fill", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "SIMPLE SETUP",
                        title: "From gallery\nto Home Screen.",
                        subtitle: "Tell the install story without leaving the promo timeline.",
                        accent: settings.mood.accent
                    )
                } first: {
                    promoFlowCard(title: "Choose a style", subtitle: "Browse the gallery", systemImage: "rectangle.3.group.fill", settings: settings)
                } second: {
                    promoFlowCard(title: "Add the widget", subtitle: "Use the system picker", systemImage: "plus.app.fill", settings: settings)
                } third: {
                    promoFlowCard(title: "See it daily", subtitle: "Useful at a glance", systemImage: "sparkles", settings: settings)
                }
            }

            outroScene(
                id: "widgets-outro",
                appName: "Widget Showcase",
                systemImage: "square.grid.2x2.fill",
                title: "A better Home Screen\nstarts with one glance.",
                subtitle: "Reusable widgets, presented as a complete story.",
                settings: settings
            )
        }
    }

    private static func screenshotStory(settings: DemoPromoVideoSettings) -> PromoVideoProject {
        PromoVideoProject(
            name: "Screenshot Studio",
            presets: [.socialPortrait, .verticalFullHD, .landscapeFullHD],
            defaultPresetID: PromoVideoOutputPreset.socialPortrait.id,
            defaultFrameRate: .fps60,
            defaultMotionIntensity: .balanced
        ) {
            PromoVideoSceneDefinition(
                id: "screenshots-hero",
                title: "Screenshot Hero",
                duration: 2.7,
                transition: .crossfade
            ) { context in
                HeroIntroPromoVideoScene(context: context) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("Screenshot Studio", systemImage: "photo.stack.fill", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "APP STORE READY",
                        title: "Design screenshots\ninside the app.",
                        subtitle: "Use responsive SwiftUI compositions instead of static mockups.",
                        accent: settings.mood.accent
                    )
                } visual: {
                    TemplateEditorFixture(
                        accent: settings.mood.accent,
                        showsDetails: settings.showDetails
                    )
                }
            }

            PromoVideoSceneDefinition(
                id: "screenshots-device",
                title: "Live Device",
                duration: 2.8,
                transition: .slide
            ) { context in
                DeviceRevealPromoVideoScene(context: context) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("Screenshot Studio", systemImage: "photo.stack.fill", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "RESPONSIVE CONTENT",
                        title: "Keep the app view\ncrisp at every size.",
                        subtitle: "The composition responds to portrait, square, and landscape outputs.",
                        accent: settings.mood.accent
                    )
                } device: {
                    TemplatePhoneScreenFixture(
                        accent: settings.mood.accent,
                        showsDetails: settings.showDetails
                    )
                } footer: {
                    Label("One source, every export", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            PromoVideoSceneDefinition(
                id: "screenshots-export",
                title: "Export Formats",
                duration: 2.9,
                transition: .zoom
            ) { context in
                FeatureFocusPromoVideoScene(context: context) {
                    demoPromoBackground(settings)
                } brand: {
                    demoPromoBrand("Screenshot Studio", systemImage: "photo.stack.fill", settings: settings)
                } message: {
                    demoPromoMessage(
                        eyebrow: "MULTIPLE OUTPUTS",
                        title: "Preview the format.\nExport only that result.",
                        subtitle: "Each campaign remains focused on the currently selected video.",
                        accent: settings.mood.accent
                    )
                } visual: {
                    TemplateDashboardFixture(
                        accent: settings.mood.accent,
                        showsDetails: settings.showDetails
                    )
                } callout: {
                    TemplateMetricFixture(
                        value: "3 sizes",
                        label: "Portrait, vertical, landscape",
                        systemImage: "aspectratio.fill",
                        accent: settings.mood.accent
                    )
                    .frame(width: 210, height: 86)
                }
            }

            outroScene(
                id: "screenshots-outro",
                appName: "Screenshot Studio",
                systemImage: "photo.stack.fill",
                title: "Compose once.\nExport beautifully.",
                subtitle: "A second complete promo video registered in the same studio.",
                settings: settings
            )
        }
    }

    private static func outroScene(
        id: String,
        appName: String,
        systemImage: String,
        title: String,
        subtitle: String,
        settings: DemoPromoVideoSettings
    ) -> PromoVideoSceneDefinition {
        PromoVideoSceneDefinition(
            id: id,
            title: "Outro CTA",
            duration: 2.5,
            transition: .none
        ) { context in
            OutroCallToActionPromoVideoScene(context: context) {
                demoPromoBackground(settings)
            } icon: {
                Image(systemName: systemImage)
                    .resizable()
                    .scaledToFit()
                    .padding(32)
                    .foregroundStyle(.white)
                    .background(settings.mood.accent.gradient)
            } message: {
                demoPromoMessage(
                    eyebrow: nil,
                    title: title,
                    subtitle: subtitle,
                    accent: settings.mood.accent,
                    alignment: .center
                )
            } callToAction: {
                PromoVideoTemplateCTA(
                    "Preview the full story",
                    systemImage: "play.fill",
                    tint: settings.mood.accent
                )
            } footer: {
                Text("\(appName) · AppFoundation Demo")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }
}
