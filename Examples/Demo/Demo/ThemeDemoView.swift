import AppFoundation
import SwiftUI

struct ThemeDemoView: View {
    @Environment(ThemeManager.self) private var themes

    private var theme: AppTheme {
        themes.effectiveTheme
    }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    livePreviewCard
                    themePickerCard
                    themeStateCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accentColor)
        .animation(.smooth, value: theme.id)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    themes.reset()
                }
            }
        }
    }

    private var livePreviewCard: some View {
        AppThemeCard(theme: theme) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("LIVE PREVIEW", systemImage: "paintpalette.fill")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(theme.accentColor)

                    Spacer()

                    Image(systemName: theme.symbolName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.primaryForegroundColor)
                        .frame(width: 42, height: 42)
                        .background(theme.elevatedSurfaceColor, in: RoundedRectangle(cornerRadius: 13))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(theme.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryForegroundColor)

                    Text("The background, surfaces, typography, tint, and preferred color scheme all come from the effective AppTheme.")
                        .font(.body)
                        .foregroundStyle(theme.secondaryForegroundColor)
                        .lineSpacing(3)
                }

                HStack(spacing: 8) {
                    themeChip("Accent", systemImage: "circle.fill")
                    themeChip(theme.appearance.preferredColorScheme.title, systemImage: "circle.lefthalf.filled")
                    themeChip(theme.isPro ? "Pro" : "Free", systemImage: theme.isPro ? "crown.fill" : "checkmark.seal.fill")
                }

                Button("Primary action") {}
                    .buttonStyle(FoundationPrimaryButtonStyle(theme: theme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var themePickerCard: some View {
        AppThemeCard(theme: theme) {
            ThemePickerView(
                manager: themes,
                title: "Choose a theme"
            ) { candidate in
                ThemeDemoThumbnail(theme: candidate)
            }
        }
    }

    private var themeStateCard: some View {
        AppThemeCard(theme: theme) {
            VStack(alignment: .leading, spacing: 16) {
                Text("THEME MANAGER STATE")
                    .font(.caption2.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(theme.secondaryForegroundColor)

                stateRow("Effective theme", value: themes.effectiveTheme.title)
                Divider().overlay(theme.borderColor)
                stateRow("Stored selection", value: themes.selectedTheme.title)
                Divider().overlay(theme.borderColor)
                stateRow("Entitlement", value: themes.hasPro ? "Pro unlocked" : "Free")

                Text(stateExplanation)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .lineSpacing(3)

                if themes.isPreviewActive {
                    Button("End timed preview") {
                        themes.endPreview()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stateRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(theme.secondaryForegroundColor)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(theme.primaryForegroundColor)
        }
        .font(.subheadline)
    }

    private func themeChip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(theme.secondaryForegroundColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(theme.elevatedSurfaceColor, in: Capsule())
    }

    private var stateExplanation: String {
        if themes.hasPro {
            return "Pro access is synchronized from PurchaseController, so every theme can be selected and persisted permanently."
        }
        if themes.isPreviewActive {
            return "This Pro theme is temporarily effective. The built-in timer will automatically return the app to its stored free theme."
        }
        return "Tap a Pro theme to start the built-in timed preview. Unlocking Demo Pro while previewing promotes that theme to the permanent selection."
    }
}

private struct ThemeDemoThumbnail: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            theme.gradient

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: theme.symbolName)
                        .font(.caption.bold())
                    Spacer()
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 9, height: 9)
                }

                Spacer()

                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.primaryForegroundColor.opacity(0.9))
                    .frame(width: 48, height: 5)
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.secondaryForegroundColor.opacity(0.75))
                    .frame(width: 70, height: 4)
            }
            .foregroundStyle(theme.primaryForegroundColor)
            .padding(12)
        }
        .background(theme.backgroundColor)
    }
}

private extension ThemePreferredColorScheme {
    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }
}
