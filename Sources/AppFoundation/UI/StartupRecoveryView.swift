#if canImport(SwiftUI)
import SwiftUI

public struct StartupRecoveryConfiguration: Sendable, Equatable {
    public var title: String
    public var message: String
    public var dataSafetyMessage: String?
    public var retryTitle: String
    public var recoveryOptionsTitle: String
    public var recoveryCopyTitle: String
    public var recoveryCopyMessage: String
    public var startFreshTitle: String
    public var startFreshMessage: String
    public var resetConfirmationTitle: String
    public var resetConfirmationMessage: String
    public var resetConfirmationButtonTitle: String
    public var actionErrorTitle: String

    public init(
        title: String = "We Couldn't Open Your Data",
        message: String = "The app couldn't finish preparing its local data safely.",
        dataSafetyMessage: String? = "Your existing data has not been deleted.",
        retryTitle: String = "Try Again",
        recoveryOptionsTitle: String = "Recovery Options",
        recoveryCopyTitle: String = "Save a Recovery Copy",
        recoveryCopyMessage: String = "Keep a copy of the current local data before taking other actions.",
        startFreshTitle: String = "Start Fresh",
        startFreshMessage: String = "Remove this app's local data from this device and start again.",
        resetConfirmationTitle: String = "Start fresh on this device?",
        resetConfirmationMessage: String = "Only continue if retrying does not work. The app decides what data is preserved before reset.",
        resetConfirmationButtonTitle: String = "Start Fresh",
        actionErrorTitle: String = "Recovery Action Failed"
    ) {
        self.title = title
        self.message = message
        self.dataSafetyMessage = dataSafetyMessage
        self.retryTitle = retryTitle
        self.recoveryOptionsTitle = recoveryOptionsTitle
        self.recoveryCopyTitle = recoveryCopyTitle
        self.recoveryCopyMessage = recoveryCopyMessage
        self.startFreshTitle = startFreshTitle
        self.startFreshMessage = startFreshMessage
        self.resetConfirmationTitle = resetConfirmationTitle
        self.resetConfirmationMessage = resetConfirmationMessage
        self.resetConfirmationButtonTitle = resetConfirmationButtonTitle
        self.actionErrorTitle = actionErrorTitle
    }
}

public struct StartupRecoveryStyle {
    public var backgroundColor: Color
    public var foregroundColor: Color
    public var secondaryForegroundColor: Color
    public var accentColor: Color
    public var cardColor: Color

    public init(
        backgroundColor: Color = Color(uiColor: .systemBackground),
        foregroundColor: Color = .primary,
        secondaryForegroundColor: Color = .secondary,
        accentColor: Color = .accentColor,
        cardColor: Color = Color(uiColor: .secondarySystemBackground)
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.secondaryForegroundColor = secondaryForegroundColor
        self.accentColor = accentColor
        self.cardColor = cardColor
    }
}

@MainActor
public struct StartupRecoveryView: View {
    public typealias RetryAction = () async throws -> Void
    public typealias RecoveryCopyAction = () async throws -> ExportFile
    public typealias StartFreshAction = () async throws -> Void

    private let configuration: StartupRecoveryConfiguration
    private let style: StartupRecoveryStyle
    private let retry: RetryAction
    private let makeRecoveryCopy: RecoveryCopyAction?
    private let startFresh: StartFreshAction?

    @State private var showsRecoveryOptions = false
    @State private var showsResetConfirmation = false
    @State private var sharedRecoveryFile: ExportFile?
    @State private var showsRecoveryShareSheet = false
    @State private var activeAction: ActiveAction?
    @State private var actionError: String?

    public init(
        configuration: StartupRecoveryConfiguration = .init(),
        style: StartupRecoveryStyle = .init(),
        retry: @escaping RetryAction,
        makeRecoveryCopy: RecoveryCopyAction? = nil,
        startFresh: StartFreshAction? = nil
    ) {
        self.configuration = configuration
        self.style = style
        self.retry = retry
        self.makeRecoveryCopy = makeRecoveryCopy
        self.startFresh = startFresh
    }

    public var body: some View {
        ZStack {
            style.backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 64)

                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(style.accentColor)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(configuration.title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text(configuration.message)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(style.secondaryForegroundColor)

                        if let dataSafetyMessage = configuration.dataSafetyMessage {
                            Text(dataSafetyMessage)
                                .font(.footnote.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(style.secondaryForegroundColor)
                        }
                    }
                    .frame(maxWidth: 460)

                    Button {
                        perform(.retry, action: retry)
                    } label: {
                        Label(configuration.retryTitle, systemImage: "arrow.clockwise")
                            .font(.headline)
                            .frame(maxWidth: 320)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(style.accentColor)
                    .disabled(isWorking)

                    if hasRecoveryOptions {
                        DisclosureGroup(
                            isExpanded: $showsRecoveryOptions,
                            content: {
                                VStack(spacing: 0) {
                                    if makeRecoveryCopy != nil {
                                        recoveryRow(
                                            title: configuration.recoveryCopyTitle,
                                            message: configuration.recoveryCopyMessage,
                                            systemImage: "square.and.arrow.up"
                                        ) {
                                            exportRecoveryCopy()
                                        }
                                    }

                                    if makeRecoveryCopy != nil, startFresh != nil {
                                        Divider()
                                    }

                                    if startFresh != nil {
                                        recoveryRow(
                                            title: configuration.startFreshTitle,
                                            message: configuration.startFreshMessage,
                                            systemImage: "arrow.counterclockwise",
                                            destructive: true
                                        ) {
                                            showsResetConfirmation = true
                                        }
                                    }
                                }
                                .background(
                                    style.cardColor,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .padding(.top, 12)
                            },
                            label: {
                                Text(configuration.recoveryOptionsTitle)
                                    .font(.subheadline.weight(.semibold))
                            }
                        )
                        .tint(style.accentColor)
                        .frame(maxWidth: 460)
                    }

                    Spacer(minLength: 44)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(style.foregroundColor)

            if isWorking {
                ProgressView()
                    .controlSize(.large)
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Working")
            }
        }
        .confirmationDialog(
            configuration.resetConfirmationTitle,
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(configuration.resetConfirmationButtonTitle, role: .destructive) {
                guard let startFresh else { return }
                perform(.startFresh, action: startFresh)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(configuration.resetConfirmationMessage)
        }
        .alert(
            configuration.actionErrorTitle,
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )
        ) {
            Button("OK") { actionError = nil }
        } message: {
            Text(actionError ?? "Unknown error")
        }
        .sheet(isPresented: $showsRecoveryShareSheet, onDismiss: {
            sharedRecoveryFile = nil
        }) {
            if let sharedRecoveryFile {
                ExportShareSheet(files: [sharedRecoveryFile])
            }
        }
    }

    private var hasRecoveryOptions: Bool {
        makeRecoveryCopy != nil || startFresh != nil
    }

    private var isWorking: Bool {
        activeAction != nil
    }

    private func recoveryRow(
        title: String,
        message: String,
        systemImage: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(style.secondaryForegroundColor)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)
            }
            .foregroundStyle(destructive ? Color.red : style.foregroundColor)
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    private func exportRecoveryCopy() {
        guard let makeRecoveryCopy, !isWorking else { return }
        activeAction = .recoveryCopy
        Task { @MainActor in
            defer { activeAction = nil }
            do {
                sharedRecoveryFile = try await makeRecoveryCopy()
                showsRecoveryShareSheet = true
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    private func perform(
        _ activeAction: ActiveAction,
        action: @escaping () async throws -> Void
    ) {
        guard !isWorking else { return }
        self.activeAction = activeAction
        Task { @MainActor in
            defer { self.activeAction = nil }
            do {
                try await action()
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    private enum ActiveAction: Equatable {
        case retry
        case recoveryCopy
        case startFresh
    }
}
#endif
