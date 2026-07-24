import AppFoundation
import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var themes

    @State private var isShowingPaywall = false
    @State private var isShowingSettings = false
    @State private var isShowingOnboarding = false
    @State private var isShowingUpsell = false

    private var theme: AppTheme { themes.effectiveTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: theme)

                List {
                    row(top: 8, bottom: 15) {
                        NavigationLink {
                            PackageDocumentationView()
                        } label: {
                            heroCard
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open AppFoundation package documentation")
                    }
                    featuresSection
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .contentMargins(.bottom, 30, for: .scrollContent)
            }
            .foregroundStyle(theme.primaryForegroundColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 7) {
                        if let appIcon {
                            Image(uiImage: appIcon)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 24, height: 24)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 6,
                                        style: .continuous
                                    )
                                )
                        }

                        Text("AF")
                            .font(.headline.weight(.semibold))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("AF")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingPaywall = true
                    } label: {
                        Image(systemName: "crown.fill")
                    }
                    .accessibilityLabel("Open Claude paywall")
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                ClaudePaywallView(
                    purchases: purchases,
                    configuration: DemoConfiguration.legacyClaudePaywall
                )
            }
            .sheet(isPresented: $isShowingUpsell) {
                LimitReachedUpsellFlow(
                    configuration: DemoConfiguration.limitReachedUpsell
                ) {
                    PaywallView(
                        purchaseManager: purchases,
                        configuration: DemoConfiguration.modernPaywall
                    )
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                DemoSettingsView()
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                FoundationOnboardingView(
                    pages: DemoConfiguration.onboardingPages
                ) {
                    isShowingOnboarding = false
                }
            }
        }
        .tint(theme.accentColor)
        .animation(.smooth, value: theme.id)
    }

    private var appIcon: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String]
        else {
            return nil
        }

        return iconFiles.reversed().lazy.compactMap(UIImage.init(named:)).first
    }

    private func row<Content: View>(
        top: CGFloat,
        bottom: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.top, top)
            .padding(.bottom, bottom)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private var heroCard: some View {
        AppThemeCard(theme: theme) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    FoundationPill(
                        "AppFoundation",
                        systemImage: "swift",
                        tint: theme.accentColor
                    )

                    Spacer(minLength: 12)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Build the app.\nSkip the boilerplate.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryForegroundColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Explore production-ready systems from one focused Demo app.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryForegroundColor)
                        .lineSpacing(3)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        platformTag("iOS 26.0+")
                        platformTag("macOS 15.0+")
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func platformTag(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(theme.secondaryForegroundColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.elevatedSurfaceColor, in: Capsule())
            .overlay { Capsule().strokeBorder(theme.borderColor) }
    }

    private var featuresSection: some View {
        Section {
            Text("EXPLORE THE PACKAGE")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(theme.secondaryForegroundColor)
                .padding(.top, 18)
                .padding(.bottom, 10)
                .featureCardRow(theme: theme, position: .top)

            featureRow(.screenshotStudio, showsDivider: true)
            featureRow(.promoStudio, showsDivider: true)
            featureRow(.widgets, showsDivider: true)
            upsellRow
            featureRow(.themes, showsDivider: true)
            featureRow(.infrastructure, showsDivider: true)

            Button {
                isShowingOnboarding = true
            } label: {
                featureLabel(
                    title: "Onboarding",
                    subtitle: "Preview the reusable onboarding flow",
                    systemImage: "rectangle.stack.fill",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 18)
            .featureCardRow(theme: theme, position: .bottom)
        }
    }

    private func featureRow(
        _ feature: DemoFeature,
        showsDivider: Bool
    ) -> some View {
        NavigationLink {
            destination(for: feature)
        } label: {
            featureLabel(
                title: feature.title,
                subtitle: feature.subtitle,
                systemImage: feature.systemImage
            )
        }
        .featureCardRow(
            theme: theme,
            position: .middle,
            showsDivider: showsDivider
        )
    }

    private var upsellRow: some View {
        Button {
            isShowingUpsell = true
        } label: {
            featureLabel(
                title: DemoFeature.upsells.title,
                subtitle: DemoFeature.upsells.subtitle,
                systemImage: DemoFeature.upsells.systemImage,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .featureCardRow(
            theme: theme,
            position: .middle,
            showsDivider: true
        )
    }

    private func featureLabel(
        title: String,
        subtitle: String,
        systemImage: String,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.accentColor)
                .frame(width: 42, height: 42)
                .background(
                    theme.elevatedSurfaceColor,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryForegroundColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.secondaryForegroundColor.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func destination(for feature: DemoFeature) -> some View {
        switch feature {
        case .screenshotStudio:
            ScreenshotStudioDemoView()
        case .promoStudio:
            PromoVideoStudioDemoView()
        case .widgets:
            WidgetShowcaseDemoView()
        case .upsells:
            PurchaseUpsellDemoView()
        case .themes:
            ThemeDemoView()
        case .infrastructure:
            InfrastructureDemoView()
        }
    }
}

private enum DemoFeature: Hashable {
    case screenshotStudio
    case promoStudio
    case widgets
    case upsells
    case themes
    case infrastructure

    var title: String {
        switch self {
        case .screenshotStudio: "Screenshot Studio"
        case .promoStudio: "Promo Video Studio"
        case .widgets: "Widgets"
        case .upsells: "Upsell"
        case .themes: "Themes"
        case .infrastructure: "New APIs"
        }
    }

    var subtitle: String {
        switch self {
        case .screenshotStudio: "Compose, preview, and export App Store screenshots"
        case .promoStudio: "Build responsive animated promo videos in SwiftUI"
        case .widgets: "Browse reusable widget designs and install guidance"
        case .upsells: "Preview the reusable limit-reached upgrade flow"
        case .themes: "Persistent selection and timed Pro previews"
        case .infrastructure: "Export, backup, snapshots, notifications, and utilities"
        }
    }

    var systemImage: String {
        switch self {
        case .screenshotStudio: "photo.stack.fill"
        case .promoStudio: "film.stack.fill"
        case .widgets: "square.grid.2x2.fill"
        case .upsells: "crown.fill"
        case .themes: "paintpalette.fill"
        case .infrastructure: "shippingbox.fill"
        }
    }
}

private enum FeatureCardRowPosition {
    case top
    case middle
    case bottom
}

private struct FeatureCardRowBackground: View {
    let theme: AppTheme
    let position: FeatureCardRowPosition

    private var cornerRadius: CGFloat {
        CGFloat(theme.appearance.cardCornerRadius)
    }

    var body: some View {
        featureShape
            .foregroundStyle(theme.surfaceColor)
            .overlay {
                FeatureCardRowBorder(
                    position: position,
                    cornerRadius: cornerRadius
                )
                .stroke(theme.borderColor, lineWidth: 1)
            }
            .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var featureShape: some View {
        switch position {
        case .top:
            UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius,
                topTrailingRadius: cornerRadius
            )
        case .middle:
            Rectangle()
        case .bottom:
            UnevenRoundedRectangle(
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: cornerRadius
            )
        }
    }
}

private struct FeatureCardRowBorder: Shape {
    let position: FeatureCardRowPosition
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(cornerRadius, rect.width / 2, rect.height)

        switch position {
        case .top:
            path.move(to: CGPoint(x: 0, y: rect.maxY))
            path.addLine(to: CGPoint(x: 0, y: radius))
            path.addArc(
                center: CGPoint(x: radius, y: radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: 0))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: radius),
                radius: radius,
                startAngle: .degrees(270),
                endAngle: .degrees(360),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        case .middle:
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: 0, y: rect.maxY))
            path.move(to: CGPoint(x: rect.maxX, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        case .bottom:
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: 0, y: rect.maxY - radius))
            path.addArc(
                center: CGPoint(x: radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(90),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(0),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        }
        return path
    }
}

private extension View {
    func featureCardRow(
        theme: AppTheme,
        position: FeatureCardRowPosition,
        showsDivider: Bool = false
    ) -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 38, bottom: 0, trailing: 38))
            .listRowSeparator(.hidden)
            .listRowBackground(
                FeatureCardRowBackground(theme: theme, position: position)
            )
            .overlay(alignment: .bottom) {
                if showsDivider {
                    Divider()
                        .overlay(theme.borderColor)
                        .padding(.leading, 56)
                }
            }
    }
}
