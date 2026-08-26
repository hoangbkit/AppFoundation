#if canImport(SwiftUI) && canImport(StoreKit)
import SwiftUI
import UIKit

/// An extremely compact, self-contained restore control: a single line of text that
/// transitions through every state.
///
/// - Idle: the title, in the standard foreground color. The container owns any
///   leading icon (embed inside `Label`'s title slot to inherit row alignment).
/// - Restoring: "Restoring purchases…" with a trailing cancel affordance.
/// - Outcomes: short colored labels — success green, nothing-found blue, failure
///   red, timeout amber — that auto-clear back to idle; tapping an outcome retries.
///
/// Nothing here is ever presented modally, so the system App Store sign-in prompt
/// (which `AppStore.sync()` may raise, keyboard included) lands on normal UI
/// without displacing anything. A generous 60s controller timeout bounds the wait;
/// cancellation is always available mid-flight.
public struct RestorePurchasesView: View {
    @Environment(\.appFoundationTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    @State private var model = RestorePurchasesRowModel()

    private let purchaseManager: PurchaseManager
    private let configuration: RestorePurchasesRowConfiguration
    private let contentAlignment: HorizontalAlignment

    /// - Parameters:
    ///   - contentAlignment: Horizontal placement of the single line. Use `.center`
    ///     when embedding in free space such as a paywall; `.leading` suits list
    ///     rows wrapped by a container-provided icon.
    public init(
        purchaseManager: PurchaseManager,
        configuration: RestorePurchasesRowConfiguration = .init(),
        contentAlignment: HorizontalAlignment = .leading
    ) {
        self.purchaseManager = purchaseManager
        self.configuration = configuration
        self.contentAlignment = contentAlignment
    }

    public var body: some View {
        if isVisible {
            control
                .onAppear { model.reconcile(using: purchaseManager) }
                .onDisappear {
                    // Covers List recycling and navigation away mid-attempt.
                    if model.hasLocalAttemptInFlight {
                        model.cancel(using: purchaseManager)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.reconcile(using: purchaseManager)
                    }
                }
                .onChange(of: purchaseManager.activity) { _, _ in
                    model.reconcile(using: purchaseManager)
                }
                .onChange(of: model.phase) { _, phase in
                    guard case .result(let result) = phase else { return }
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: accessibilityMessage(for: result)
                    )
                }
                .accessibilityIdentifier("restore.view")
        }
    }

    // MARK: - Control

    @ViewBuilder
    private var control: some View {
        let centered = contentAlignment == .center

        Button {
            handleTap()
        } label: {
            HStack(spacing: 8) {
                if centered {
                    Spacer(minLength: 0)
                }

                Text(label)
                    .foregroundStyle(labelColor)
                    .animation(.default, value: model.phase)

                if !centered {
                    Spacer(minLength: 8)
                }

                if showsRestoring {
                    cancelButton
                }

                if centered {
                    Spacer(minLength: 0)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Taps during a restore fall through to `handleTap`, which ignores them;
        // only a purchase running elsewhere truly disables the control.
        .disabled(blockedElsewhere)
        .opacity(blockedElsewhere ? 0.45 : 1)
    }

    private func handleTap() {
        switch model.phase {
        case .idle, .result(.nothingToRestore), .result(.failure):
            model.start(using: purchaseManager, configuration: configuration)
        case .restoring, .result(.restored):
            break
        }
    }

    private var cancelButton: some View {
        Button {
            model.cancel(using: purchaseManager)
        } label: {
            Image(systemName: "xmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.secondaryForegroundColor)
                .padding(7)
                .background(Circle().fill(theme.surfaceColor))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(configuration.cancelTitle))
        .accessibilityIdentifier("restore.cancel")
    }

    // MARK: - State mapping

    private var isVisible: Bool {
        !purchaseManager.hasPro || model.phase == .result(.restored)
    }

    private var blockedElsewhere: Bool {
        purchaseManager.activity.isBusy && !showsRestoring
    }

    private var showsRestoring: Bool {
        if model.phase == .restoring {
            return true
        }
        if case .restoring = purchaseManager.activity {
            return true
        }
        return false
    }

    private var label: String {
        switch displayState {
        case .idle:
            return configuration.title
        case .restoring:
            return configuration.restoringTitle
        case .restored:
            return configuration.successLabel
        case .info:
            return configuration.nothingFoundLabel
        case .failed(let failure):
            return failure.code == .timeout
                ? configuration.timeoutLabel
                : configuration.failureLabel
        }
    }

    private var labelColor: Color {
        switch displayState {
        case .idle, .restoring:
            return theme.primaryForegroundColor
        case .restored:
            return Color.green
        case .info:
            return Color.blue
        case .failed(let failure):
            return failure.code == .timeout ? Color.orange : Color.red
        }
    }

    private enum DisplayState: Hashable {
        case idle
        case restoring
        case restored
        case info
        case failed(PurchaseFailure)
    }

    private var displayState: DisplayState {
        if showsRestoring {
            return .restoring
        }

        switch model.phase {
        case .idle, .restoring:
            return .idle
        case .result(.restored):
            return .restored
        case .result(.nothingToRestore):
            return .info
        case .result(.failure(let failure)):
            return .failed(failure)
        }
    }

    private func accessibilityMessage(for result: RestorePurchasesRowModel.RestoreResult) -> String {
        switch result {
        case .restored:
            configuration.successLabel
        case .nothingToRestore:
            configuration.nothingFoundLabel
        case .failure(let failure):
            failure.code == .timeout
                ? configuration.timeoutLabel
                : configuration.failureLabel
        }
    }
}
#endif
