#if canImport(SwiftUI) && canImport(StoreKit)
import SwiftUI

public struct LimitReachedComparisonRow: Identifiable, Hashable {
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
}

/// App-owned copy and limits for a reusable "limit reached" upsell.
public struct LimitReachedUpsellConfiguration {
    public var navigationTitle: String
    public var title: String
    public var message: String
    public var symbolName: String
    public var comparisonTitle: String
    public var comparisonSubtitle: String
    public var featureColumnTitle: String
    public var freeColumnTitle: String
    public var proColumnTitle: String
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
        rows: [LimitReachedComparisonRow],
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
public struct LimitReachedUpsellView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFoundationTheme) private var environmentTheme

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
                        comparisonCard
                        actions
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(configuration.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(theme.accentColor)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(theme.appearance.preferredColorScheme.colorScheme)
    }

    private var header: some View {
        VStack(spacing: 15) {
            Image(systemName: configuration.symbolName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.accentColor)
                .frame(width: 78, height: 78)
                .background(theme.elevatedSurfaceColor, in: Circle())
                .overlay {
                    Circle().strokeBorder(theme.borderColor)
                }

            VStack(spacing: 7) {
                Text(configuration.title)
                    .font(.title2.bold())
                    .foregroundStyle(theme.primaryForegroundColor)
                    .multilineTextAlignment(.center)

                Text(configuration.message)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var comparisonCard: some View {
        AppThemeCard(theme: theme) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(configuration.comparisonTitle)
                        .font(.headline.bold())
                        .foregroundStyle(theme.primaryForegroundColor)
                    Text(configuration.comparisonSubtitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryForegroundColor)
                }

                comparisonTable
            }
        }
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
            .foregroundStyle(theme.secondaryForegroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)

            Divider()
                .overlay(theme.borderColor)
                .gridCellColumns(3)

            ForEach(Array(configuration.rows.enumerated()), id: \.element.id) { index, row in
                GridRow {
                    Text(row.feature)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.primaryForegroundColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.freeValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.secondaryForegroundColor)
                        .multilineTextAlignment(.center)
                    Text(row.proValue)
                        .font(.caption2.bold())
                        .foregroundStyle(theme.accentColor)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)

                if index < configuration.rows.count - 1 {
                    Divider()
                        .overlay(theme.borderColor.opacity(0.7))
                        .gridCellColumns(3)
                }
            }
        }
        .background(
            theme.elevatedSurfaceColor,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.borderColor)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(configuration.comparisonAccessibilityLabel)
    }

    private var actions: some View {
        VStack(spacing: 11) {
            Button(action: onUnlockPro) {
                Label(configuration.unlockButtonTitle, systemImage: "crown.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LimitUpsellPrimaryButtonStyle(theme: theme))

            Button(configuration.stayFreeButtonTitle) {
                onStayFree?()
                dismiss()
            }
            .buttonStyle(LimitUpsellSecondaryButtonStyle(theme: theme))
        }
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
                LimitReachedUpsellView(configuration: configuration) {
                    withAnimation(.snappy) {
                        showsPaywall = true
                    }
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
            .foregroundStyle(theme.accentForegroundColor)
            .padding(.vertical, 15)
            .background(
                theme.accentColor.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct LimitUpsellSecondaryButtonStyle: ButtonStyle {
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(theme.primaryForegroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                theme.elevatedSurfaceColor.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.borderColor)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
#endif
