#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

public struct LimitReachedComparisonRow: Identifiable, Hashable, Sendable {
    public let id: String
    public var feature: String
    public var freeValue: String
    public var proValue: String

    public init(
        id: String? = nil,
        feature: String,
        freeValue: String,
        proValue: String
    ) {
        self.id = id ?? feature
        self.feature = feature
        self.freeValue = freeValue
        self.proValue = proValue
    }

    public init(_ feature: PurchaseFeature) {
        self.init(
            id: feature.id,
            feature: feature.title,
            freeValue: feature.freeValue,
            proValue: feature.proValue
        )
    }
}

/// App-owned copy for a reusable "limit reached" upsell.
public struct LimitReachedUpsellConfiguration: Sendable {
    public var navigationTitle: String
    public var title: String
    public var message: String
    public var symbolName: String
    public var comparisonTitle: String
    public var comparisonSubtitle: String
    public var featureColumnTitle: String
    public var freeColumnTitle: String
    public var proColumnTitle: String

    /// Optional local override. Leave empty to use `PurchaseManager.features`.
    public var rows: [LimitReachedComparisonRow]

    public var unlockButtonTitle: String
    public var stayFreeButtonTitle: String
    public var comparisonAccessibilityLabel: String
    public var themeOverride: AppTheme?

    public init(
        navigationTitle: String = "Limit Reached",
        title: String,
        message: String,
        symbolName: String = "exclamationmark.circle.fill",
        comparisonTitle: String = "Free or Pro — your choice",
        comparisonSubtitle: String = "Your existing data stays available either way.",
        featureColumnTitle: String = "Feature",
        freeColumnTitle: String = "Free",
        proColumnTitle: String = "Pro",
        rows: [LimitReachedComparisonRow] = [],
        unlockButtonTitle: String = "Unlock Pro",
        stayFreeButtonTitle: String = "Stay Free",
        comparisonAccessibilityLabel: String = "Free and Pro comparison",
        themeOverride: AppTheme? = nil
    ) {
        self.navigationTitle = navigationTitle
        self.title = title
        self.message = message
        self.symbolName = symbolName
        self.comparisonTitle = comparisonTitle
        self.comparisonSubtitle = comparisonSubtitle
        self.featureColumnTitle = featureColumnTitle
        self.freeColumnTitle = freeColumnTitle
        self.proColumnTitle = proColumnTitle
        self.rows = rows
        self.unlockButtonTitle = unlockButtonTitle
        self.stayFreeButtonTitle = stayFreeButtonTitle
        self.comparisonAccessibilityLabel = comparisonAccessibilityLabel
        self.themeOverride = themeOverride
    }
}

/// The reusable first step of a limit-reached flow, adapted from MiLove.
public struct ProUpsellView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFoundationTheme) private var environmentTheme
    @Environment(\.appFoundationVisualStyle) private var visualStyle
    @Environment(PurchaseManager.self) private var purchaseManager

    private let configuration: LimitReachedUpsellConfiguration
    private let onUnlockPro: () -> Void
    private let onStayFree: (() -> Void)?

    public init(
        configuration: LimitReachedUpsellConfiguration,
        onUnlockPro: @escaping () -> Void,
        onStayFree: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self.onUnlockPro = onUnlockPro
        self.onStayFree = onStayFree
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: theme)

                ScrollView {
                    VStack(spacing: 22) {
                        header
                        unlockAction
                        if !resolvedRows.isEmpty { comparisonTable }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                if visualStyle.usesVisibleNavigationChrome {
                    ToolbarItem(placement: .principal) {
                        Text(configuration.navigationTitle)
                            .font(.headline)
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
            .toolbarBackground(visualStyle.toolbarVisibility, for: .navigationBar)
            .tint(theme.accentColor)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(theme.appearance.preferredColorScheme.colorScheme)
    }

    private var header: some View {
        VStack(spacing: 15) {
            ProCrownIcon()

            VStack(spacing: 7) {
                Text(configuration.title)
                    .font(upsellTitleFont)
                    .foregroundStyle(primaryForeground)
                    .multilineTextAlignment(.center)

                Text(configuration.message)
                    .font(.subheadline)
                    .foregroundStyle(secondaryForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var comparisonTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
            GridRow {
                Text(configuration.featureColumnTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(configuration.freeColumnTitle)
                    .frame(minWidth: 58)
                    .gridColumnAlignment(.center)
                Text(configuration.proColumnTitle)
                    .frame(minWidth: 58)
                    .gridColumnAlignment(.center)
            }
            .font(.caption.weight(.black))
            .foregroundStyle(secondaryForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)

            Divider()
                .overlay(headerDividerColor)
                .gridCellColumns(3)

            ForEach(Array(resolvedRows.enumerated()), id: \.element.id) { index, row in
                GridRow {
                    Text(row.feature)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(primaryForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.freeValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryForeground)
                        .multilineTextAlignment(.center)
                    Text(row.proValue)
                        .font(.caption2.bold())
                        .foregroundStyle(theme.accentColor)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)

                if index < resolvedRows.count - 1 {
                    Divider()
                        .overlay(rowDividerColor)
                        .gridCellColumns(3)
                }
            }
        }
        .foundationVisualSurface(
            solidColor: comparisonSurface,
            borderColor: comparisonBorder,
            shadowColor: theme.appearance.shadow.color,
            fallbackCornerRadius: 16,
            fallbackShadowRadius: 0,
            fallbackShadowOffset: 0
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(configuration.comparisonAccessibilityLabel)
    }

    @ViewBuilder
    private var unlockAction: some View {
        if visualStyle.primaryAction == .automatic {
            Button(action: onUnlockPro) {
                Label(configuration.unlockButtonTitle, systemImage: "crown.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LimitUpsellPrimaryButtonStyle(theme: theme))
        } else {
            Button(action: onUnlockPro) {
                Label(configuration.unlockButtonTitle, systemImage: "crown.fill")
            }
            .buttonStyle(FoundationPrimaryButtonStyle(theme: FoundationTheme(theme)))
        }
    }

    private var resolvedRows: [LimitReachedComparisonRow] {
        if !configuration.rows.isEmpty { return configuration.rows }
        return purchaseManager.features.map(LimitReachedComparisonRow.init)
    }

    private var upsellTitleFont: Font {
        if visualStyle.preservesLegacyPresentation {
            return .title2.bold()
        }
        return .system(
            size: 24,
            weight: .bold,
            design: visualStyle.resolvedFontDesign(fallback: .default)
        )
    }

    private var primaryForeground: Color {
        visualStyle.background == .systemGrouped ? .primary : theme.primaryForegroundColor
    }

    private var secondaryForeground: Color {
        visualStyle.background == .systemGrouped ? .secondary : theme.secondaryForegroundColor
    }

    private var comparisonSurface: Color {
        if visualStyle.background == .systemGrouped {
            return systemGroupedSurface
        }
        if visualStyle.preservesLegacyPresentation {
            return theme.elevatedSurfaceColor.opacity(0.62)
        }
        return theme.elevatedSurfaceColor.opacity(0.82)
    }

    private var comparisonBorder: Color {
        if visualStyle.background == .systemGrouped {
            return Color.primary.opacity(0.10)
        }
        if visualStyle.preservesLegacyPresentation {
            return theme.borderColor.opacity(0.45)
        }
        return theme.borderColor.opacity(0.65)
    }

    private var headerDividerColor: Color {
        visualStyle.preservesLegacyPresentation
            ? theme.borderColor.opacity(0.45)
            : comparisonBorder.opacity(0.75)
    }

    private var rowDividerColor: Color {
        visualStyle.preservesLegacyPresentation
            ? theme.borderColor.opacity(0.35)
            : comparisonBorder.opacity(0.58)
    }

    private var systemGroupedSurface: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        theme.elevatedSurfaceColor
        #endif
    }

    private var theme: AppTheme {
        configuration.themeOverride ?? environmentTheme
    }
}

/// A convenience flow that transitions from the limit explanation to an app-owned paywall.
public struct LimitReachedUpsellFlow<Paywall: View>: View {
    private let configuration: LimitReachedUpsellConfiguration
    private let paywall: () -> Paywall

    @State private var showsPaywall = false

    public init(
        configuration: LimitReachedUpsellConfiguration,
        @ViewBuilder paywall: @escaping () -> Paywall
    ) {
        self.configuration = configuration
        self.paywall = paywall
    }

    public var body: some View {
        Group {
            if showsPaywall {
                paywall()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ProUpsellView(configuration: configuration) {
                    withAnimation(.snappy) { showsPaywall = true }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }
}

private struct LimitUpsellPrimaryButtonStyle: ButtonStyle {
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundStyle(buttonForeground)
            .padding(.vertical, 15)
            .background(
                theme.accentColor.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    private var buttonForeground: Color {
        let accent = theme.appearance.accent
        let luminance = 0.2126 * accent.red + 0.7152 * accent.green + 0.0722 * accent.blue
        return luminance > 0.58 ? .black : .white
    }
}

#endif
