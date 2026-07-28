import Foundation

public struct FoundationProComparisonRow: Identifiable, Hashable, Sendable {
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

/// App-owned copy for a reusable Pro celebration screen.
public struct FoundationProCelebrationConfiguration: Sendable {
    public var navigationTitle: String
    public var doneButtonTitle: String
    public var symbolName: String

    /// Optional local override. Leave empty to show the active plan, such as `Lifetime Pro`.
    public var title: String
    public var message: String
    public var statusSymbolName: String

    /// Optional local override. Leave empty to show the active purchased product.
    public var planTitle: String

    /// Optional local override. Leave empty to derive entitlement status from the manager.
    public var statusMessage: String

    public var featureColumnTitle: String
    public var freeColumnTitle: String
    public var proColumnTitle: String

    /// Optional local override. Leave empty to use `PurchaseManager.features`.
    public var rows: [FoundationProComparisonRow]

    public var comparisonAccessibilityLabel: String
    public var themeOverride: AppTheme?

    public init(
        navigationTitle: String = "Pro",
        doneButtonTitle: String = "Done",
        symbolName: String = "diamond.fill",
        title: String = "",
        message: String = "Thanks for supporting \(AppMetadata.current().name) and unlocking the complete Pro experience",
        statusSymbolName: String = "checkmark.seal.fill",
        planTitle: String = "",
        statusMessage: String = "",
        featureColumnTitle: String = "Feature",
        freeColumnTitle: String = "Free",
        proColumnTitle: String = "Pro",
        rows: [FoundationProComparisonRow] = [],
        comparisonAccessibilityLabel: String = "Free and Pro comparison",
        themeOverride: AppTheme? = nil
    ) {
        self.navigationTitle = navigationTitle
        self.doneButtonTitle = doneButtonTitle
        self.symbolName = symbolName
        self.title = title
        self.message = message
        self.statusSymbolName = statusSymbolName
        self.planTitle = planTitle
        self.statusMessage = statusMessage
        self.featureColumnTitle = featureColumnTitle
        self.freeColumnTitle = freeColumnTitle
        self.proColumnTitle = proColumnTitle
        self.rows = rows
        self.comparisonAccessibilityLabel = comparisonAccessibilityLabel
        self.themeOverride = themeOverride
    }
}

#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

/// A theme-aware Pro entitlement celebration screen adapted from MiLove.
public struct ProCelebrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFoundationTheme) private var environmentTheme
    @Environment(\.requestReview) private var requestReview
    @Environment(PurchaseManager.self) private var purchaseManager

    private let configuration: FoundationProCelebrationConfiguration

    public init(configuration: FoundationProCelebrationConfiguration) {
        self.configuration = configuration
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: theme)

                ScrollView {
                    VStack(spacing: 20) {
                        celebrationHeader
                        reviewCard
                        if !resolvedRows.isEmpty { comparisonTable }
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(configuration.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(configuration.doneButtonTitle) { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(theme.accentColor)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(theme.appearance.preferredColorScheme.colorScheme)
    }

    private var celebrationHeader: some View {
        VStack(spacing: 13) {
            ProCrownIcon()

            VStack(spacing: 6) {
                Text(resolvedTitle)
                    .font(.largeTitle.bold())
                    .foregroundStyle(theme.primaryForegroundColor)
                    .multilineTextAlignment(.center)

                Text(configuration.message)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
    }

    private var reviewCard: some View {
        Button {
            requestReview()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: configuration.statusSymbolName)
                    .font(.system(size: 21, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 46, height: 46)
                    .background(theme.accentColor.opacity(0.13), in: Circle())
                    .overlay { Circle().strokeBorder(theme.borderColor) }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Enjoying \(appName)?")
                        .font(.headline.bold())
                        .foregroundStyle(theme.primaryForegroundColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(theme.accentColor)
                        .accessibilityHidden(true)

                        Text("Leave a review")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryForegroundColor)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                celebrationCardBackground,
                in: RoundedRectangle(cornerRadius: celebrationCardCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: celebrationCardCornerRadius, style: .continuous)
                    .strokeBorder(celebrationCardBorder)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Leave a review for \(appName)")
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
                .overlay(theme.borderColor.opacity(0.45))
                .gridCellColumns(3)

            ForEach(Array(resolvedRows.enumerated()), id: \.element.id) { index, row in
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
                .background(Color.clear)

                if index < resolvedRows.count - 1 {
                    Divider()
                        .overlay(theme.borderColor.opacity(0.35))
                        .gridCellColumns(3)
                }
            }
        }
        .background(
            celebrationCardBackground,
            in: RoundedRectangle(cornerRadius: celebrationCardCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: celebrationCardCornerRadius, style: .continuous)
                .strokeBorder(celebrationCardBorder)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(configuration.comparisonAccessibilityLabel)
    }

    private var resolvedRows: [FoundationProComparisonRow] {
        if !configuration.rows.isEmpty { return configuration.rows }
        return purchaseManager.features.map(FoundationProComparisonRow.init)
    }

    private var resolvedTitle: String {
        if !configuration.title.isEmpty { return configuration.title }
        guard let planLabel = purchaseManager.activeProduct?.planLabel else { return "Pro plan" }
        return "\(planLabel) Pro"
    }

    private var appName: String {
        AppMetadata.current().name
    }

    private var celebrationCardCornerRadius: CGFloat {
        CGFloat(theme.appearance.cardCornerRadius)
    }

    private var celebrationCardBackground: Color {
        theme.elevatedSurfaceColor.opacity(0.62)
    }

    private var celebrationCardBorder: Color {
        theme.borderColor.opacity(0.45)
    }

    private var theme: AppTheme {
        configuration.themeOverride ?? environmentTheme
    }
}

#endif
