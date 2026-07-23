#if canImport(SwiftUI)
import SwiftUI

public struct WidgetShowcaseView<Background: View>: View {
    private let catalog: WidgetShowcaseCatalog
    private let guide: WidgetInstallGuideConfiguration
    private let hasPro: Bool
    private let style: WidgetShowcaseStyle
    private let onRequestUpgrade: (() -> Void)?
    private let embedsInNavigationStack: Bool
    private let background: Background

    public init(
        catalog: WidgetShowcaseCatalog,
        guide: WidgetInstallGuideConfiguration,
        hasPro: Bool = true,
        style: WidgetShowcaseStyle = .standard,
        onRequestUpgrade: (() -> Void)? = nil,
        @ViewBuilder background: () -> Background
    ) {
        self.init(
            catalog: catalog,
            guide: guide,
            hasPro: hasPro,
            style: style,
            onRequestUpgrade: onRequestUpgrade,
            embedsInNavigationStack: true,
            background: background
        )
    }

    public init(
        catalog: WidgetShowcaseCatalog,
        guide: WidgetInstallGuideConfiguration,
        hasPro: Bool = true,
        style: WidgetShowcaseStyle = .standard,
        onRequestUpgrade: (() -> Void)? = nil,
        embedsInNavigationStack: Bool,
        @ViewBuilder background: () -> Background
    ) {
        self.catalog = catalog
        self.guide = guide
        self.hasPro = hasPro
        self.style = style
        self.onRequestUpgrade = onRequestUpgrade
        self.embedsInNavigationStack = embedsInNavigationStack
        self.background = background()
    }

    @ViewBuilder
    public var body: some View {
        Group {
            if embedsInNavigationStack {
                NavigationStack {
                    gallery
                }
            } else {
                gallery
            }
        }
        .tint(style.accentColor)
    }

    private var gallery: some View {
        GeometryReader { proxy in
            ZStack {
                styledBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        setupCard

                        ForEach(catalog.families) { family in
                            familySection(
                                family,
                                availableWidth: max(0, Double(proxy.size.width - 36))
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(style.primaryTextColor)
        .navigationTitle(guide.galleryTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var styledBackground: some View {
        ZStack {
            WidgetShowcaseDefaultBackground(style: style)
            background.ignoresSafeArea()
        }
    }

    private var setupCard: some View {
        NavigationLink {
            WidgetInstallGuideView(
                goal: .general,
                configuration: guide,
                style: style,
                background: { styledBackground }
            )
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "hand.tap.fill")
                    .font(.headline)
                    .foregroundStyle(style.accentColor)
                    .frame(width: 44, height: 44)
                    .background(
                        style.accentColor.opacity(0.13),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Add \(guide.appName) to your Home Screen")
                        .font(.headline)
                        .foregroundStyle(style.primaryTextColor)
                    Text("Open the complete setup guide for every widget size.")
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryTextColor)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(style.secondaryTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetShowcaseCard(style: style, padding: 16, cornerRadius: 22)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows instructions for adding a widget")
    }

    private func familySection(
        _ family: WidgetShowcaseFamily,
        availableWidth: Double
    ) -> some View {
        let size = family.previewSize(availableWidth: availableWidth)

        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(family.title)
                    .font(.title3.bold())
                    .foregroundStyle(style.primaryTextColor)

                Spacer()

                Text("\(catalog.items(for: family).count) designs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.secondaryTextColor)
            }

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(catalog.items(for: family)) { item in
                        widgetButton(item, size: size)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func widgetButton(
        _ item: WidgetShowcaseItem,
        size: WidgetShowcaseSize
    ) -> some View {
        Group {
            if item.access == .pro && !hasPro {
                Button {
                    onRequestUpgrade?()
                } label: {
                    widgetLabel(item, size: size)
                }
            } else {
                NavigationLink {
                    WidgetInstallGuideView(
                        goal: WidgetInstallGoal(descriptor: item.descriptor),
                        configuration: guide,
                        style: style,
                        background: { styledBackground }
                    )
                } label: {
                    widgetLabel(item, size: size)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: item))
        .accessibilityHint(
            item.access == .pro && !hasPro
                ? "Requests an upgrade"
                : "Shows widget details and setup instructions"
        )
    }

    private func widgetLabel(
        _ item: WidgetShowcaseItem,
        size: WidgetShowcaseSize
    ) -> some View {
        VStack(spacing: 9) {
            item.preview()
                .frame(width: size.width, height: size.height)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: item.family.cornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: item.family.cornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(style.borderColor)
                }
                .shadow(color: style.shadowColor, radius: 12, y: 7)

            HStack(spacing: 6) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(style.primaryTextColor)
                    .multilineTextAlignment(.center)

                if item.access == .pro && !hasPro {
                    Text("PRO")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(style.accentColor, in: Capsule())
                }
            }
            .frame(width: size.width, alignment: .center)
        }
    }

    private func accessibilityLabel(for item: WidgetShowcaseItem) -> String {
        var parts = [item.title, item.family.title, item.subtitle]
        if item.access == .pro { parts.append("Pro") }
        return parts.joined(separator: ", ")
    }
}

public extension WidgetShowcaseView where Background == Color {
    init(
        catalog: WidgetShowcaseCatalog,
        guide: WidgetInstallGuideConfiguration,
        hasPro: Bool = true,
        style: WidgetShowcaseStyle = .standard,
        onRequestUpgrade: (() -> Void)? = nil
    ) {
        self.init(
            catalog: catalog,
            guide: guide,
            hasPro: hasPro,
            style: style,
            onRequestUpgrade: onRequestUpgrade,
            background: { Color.clear }
        )
    }

    init(
        catalog: WidgetShowcaseCatalog,
        guide: WidgetInstallGuideConfiguration,
        hasPro: Bool = true,
        style: WidgetShowcaseStyle = .standard,
        onRequestUpgrade: (() -> Void)? = nil,
        embedsInNavigationStack: Bool
    ) {
        self.init(
            catalog: catalog,
            guide: guide,
            hasPro: hasPro,
            style: style,
            onRequestUpgrade: onRequestUpgrade,
            embedsInNavigationStack: embedsInNavigationStack,
            background: { Color.clear }
        )
    }
}

private struct WidgetShowcaseDefaultBackground: View {
    let style: WidgetShowcaseStyle

    var body: some View {
        ZStack {
            style.backgroundColor

            LinearGradient(
                colors: [style.gradientStartColor, style.gradientEndColor, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 30)
            .scaleEffect(1.16)

            RadialGradient(
                colors: [style.accentColor.opacity(0.20), .clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private extension View {
    func widgetShowcaseCard(
        style: WidgetShowcaseStyle,
        padding: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        self
            .padding(padding)
            .background(
                style.surfaceColor,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(style.borderColor)
            }
            .shadow(color: style.shadowColor, radius: 18, y: 10)
    }
}
#endif
