#if canImport(SwiftUI)
import SwiftUI

public struct WidgetShowcaseView<Background: View>: View {
    private let catalog: WidgetShowcaseCatalog
    private let guide: WidgetInstallGuideConfiguration
    private let hasPro: Bool
    private let style: WidgetShowcaseStyle
    private let onRequestUpgrade: (() -> Void)?
    private let background: Background

    @State private var path: [WidgetShowcaseRoute] = []

    public init(
        catalog: WidgetShowcaseCatalog,
        guide: WidgetInstallGuideConfiguration,
        hasPro: Bool = true,
        style: WidgetShowcaseStyle = .standard,
        onRequestUpgrade: (() -> Void)? = nil,
        @ViewBuilder background: () -> Background
    ) {
        self.catalog = catalog
        self.guide = guide
        self.hasPro = hasPro
        self.style = style
        self.onRequestUpgrade = onRequestUpgrade
        self.background = background()
    }

    public var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                ZStack {
                    styledBackground

                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            introCard
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
            .navigationDestination(for: WidgetShowcaseRoute.self) { route in
                destination(for: route)
            }
        }
        .tint(style.accentColor)
    }

    private var styledBackground: some View {
        ZStack {
            WidgetShowcaseDefaultBackground(style: style)
            background.ignoresSafeArea()
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WIDGET SHOWCASE")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(style.secondaryTextColor)

                    Text(guide.gallerySubtitle)
                        .font(.title2.bold())
                        .foregroundStyle(style.primaryTextColor)
                }

                Spacer(minLength: 12)

                Image(systemName: "square.grid.2x2.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(style.accentColor)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    metricPill("\(catalog.items.count) designs", systemImage: "sparkles")
                    metricPill("\(catalog.families.count) sizes", systemImage: "rectangle.3.group")
                    if catalog.proItemCount > 0 {
                        metricPill("\(catalog.proItemCount) Pro", systemImage: "crown.fill")
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
        .widgetShowcaseCard(style: style, padding: 20, cornerRadius: 26)
        .accessibilityElement(children: .combine)
    }

    private var setupCard: some View {
        Button {
            path.append(.guide)
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
                Label(family.title, systemImage: family.systemImage)
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
        Button {
            if item.access == .pro && !hasPro {
                onRequestUpgrade?()
            } else {
                path.append(.widget(item.id))
            }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
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
                    .overlay(alignment: .topTrailing) {
                        if item.access == .pro {
                            Label("PRO", systemImage: hasPro ? "checkmark" : "lock.fill")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.56), in: Capsule())
                                .padding(9)
                        }
                    }
                    .shadow(color: style.shadowColor, radius: 12, y: 7)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(style.primaryTextColor)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(style.secondaryTextColor)
                        .lineLimit(2)
                }
                .frame(width: size.width, alignment: .leading)
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

    private func metricPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(style.secondaryTextColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(style.elevatedSurfaceColor, in: Capsule())
            .overlay { Capsule().strokeBorder(style.borderColor) }
    }

    @ViewBuilder
    private func destination(for route: WidgetShowcaseRoute) -> some View {
        switch route {
        case .guide:
            WidgetInstallGuideView(
                goal: .general,
                configuration: guide,
                style: style,
                background: { styledBackground }
            )
        case let .widget(id):
            if let item = catalog.item(id: id) {
                WidgetShowcaseDetailView(
                    item: item,
                    guide: guide,
                    hasPro: hasPro,
                    style: style,
                    onRequestUpgrade: onRequestUpgrade,
                    background: { styledBackground }
                )
            } else {
                ContentUnavailableView("Widget unavailable", systemImage: "square.grid.2x2")
            }
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
            background: { .clear }
        )
    }
}

private enum WidgetShowcaseRoute: Hashable {
    case guide
    case widget(String)
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
