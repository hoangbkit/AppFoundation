import AppFoundation
import SwiftUI

@MainActor
struct AnalyticsDemoView: View {
    @Environment(\.appFoundationTheme) private var theme

    @State private var serverURL = "https://analytics.133043.xyz"
    @State private var appID = ""
    @State private var appKey = ""

    @State private var eventName = ""
    @State private var eventDimension = ""
    @State private var eventCount = 1

    @State private var errorCode = ""
    @State private var errorComponent = ""
    @State private var errorSeverity = "error"
    @State private var errorCount = 1

    @State private var isSending = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            List {
                connectionSection
                eventSection
                errorSection
                localStateSection

                if let statusMessage {
                    Section("Result") {
                        Label(
                            statusMessage,
                            systemImage: statusIsError
                                ? "xmark.circle.fill"
                                : "checkmark.circle.fill"
                        )
                        .foregroundStyle(statusIsError ? Color.red : Color.green)
                        .textSelection(.enabled)
                    }
                    .listRowBackground(theme.surfaceColor)
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(theme.primaryForegroundColor)
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(theme.accentColor)
    }

    private var connectionSection: some View {
        Section("Connection") {
            TextField("Server URL", text: $serverURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)

            TextField("App ID", text: $appID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("App Key (optional)", text: $appKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Text("Leave App Key empty to test keyless native ingestion. The Demo does not persist the app key; App ID still scopes the SDK local analytics state and installation identity.")
                .font(.caption)
                .foregroundStyle(theme.secondaryForegroundColor)
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var eventSection: some View {
        Section("Custom Event") {
            TextField("Event name", text: $eventName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Dimension (optional)", text: $eventDimension)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Stepper("Count: \(eventCount)", value: $eventCount, in: 1...500)

            Button {
                Task { await sendEvent() }
            } label: {
                if isSending {
                    HStack {
                        ProgressView()
                        Text("Sending…")
                    }
                } else {
                    Label("Send Event", systemImage: "paperplane.fill")
                }
            }
            .disabled(isSending || trimmed(appID).isEmpty || trimmed(eventName).isEmpty)
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var errorSection: some View {
        Section("Custom Error") {
            TextField("Error code", text: $errorCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Component", text: $errorComponent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Picker("Severity", selection: $errorSeverity) {
                Text("Error").tag("error")
                Text("Fatal").tag("fatal")
            }
            .pickerStyle(.segmented)

            Stepper("Count: \(errorCount)", value: $errorCount, in: 1...100)

            Button {
                Task { await sendError() }
            } label: {
                if isSending {
                    HStack {
                        ProgressView()
                        Text("Sending…")
                    }
                } else {
                    Label("Send Error", systemImage: "exclamationmark.triangle.fill")
                }
            }
            .disabled(
                isSending
                    || trimmed(appID).isEmpty
                    || trimmed(errorCode).isEmpty
                    || trimmed(errorComponent).isEmpty
            )
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var localStateSection: some View {
        Section("Local Test State") {
            Button("Reset Local State", systemImage: "trash", role: .destructive) {
                Task { await resetLocalState() }
            }
            .disabled(isSending || trimmed(appID).isEmpty)

            Text("Reset clears the local cumulative snapshot for the entered App ID but preserves the SDK installation identity.")
                .font(.caption)
                .foregroundStyle(theme.secondaryForegroundColor)
        }
        .listRowBackground(theme.surfaceColor)
    }

    private func sendEvent() async {
        await perform {
            let client = try makeClient()
            let dimension = trimmed(eventDimension)
            try await client.track(
                trimmed(eventName),
                dimension: dimension.isEmpty ? nil : dimension,
                count: eventCount
            )
            try await client.flush()
            return "Event '\(trimmed(eventName))' accepted by the analytics server."
        }
    }

    private func sendError() async {
        await perform {
            let client = try makeClient()
            let severity: AppAnalyticsErrorSeverity = errorSeverity == "fatal" ? .fatal : .error
            try await client.trackError(
                trimmed(errorCode),
                component: trimmed(errorComponent),
                severity: severity,
                count: errorCount
            )
            try await client.flush()
            return "Error '\(trimmed(errorCode))' accepted by the analytics server."
        }
    }

    private func resetLocalState() async {
        await perform {
            let client = try makeClient()
            try await client.resetLocalState()
            return "Local analytics state reset for '\(trimmed(appID))'."
        }
    }

    private func perform(_ operation: () async throws -> String) async {
        isSending = true
        statusMessage = nil
        defer { isSending = false }

        do {
            statusMessage = try await operation()
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private func makeClient() throws -> AppAnalyticsClient {
        let id = trimmed(appID)
        guard !id.isEmpty else {
            throw AppAnalyticsError.invalidConfiguration("App ID is required.")
        }

        let urlText = trimmed(serverURL)
        guard let url = URL(string: urlText), url.host != nil else {
            throw AppAnalyticsError.invalidConfiguration("Server URL is invalid.")
        }

        let key = trimmed(appKey)
        return AppAnalyticsClient(
            configuration: AppAnalyticsConfiguration(
                appID: id,
                appKey: key.isEmpty ? nil : key,
                baseURL: url,
                stateStorageKey: "appfoundation.demo.analytics.test.\(id)",
                transportRetryCount: 0
            )
        )
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
