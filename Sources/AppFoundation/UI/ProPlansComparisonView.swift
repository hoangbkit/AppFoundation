#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

/// A dedicated Free-versus-Pro comparison surface for Settings.
///
/// Its presentation intentionally mirrors `ProUpsellView`; only the header copy
/// changes so users can open the same comparison design without a limit-reached context.
public struct ProPlansComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFoundationTheme) private var theme
    @Environment(PurchaseManager.self) private var purchaseManager

    private let title: String
    private let message: String
    private let onUnlockPro: () -> Void

    public init(
        title: String = "Compare Free and Pro",
        message: String = "See what’s included in each plan and choose what works best for you.",
        onUnlockPro: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.onUnlockPro = onUnlockPro
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
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
            ProCrownIcon()

            VStack(spacing: 7) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(theme.primaryForegroundColor)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var comparisonTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
            GridRow {
                Text("Feature")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .frame(minWidth: 58)
                    .gridColumnAlignment(.center)
                Text("Pro")
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

                if index < resolvedRows.count - 1 {
                    Divider()
                        .overlay(theme.borderColor.opacity(0.35))
                        .gridCellColumns(3)
                }
            }
        }
        .background(
            theme.elevatedSurfaceColor.opacity(0.62),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.borderColor.opacity(0.45))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Free and Pro comparison")
    }

    private var unlockAction: some View {
        Button(action: onUnlockPro) {
            Label("Unlock Pro", systemImage: "crown.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ProPlansComparisonPrimaryButtonStyle(theme: theme))
    }

    private var resolvedRows: [LimitReachedComparisonRow] {
        purchaseManager.features.map(LimitReachedComparisonRow.init)
    }
}

private struct ProPlansComparisonPrimaryButtonStyle: ButtonStyle {
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
