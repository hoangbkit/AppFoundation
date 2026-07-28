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
}

/// App-owned copy and feature comparison content for a reusable Pro celebration screen.
public struct FoundationProCelebrationConfiguration: Sendable {
    public var navigationTitle: String
    public var doneButtonTitle: String
    public var symbolName: String
    public var title: String
    public var message: String
    public var statusSymbolName: String
    public var planTitle: String
    public var statusMessage: String
    public var featureColumnTitle: String
    public var freeColumnTitle: String
    public var proColumnTitle: String
    public var rows: [FoundationProComparisonRow]
    public var comparisonAccessibilityLabel: String
    public var themeOverride: AppTheme?

    public init(
        navigationTitle: String = "Pro",
        doneButtonTitle: String = "Done",
        symbolName: String = "diamond.fill",
        title: String,
        message: String,
        statusSymbolName: String = "checkmark.seal.fill",
        planTitle: String,
        statusMessage: String,
        featureColumnTitle: String = "Feature",
        freeColumnTitle: String = "Free",
        proColumnTitle: String = "Pro",
        rows: [FoundationProComparisonRow],
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

#if canImport(SwiftUI)
import SwiftUI

/// A theme-aware Pro entitlement celebration screen adapted from MiLove.
public struct FoundationProCelebrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFoundationTheme) private var environmentTheme

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
                        statusCard
                        comparisonTable
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
                    Button(configuration.doneButtonTitle) {
                        dismiss()
                    }
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
            ZStack {
                Circle()
                    .fill(theme.elevatedSurfaceColor.opacity(0.74))
                    .frame(width: 112, height: 112)
                    .overlay {
                        Circle().strokeBorder(theme.borderColor)
                    }

                theme.gradient
                    .frame(width: 82, height: 82)
                    .clipShape(Circle())
                    .opacity(0.55)
                    .blur(radius: 4)

                Image(systemName: configuration.symbolName)
                    .font(.system(size: 48, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.primaryForegroundColor)
            }
            .shadow(
                color: theme.accentColor.opacity(0.28),
                radius: 34,
                y: 14
            )

            VStack(spacing: 6) {
                Text(configuration.title)
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

    private var statusCard: some View {
        AppThemeCard(theme: theme) {
            HStack(spacing: 13) {
                Image(systemName: configuration.statusSymbolName)
                    .font(.system(size: 21, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 46, height: 46)
                    .background(theme.accentColor.opacity(0.13), in: Circle())
                    .overlay {
                        Circle().strokeBorder(theme.borderColor)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(configuration.planTitle)
                        .font(.headline.bold())
                        .foregroundStyle(theme.primaryForegroundColor)

                    Text(configuration.statusMessage)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryForegroundColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
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
                .background(theme.accentColor.opacity(0.035))

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

    private var theme: AppTheme {
        configuration.themeOverride ?? environmentTheme
    }
}
#endif
