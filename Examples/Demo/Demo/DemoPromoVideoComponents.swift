import AppFoundation
import SwiftUI

@MainActor
struct DemoPromoVideoSceneControls: View {
    @Bindable var settings: DemoPromoVideoSettings
    let context: PromoVideoStudioControlContext

    var body: some View {
        Section("App Scene Controls") {
            switch context.selectedSceneID {
            case "feature-focus":
                Toggle("Emphasize exact export", isOn: $settings.emphasizeExport)
            default:
                Toggle("Show fixture details", isOn: $settings.showDetails)
            }

            LabeledContent(
                "Scene position",
                value: "\(context.selectedSceneIndex + 1) of \(context.sceneCount)"
            )
        }
    }
}

@MainActor
struct DemoPromoVideoConfigurationControls: View {
    @Bindable var settings: DemoPromoVideoSettings

    var body: some View {
        Section("Campaign Style") {
            Picker("Mood", selection: $settings.mood) {
                ForEach(DemoPromoVideoMood.allCases) { mood in
                    Text(mood.title).tag(mood)
                }
            }

            Picker("Background", selection: $settings.backgroundStyle) {
                ForEach(ScreenshotBackgroundStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
        }
    }
}

@MainActor
@ViewBuilder
func demoPromoBackground(_ settings: DemoPromoVideoSettings) -> some View {
    ScreenshotBackground(
        style: settings.backgroundStyle,
        colors: settings.mood.colors
    )
}

@MainActor
func demoPromoBrand(
    _ appName: String,
    systemImage: String,
    settings: DemoPromoVideoSettings
) -> some View {
    PromoVideoTemplateBrand(
        appName: appName,
        foreground: .white
    ) {
        Image(systemName: systemImage)
            .resizable()
            .scaledToFit()
            .padding(6)
            .foregroundStyle(.white)
            .background(settings.mood.accent.gradient)
    }
}

@MainActor
func demoPromoMessage(
    eyebrow: String?,
    title: String,
    subtitle: String,
    accent: Color,
    alignment: TextAlignment = .leading
) -> some View {
    PromoVideoTemplateMessage(
        eyebrow: eyebrow,
        title: title,
        subtitle: subtitle,
        foreground: .white,
        secondaryForeground: .white.opacity(0.72),
        accent: accent,
        alignment: alignment
    )
}

@MainActor
func promoFeatureCard(
    _ title: String,
    value: String,
    systemImage: String,
    settings: DemoPromoVideoSettings
) -> some View {
    TemplateFeatureCardFixture(
        title: title,
        subtitle: settings.showDetails ? "AppFoundation-owned motion" : nil,
        value: value,
        systemImage: systemImage,
        accent: settings.mood.accent
    )
}

@MainActor
func promoFlowCard(
    title: String,
    subtitle: String,
    systemImage: String,
    settings: DemoPromoVideoSettings
) -> some View {
    VStack(spacing: 18) {
        Spacer(minLength: 0)

        Image(systemName: systemImage)
            .font(.system(size: 54, weight: .semibold))
            .foregroundStyle(settings.mood.accent)
            .frame(width: 104, height: 104)
            .background(
                settings.mood.accent.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )

        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            if settings.showDetails {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .multilineTextAlignment(.center)

        Spacer(minLength: 0)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(.white)
    .background(Color(red: 0.045, green: 0.05, blue: 0.082))
}
