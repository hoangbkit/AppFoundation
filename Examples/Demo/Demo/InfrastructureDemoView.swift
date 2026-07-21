import AppFoundation
import SwiftUI

struct InfrastructureDemoView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.appFoundationTheme) private var theme

    @State private var isShowingPaywall = false
    @State private var sharePayload: DemoSharePayload?
    @State private var alertMessage: String?
    @State private var backupStatus = "Not tested"
    @State private var sharedStoreStatus = "Not tested"
    @State private var notificationStatus = "Not scheduled"

    private let accessPolicy = PremiumAccessPolicy()

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            List {
                commerceSection

                SubscriptionSettingsSection(
                    purchaseManager: purchases,
                    onUpgrade: { isShowingPaywall = true }
                )
                .listRowBackground(theme.surfaceColor)

                exportSection
                backupSection
                sharedPlatformSection
                notificationSection
                utilitiesSection
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(theme.primaryForegroundColor)
        }
        .navigationTitle("New APIs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(theme.accentColor)
        .animation(.smooth, value: theme.id)
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(
                purchaseManager: purchases,
                configuration: DemoConfiguration.modernPaywall
            )
        }
        .sheet(item: $sharePayload) { payload in
            ExportShareSheet(files: payload.files)
        }
        .alert("Demo Result", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var commerceSection: some View {
        Section("Commerce and gating") {
            LabeledContent("PurchaseManager.hasPro", value: purchases.hasPro ? "true" : "false")

            PremiumButton(
                decision: premiumDecision,
                action: {
                    HapticService.notification(.success)
                    alertMessage = "Premium action completed."
                },
                onRequestUpgrade: { _ in isShowingPaywall = true }
            ) {
                Label("Run premium action", systemImage: "wand.and.stars")
            }

            PremiumGate(decision: premiumDecision) {
                Label("Premium editor unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(theme.primaryForegroundColor)
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background(theme.elevatedSurfaceColor)
            } locked: { feature in
                LockedFeatureOverlay(feature: feature) {
                    isShowingPaywall = true
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.borderColor)
            }
            .frame(height: 104)

            LabeledContent(
                "Existing content after expiry",
                value: existingContentDecision == .allowed ? "Accessible" : "Locked"
            )
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var exportSection: some View {
        Section("ExportKit") {
            DemoExportArtwork(theme: theme)
                .aspectRatio(1200 / 630, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(theme.borderColor)
                }
                .accessibilityLabel("Preview of the image exported by ExportKit")

            Button("Export current theme as rounded PNG", systemImage: "square.and.arrow.up") {
                exportPreview()
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var backupSection: some View {
        Section("BackupKit") {
            LabeledContent("Round trip", value: backupStatus)
            Button("Create and verify package", systemImage: "archivebox") {
                runBackupRoundTrip()
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var sharedPlatformSection: some View {
        Section("Widget and shared data") {
            LabeledContent(
                "Deep link",
                value: DemoConfiguration.sampleDeepLink.url?.absoluteString ?? "Invalid"
            )
            .font(.caption)

            LabeledContent("Snapshot store", value: sharedStoreStatus)
            Button("Save and load shared snapshot", systemImage: "arrow.triangle.2.circlepath") {
                runSharedSnapshotRoundTrip()
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var notificationSection: some View {
        Section("Notifications") {
            LabeledContent("Status", value: notificationStatus)
            Button("Schedule notification in 10 seconds", systemImage: "bell.badge") {
                scheduleDemoNotification()
            }
            Button("Cancel demo notification", systemImage: "bell.slash", role: .destructive) {
                Task {
                    await LocalNotificationManager().cancel(ids: [Self.notificationID])
                    await MainActor.run { notificationStatus = "Cancelled" }
                }
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var utilitiesSection: some View {
        let info = AppInfo.current()
        let reviewEligible = ReviewRequestPolicy(
            minimumMeaningfulActions: 3,
            minimumDaysBetweenRequests: 90
        ).shouldRequest(
            meaningfulActionCount: 5,
            lastRequestDate: Calendar.current.date(byAdding: .day, value: -120, to: .now)
        )

        return Section("Utilities") {
            LabeledContent("AppInfo", value: "\(info.displayName) \(info.versionAndBuild)")
            LabeledContent("Review policy sample", value: reviewEligible ? "Eligible" : "Wait")

            AsyncButton {
                try await Task.sleep(for: .milliseconds(650))
            } label: {
                Label("Run AsyncButton", systemImage: "hourglass")
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var premiumDecision: PremiumAccessDecision {
        accessPolicy.decision(
            for: DemoConfiguration.premiumExportFeature,
            requirement: .pro,
            hasPro: purchases.hasPro
        )
    }

    private var existingContentDecision: PremiumAccessDecision {
        accessPolicy.decision(
            for: DemoConfiguration.premiumExportFeature,
            requirement: .pro,
            hasPro: purchases.hasPro,
            isExistingContent: true
        )
    }

    @MainActor
    private func exportPreview() {
        Task { @MainActor in
            do {
                let data = try ViewImageExporter.render(
                    DemoExportArtwork(theme: theme),
                    size: CGSize(width: 1200, height: 630),
                    scale: 1,
                    cornerRadius: 72,
                    maximumPixelCount: 10_000_000,
                    format: .png
                )
                let file = try await ExportFileWriter().write(
                    data,
                    filename: "AppFoundation \(theme.title) Demo Export",
                    fileExtension: ExportImageFormat.png.fileExtension
                )
                sharePayload = DemoSharePayload(files: [file])
            } catch {
                alertMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func runBackupRoundTrip() {
        Task { @MainActor in
            do {
                backupStatus = "Working…"
                let info = AppInfo.current()
                let payload = DemoBackupPayload(
                    title: "AppFoundation Demo",
                    items: ["Commerce", "Export", "Backup", "Widgets", "Notifications"]
                )
                let envelope = BackupEnvelope(
                    format: DemoConfiguration.backupConfiguration.format,
                    version: DemoConfiguration.backupConfiguration.version,
                    appIdentifier: DemoConfiguration.backupConfiguration.appIdentifier,
                    appVersion: info.version,
                    appBuild: info.build,
                    payload: payload,
                    metadata: ["source": "Examples/Demo", "theme": theme.id]
                )
                let asset = BackupAsset(
                    relativePath: "notes/readme.txt",
                    data: Data("Demo backup asset".utf8)
                )
                let packageURL = try await BackupPackageWriter().write(
                    envelope: envelope,
                    configuration: DemoConfiguration.backupConfiguration,
                    assets: [asset],
                    filename: "AppFoundation Demo Backup"
                )
                let result = try await BackupPackageReader().read(
                    DemoBackupPayload.self,
                    from: packageURL,
                    configuration: DemoConfiguration.backupConfiguration
                )
                backupStatus = "Verified \(result.payload.items.count) items + \(result.assets.count) asset"
            } catch {
                backupStatus = "Failed"
                alertMessage = "Backup failed: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func runSharedSnapshotRoundTrip() {
        Task { @MainActor in
            do {
                sharedStoreStatus = "Working…"
                let store = try AppGroupStore<DemoWidgetSnapshot>(
                    suiteName: DemoConfiguration.sharedSuiteName,
                    key: "widget-preview"
                )
                try await store.save(
                    DemoWidgetSnapshot(
                        title: "AppFoundation Demo",
                        deepLink: DemoConfiguration.sampleDeepLink.url?.absoluteString ?? ""
                    ),
                    schemaVersion: 1
                )
                let loaded = try await store.load()
                sharedStoreStatus = loaded == nil
                    ? "No snapshot"
                    : "Loaded schema \(loaded?.schemaVersion ?? 0)"
            } catch {
                sharedStoreStatus = "Failed"
                alertMessage = "Shared snapshot failed: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func scheduleDemoNotification() {
        Task { @MainActor in
            do {
                notificationStatus = "Requesting permission…"
                let manager = LocalNotificationManager()
                guard try await manager.requestAuthorization() else {
                    notificationStatus = "Permission denied"
                    return
                }
                try await manager.replace(
                    LocalNotificationRequest(
                        id: Self.notificationID,
                        title: "AppFoundation Demo",
                        body: "LocalNotificationManager scheduled this reminder.",
                        date: .now.addingTimeInterval(10),
                        userInfo: ["source": "Examples/Demo"]
                    )
                )
                notificationStatus = "Scheduled"
            } catch {
                notificationStatus = "Failed"
                alertMessage = "Notification failed: \(error.localizedDescription)"
            }
        }
    }

    private static let notificationID = "appfoundation.demo.notification"
}

private struct DemoExportArtwork: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            theme.backgroundColor
            theme.gradient.opacity(0.94)

            RadialGradient(
                colors: [theme.accentColor.opacity(0.28), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 620
            )

            VStack(alignment: .leading, spacing: 18) {
                Label("APPFOUNDATION", systemImage: "square.stack.3d.up.fill")
                    .font(.headline)
                    .foregroundStyle(theme.accentColor)
                Spacer()
                Text("Shared infrastructure\nfor every app")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryForegroundColor)
                Text("Rendered with the \(theme.title) theme")
                    .font(.title3)
                    .foregroundStyle(theme.secondaryForegroundColor)
            }
            .padding(54)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct DemoBackupPayload: Codable, Sendable, Equatable {
    let title: String
    let items: [String]
}

private struct DemoWidgetSnapshot: Codable, Sendable, Equatable {
    let title: String
    let deepLink: String
}

private struct DemoSharePayload: Identifiable {
    let id = UUID()
    let files: [ExportFile]
}