#if DEBUG && canImport(SwiftUI) && canImport(StoreKit) && canImport(UIKit)
import StoreKit
import SwiftUI
import UIKit

@MainActor
public struct FoundationDeveloperReplay: Identifiable {
    public enum Presentation {
        case sheet
        case fullScreen
    }

    public let id: String
    public let title: String
    public let systemImage: String
    public let presentation: Presentation

    private let makeContent: (@escaping () -> Void) -> AnyView

    public init<Content: View>(
        id: String = UUID().uuidString,
        title: String,
        systemImage: String = "play.rectangle",
        presentation: Presentation = .sheet,
        content: @escaping (_ dismiss: @escaping () -> Void) -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.presentation = presentation
        self.makeContent = { dismiss in AnyView(content(dismiss)) }
    }

    fileprivate func content(dismiss: @escaping () -> Void) -> AnyView {
        makeContent(dismiss)
    }
}

@MainActor
public struct FoundationDeveloperDestination: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    private let makeContent: () -> AnyView

    public init<Content: View>(
        id: String = UUID().uuidString,
        title: String,
        systemImage: String = "hammer",
        content: @escaping () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.makeContent = { AnyView(content()) }
    }

    fileprivate func content() -> AnyView {
        makeContent()
    }
}

@MainActor
public struct FoundationDeveloperAction: Identifiable {
    public enum Role {
        case normal
        case destructive
    }

    public let id: String
    public let title: String
    public let systemImage: String
    public let role: Role
    private let performAction: () async throws -> Void

    public init(
        id: String = UUID().uuidString,
        title: String,
        systemImage: String = "hammer",
        role: Role = .normal,
        action: @escaping () async throws -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.performAction = action
    }

    fileprivate func perform() async throws {
        try await performAction()
    }
}

@MainActor
public struct FoundationDeveloperToggle: Identifiable {
    public let id: String
    public let title: String
    private let readValue: () -> Bool
    private let writeValue: (Bool) -> Void

    public init(
        id: String = UUID().uuidString,
        title: String,
        value: @escaping () -> Bool,
        setValue: @escaping (Bool) -> Void
    ) {
        self.id = id
        self.title = title
        self.readValue = value
        self.writeValue = setValue
    }

    fileprivate var value: Bool { readValue() }
    fileprivate func set(_ value: Bool) { writeValue(value) }
}

@MainActor
public struct FoundationDeveloperValue: Identifiable {
    public let id: String
    public let title: String
    private let readValue: () -> String

    public init(
        id: String = UUID().uuidString,
        title: String,
        value: @escaping () -> String
    ) {
        self.id = id
        self.title = title
        self.readValue = value
    }

    fileprivate var value: String { readValue() }
}

public enum FoundationDeveloperItem: Identifiable {
    case action(FoundationDeveloperAction)
    case toggle(FoundationDeveloperToggle)
    case value(FoundationDeveloperValue)
    case destination(FoundationDeveloperDestination)

    public var id: String {
        switch self {
        case .action(let action): action.id
        case .toggle(let toggle): toggle.id
        case .value(let value): value.id
        case .destination(let destination): destination.id
        }
    }
}

@MainActor
public struct FoundationDeveloperSection: Identifiable {
    public let id: String
    public let title: String
    public let items: [FoundationDeveloperItem]

    public init(
        id: String = UUID().uuidString,
        title: String,
        items: [FoundationDeveloperItem]
    ) {
        self.id = id
        self.title = title
        self.items = items
    }
}

@MainActor
public struct FoundationDeveloperConfiguration {
    public var replays: [FoundationDeveloperReplay]
    public var resetOnboarding: FoundationDeveloperAction?
    public var additionalSections: [FoundationDeveloperSection]

    public init(
        replays: [FoundationDeveloperReplay] = [],
        resetOnboarding: FoundationDeveloperAction? = nil,
        additionalSections: [FoundationDeveloperSection] = []
    ) {
        self.replays = replays
        self.resetOnboarding = resetOnboarding
        self.additionalSections = additionalSections
    }
}

/// Debug-only developer controls shared by AppFoundation apps.
///
/// The common App, Purchases, Failure Simulation, Startup, and Diagnostics sections are always
/// present. Apps can register their real paywall/onboarding/upsell flows and append structured
/// app-specific sections through ``FoundationDeveloperConfiguration``.
@MainActor
public struct FoundationDeveloperView: View {
    private let purchaseManager: PurchaseManager
    private let configuration: FoundationDeveloperConfiguration

    @State private var purchaseOutcome: DeveloperPurchaseOutcome = .success
    @State private var catalogFailureEnabled = false
    @State private var restoreFailureEnabled = false
    @State private var latency: DeveloperPurchaseLatency = .normal
    @State private var sheetReplay: FoundationDeveloperReplay?
    @State private var fullScreenReplay: FoundationDeveloperReplay?
    @State private var showsRecoveryPreview = false
    @State private var actionError: String?

    public init(
        purchaseManager: PurchaseManager,
        configuration: FoundationDeveloperConfiguration = .init()
    ) {
        self.purchaseManager = purchaseManager
        self.configuration = configuration
    }

    public var body: some View {
        Form {
            appSection
            purchasesSection
            failureSimulationSection
            replaySection
            startupSection
            diagnosticsSection
            additionalSections
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheetReplay) { replay in
            replay.content { sheetReplay = nil }
        }
        .fullScreenCover(item: $fullScreenReplay) { replay in
            replay.content { fullScreenReplay = nil }
        }
        .fullScreenCover(isPresented: $showsRecoveryPreview) {
            StartupRecoveryView(
                configuration: StartupRecoveryConfiguration(
                    title: "We Couldn't Open Your Data",
                    message: "This is the AppFoundation developer preview of the last-resort startup recovery screen.",
                    dataSafetyMessage: "No app data is changed by this preview."
                ),
                retry: {
                    showsRecoveryPreview = false
                }
            )
        }
        .alert("Developer Action Failed", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "Unknown error")
        }
    }

    private var appSection: some View {
        let info = AppInfo.current()
        return Section("App") {
            LabeledContent("App", value: info.displayName)
            LabeledContent("Version", value: info.versionAndBuild)
            LabeledContent("Bundle ID", value: info.bundleIdentifier)
            LabeledContent("Build", value: "Debug")
            LabeledContent("Environment", value: runtimeEnvironment)
            LabeledContent("System", value: UIDevice.current.systemVersion)
        }
    }

    private var purchasesSection: some View {
        Section("Purchases") {
            Toggle(
                "Simulated purchases",
                isOn: Binding(
                    get: { purchaseManager.isUsingSimulatedPurchases },
                    set: { enabled in
                        Task { @MainActor in
                            await purchaseManager.setSimulatedPurchasesEnabled(enabled)
                            resetFailureControls()
                        }
                    }
                )
            )

            LabeledContent("Entitlement", value: entitlementTitle)
            LabeledContent("Product state", value: productLoadingTitle)

            NavigationLink {
                FoundationDeveloperProductCatalogView(products: purchaseManager.products)
            } label: {
                LabeledContent("Loaded product prices", value: "\(purchaseManager.products.count)")
            }

            NavigationLink {
                FoundationDeveloperEntitlementView(purchaseManager: purchaseManager)
            } label: {
                LabeledContent(
                    "Simulated entitlement",
                    value: simulatedEntitlementTitle
                )
            }
            .disabled(!purchaseManager.isUsingSimulatedPurchases)

            NavigationLink {
                FoundationDeveloperPlansView(purchaseManager: purchaseManager)
            } label: {
                LabeledContent(
                    "Simulated plans & prices",
                    value: "\(purchaseManager.simulatedConfigurationSnapshot.productIDs.count)"
                )
            }

            Button("Refresh entitlement", systemImage: "arrow.clockwise") {
                Task { @MainActor in
                    await purchaseManager.refreshEntitlements()
                }
            }

            Button("Reload products", systemImage: "arrow.triangle.2.circlepath") {
                Task { @MainActor in
                    await purchaseManager.loadProducts(force: true)
                }
            }

            Button("Reset simulated purchases", systemImage: "trash", role: .destructive) {
                Task { @MainActor in
                    await purchaseManager.resetSimulatedPurchases()
                    resetFailureControls()
                }
            }
            .disabled(!purchaseManager.isUsingSimulatedPurchases)
        }
    }

    private var failureSimulationSection: some View {
        Section("Purchase Failure Simulation") {
            Picker("Purchase outcome", selection: $purchaseOutcome) {
                ForEach(DeveloperPurchaseOutcome.allCases) { outcome in
                    Text(outcome.title).tag(outcome)
                }
            }
            .onChange(of: purchaseOutcome) { _, newValue in
                applyPurchaseOutcome(newValue)
            }

            Toggle("Product loading failure", isOn: Binding(
                get: { catalogFailureEnabled },
                set: { enabled in
                    catalogFailureEnabled = enabled
                    Task { @MainActor in
                        await purchaseManager.setSimulatedProductLoadingFailure(
                            enabled ? .noProductsAvailable : nil
                        )
                    }
                }
            ))

            Toggle("Restore failure", isOn: Binding(
                get: { restoreFailureEnabled },
                set: { enabled in
                    restoreFailureEnabled = enabled
                    purchaseManager.setSimulatedRestoreFailure(
                        enabled ? DeveloperPurchaseOutcome.networkFailure.failure : nil
                    )
                }
            ))

            Picker("Operation latency", selection: $latency) {
                ForEach(DeveloperPurchaseLatency.allCases) { latency in
                    Text(latency.title).tag(latency)
                }
            }
            .onChange(of: latency) { _, newValue in
                purchaseManager.setSimulatedOperationDelay(newValue.duration)
            }

            Button("Reset failure simulation", systemImage: "arrow.counterclockwise") {
                Task { @MainActor in
                    await purchaseManager.resetSimulatedFailures()
                    resetFailureControls()
                }
            }
        }
        .disabled(!purchaseManager.isUsingSimulatedPurchases)
    }

    @ViewBuilder
    private var replaySection: some View {
        if !configuration.replays.isEmpty || configuration.resetOnboarding != nil {
            Section("Replay") {
                ForEach(configuration.replays) { replay in
                    Button {
                        present(replay)
                    } label: {
                        Label(replay.title, systemImage: replay.systemImage)
                    }
                }

                if let resetOnboarding = configuration.resetOnboarding {
                    developerActionButton(resetOnboarding)
                }
            }
        }
    }

    private var startupSection: some View {
        Section("Startup & Recovery") {
            Button("Preview recovery screen", systemImage: "exclamationmark.triangle") {
                showsRecoveryPreview = true
            }

            Text("Apps can register real startup failure/reset controls in their additional developer sections. The built-in preview never mutates app data.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            LabeledContent("Purchase mode", value: purchaseModeTitle)
            LabeledContent("Purchase activity", value: purchaseActivityTitle)
            LabeledContent("Preferred product", value: purchaseManager.preferredProduct?.id ?? "None")
            LabeledContent(
                "Configured products",
                value: "\(purchaseManager.simulatedConfigurationSnapshot.productIDs.count) simulated"
            )

            Button("Copy diagnostics", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = diagnosticText
            }
        }
    }

    @ViewBuilder
    private var additionalSections: some View {
        ForEach(configuration.additionalSections) { section in
            Section(section.title) {
                ForEach(section.items) { item in
                    developerItem(item)
                }
            }
        }
    }

    @ViewBuilder
    private func developerItem(_ item: FoundationDeveloperItem) -> some View {
        switch item {
        case .action(let action):
            developerActionButton(action)

        case .toggle(let toggle):
            Toggle(toggle.title, isOn: Binding(
                get: { toggle.value },
                set: { toggle.set($0) }
            ))

        case .value(let value):
            LabeledContent(value.title, value: value.value)

        case .destination(let destination):
            NavigationLink {
                destination.content()
            } label: {
                Label(destination.title, systemImage: destination.systemImage)
            }
        }
    }

    private func developerActionButton(_ action: FoundationDeveloperAction) -> some View {
        Button(
            action.title,
            systemImage: action.systemImage,
            role: action.role == .destructive ? .destructive : nil
        ) {
            Task { @MainActor in
                do {
                    try await action.perform()
                } catch {
                    actionError = error.localizedDescription
                }
            }
        }
    }

    private func present(_ replay: FoundationDeveloperReplay) {
        switch replay.presentation {
        case .sheet:
            sheetReplay = replay
        case .fullScreen:
            fullScreenReplay = replay
        }
    }

    private func applyPurchaseOutcome(_ outcome: DeveloperPurchaseOutcome) {
        for productID in purchaseManager.simulatedConfigurationSnapshot.productIDs {
            purchaseManager.setSimulatedPurchaseResult(outcome.result, for: productID)
        }
    }

    private func resetFailureControls() {
        purchaseOutcome = .success
        catalogFailureEnabled = false
        restoreFailureEnabled = false
        latency = .normal
        purchaseManager.setSimulatedOperationDelay(latency.duration)
    }

    private var runtimeEnvironment: String {
        #if targetEnvironment(simulator)
        "Simulator"
        #else
        "Device"
        #endif
    }

    private var purchaseModeTitle: String {
        purchaseManager.isUsingSimulatedPurchases ? "Simulated" : "Live StoreKit"
    }

    private var entitlementTitle: String {
        switch purchaseManager.entitlementState {
        case .checking: "Checking"
        case .inactive: "Free"
        case .active: "Pro"
        }
    }

    private var simulatedEntitlementTitle: String {
        let ids = purchaseManager.simulatedPurchasedProductIDs
        guard !ids.isEmpty else { return "Free" }
        return ids.sorted().joined(separator: ", ")
    }

    private var productLoadingTitle: String {
        switch purchaseManager.productLoadingState {
        case .idle: "Idle"
        case .loading: "Loading"
        case .loaded: "Loaded"
        case .failed(let failure): "Failed: \(failure.code.rawValue)"
        }
    }

    private var purchaseActivityTitle: String {
        switch purchaseManager.activity {
        case .idle: "Idle"
        case .purchasing(let productID): "Purchasing \(productID)"
        case .restoring: "Restoring"
        case .pending(let productID): "Pending \(productID)"
        case .failed(let failure): "Failed: \(failure.code.rawValue)"
        }
    }

    private var diagnosticText: String {
        let info = AppInfo.current()
        let products = purchaseManager.products
            .map { product in
                var value = "\(product.id) = \(product.displayPrice)"
                if let offer = product.introductoryOffer {
                    let eligibility = offer.isEligible ? "eligible" : "ineligible"
                    value += " · \(offer.headline) · \(eligibility)"
                }
                return value
            }
            .joined(separator: "\n")
        return """
        App: \(info.displayName) \(info.versionAndBuild)
        Bundle: \(info.bundleIdentifier)
        Environment: \(runtimeEnvironment)
        iOS: \(UIDevice.current.systemVersion)
        Purchase mode: \(purchaseModeTitle)
        Entitlement: \(entitlementTitle)
        Product state: \(productLoadingTitle)
        Purchase activity: \(purchaseActivityTitle)
        Preferred product: \(purchaseManager.preferredProduct?.id ?? "None")
        Products:\n\(products.isEmpty ? "None" : products)
        """
    }
}

@MainActor
private struct FoundationDeveloperProductCatalogView: View {
    let products: [StoreProduct]

    var body: some View {
        List {
            if products.isEmpty {
                ContentUnavailableView(
                    "No Products Loaded",
                    systemImage: "cart",
                    description: Text("Reload products or enable the simulator to inspect pricing.")
                )
            } else {
                ForEach(products) { product in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(product.displayName)
                                .font(.headline)
                            Spacer()
                            Text(product.displayPrice)
                                .font(.headline)
                        }
                        Text(product.id)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text(product.subscriptionPeriod?.shortLabel ?? "lifetime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let offer = product.introductoryOffer {
                            Text("\(offer.headline) · \(offer.isEligible ? "Eligible" : "Ineligible")")
                                .font(.caption)
                                .foregroundStyle(offer.isEligible ? .green : .secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .navigationTitle("Product Prices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
private struct FoundationDeveloperEntitlementView: View {
    let purchaseManager: PurchaseManager

    var body: some View {
        List {
            Section("Simulated Entitlement") {
                Button {
                    Task { @MainActor in
                        await purchaseManager.setSimulatedPurchasedProductIDs([])
                    }
                } label: {
                    entitlementRow(title: "Free", productID: nil)
                }

                ForEach(purchaseManager.simulatedConfigurationSnapshot.productIDs, id: \.self) { productID in
                    Button {
                        Task { @MainActor in
                            await purchaseManager.setSimulatedPurchasedProductIDs([productID])
                        }
                    } label: {
                        entitlementRow(
                            title: purchaseManager.simulatedCatalogProducts
                                .first(where: { $0.id == productID })?.displayName ?? productID,
                            productID: productID
                        )
                    }
                }
            }
        }
        .navigationTitle("Entitlement")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func entitlementRow(title: String, productID: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected(productID) {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
    }

    private func isSelected(_ productID: String?) -> Bool {
        let active = purchaseManager.simulatedPurchasedProductIDs
        guard let productID else { return active.isEmpty }
        return active == Set([productID])
    }
}

@MainActor
private struct FoundationDeveloperPlansView: View {
    let purchaseManager: PurchaseManager

    @Environment(\.dismiss) private var dismiss
    @State private var plans: [DeveloperPlanDraft]
    @State private var preferredProductID: String
    @State private var validationMessage: String?

    init(purchaseManager: PurchaseManager) {
        self.purchaseManager = purchaseManager
        let configuration = purchaseManager.simulatedConfigurationSnapshot
        let sourceProducts = purchaseManager.simulatedCatalogProducts.isEmpty
            ? purchaseManager.products
            : purchaseManager.simulatedCatalogProducts
        let drafts = sourceProducts.map {
            DeveloperPlanDraft(
                product: $0,
                enabled: configuration.productIDs.contains($0.id),
                unlocksEntitlement: configuration.entitledProductIDs.contains($0.id)
            )
        }
        _plans = State(initialValue: drafts)
        _preferredProductID = State(
            initialValue: configuration.preferredProductID
                ?? drafts.first(where: \.enabled)?.productID
                ?? ""
        )
    }

    var body: some View {
        Form {
            Section {
                ForEach($plans) { $plan in
                    NavigationLink {
                        DeveloperPlanDetailView(plan: $plan)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(plan.displayName.isEmpty ? plan.productID : plan.displayName)
                                Text("\(plan.displayPrice) · \(plan.period.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let offerSummary = plan.introductoryOfferSummary {
                                    Text(offerSummary)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if plan.enabled {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                }
                .onDelete { plans.remove(atOffsets: $0) }
                .onMove { plans.move(fromOffsets: $0, toOffset: $1) }

                Button("Add simulated plan", systemImage: "plus") {
                    let index = plans.count + 1
                    plans.append(.new(index: index))
                }
            } header: {
                Text("Plans")
            } footer: {
                Text("Only enabled products appear in simulated paywalls. Pricing and introductory-offer changes never affect App Store Connect.")
            }

            Section("Default Selection") {
                if enabledPlans.isEmpty {
                    Text("Enable at least one plan")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Preferred plan", selection: $preferredProductID) {
                        ForEach(enabledPlans) { plan in
                            Text(plan.displayName.isEmpty ? plan.productID : plan.displayName)
                                .tag(plan.productID)
                        }
                    }
                }
            }

            Section {
                Button("Restore app defaults", role: .destructive) {
                    let configuration = purchaseManager.configuration
                    let sourceProducts = purchaseManager.products.isEmpty
                        ? purchaseManager.simulatedCatalogProducts
                        : purchaseManager.products
                    plans = sourceProducts.map {
                        DeveloperPlanDraft(
                            product: $0,
                            enabled: configuration.productIDs.contains($0.id),
                            unlocksEntitlement: configuration.entitledProductIDs.contains($0.id)
                        )
                    }
                    preferredProductID = configuration.preferredProductID
                        ?? plans.first(where: \.enabled)?.productID
                        ?? ""
                }
            }
        }
        .navigationTitle("Simulated Plans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    apply()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Cannot Apply Plans", isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) {
            Button("OK", role: .cancel) { validationMessage = nil }
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private var enabledPlans: [DeveloperPlanDraft] {
        plans.filter(\.enabled)
    }

    private func apply() {
        let enabled = enabledPlans
        guard !enabled.isEmpty else {
            validationMessage = "Enable at least one simulated plan."
            return
        }

        let normalizedIDs = enabled.map { $0.productID.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard normalizedIDs.allSatisfy({ !$0.isEmpty }) else {
            validationMessage = "Every enabled plan needs a product identifier."
            return
        }
        guard Set(normalizedIDs).count == normalizedIDs.count else {
            validationMessage = "Enabled plans must use unique product identifiers."
            return
        }
        guard plans.allSatisfy({ $0.price >= 0 }) else {
            validationMessage = "Plan prices cannot be negative."
            return
        }
        guard plans.allSatisfy({ $0.introductoryOfferPrice >= 0 }) else {
            validationMessage = "Introductory-offer prices cannot be negative."
            return
        }

        let preferred = normalizedIDs.contains(preferredProductID)
            ? preferredProductID
            : normalizedIDs[0]
        let entitledIDs = Set(
            enabled.filter(\.unlocksEntitlement).map(\.productID)
        )
        let existing = purchaseManager.simulatedConfigurationSnapshot
        let configuration = PurchaseConfiguration(
            productIDs: normalizedIDs,
            entitledProductIDs: entitledIDs,
            preferredProductID: preferred,
            features: existing.features,
            productLoadAttempts: existing.productLoadAttempts
        )
        let products = plans.map(\.product)

        Task { @MainActor in
            await purchaseManager.configureSimulatedCatalog(
                configuration: configuration,
                products: products
            )
            dismiss()
        }
    }
}

struct DeveloperPlanDraft: Identifiable {
    let id: UUID
    var productID: String
    var displayName: String
    var productDescription: String
    var displayPrice: String
    var price: Double
    var period: DeveloperPlanPeriod
    var enabled: Bool
    var unlocksEntitlement: Bool
    var introductoryOfferMode: DeveloperIntroductoryOfferMode
    var introductoryOfferEligible: Bool
    var introductoryOfferPeriodValue: Int
    var introductoryOfferPeriodUnit: DeveloperIntroductoryOfferPeriodUnit
    var introductoryOfferPeriodCount: Int
    var introductoryOfferDisplayPrice: String
    var introductoryOfferPrice: Double

    init(
        id: UUID = UUID(),
        product: StoreProduct,
        enabled: Bool,
        unlocksEntitlement: Bool
    ) {
        let offer = product.introductoryOffer
        self.id = id
        self.productID = product.id
        self.displayName = product.displayName
        self.productDescription = product.description
        self.displayPrice = product.displayPrice
        self.price = product.price
        self.period = DeveloperPlanPeriod(product.subscriptionPeriod)
        self.enabled = enabled
        self.unlocksEntitlement = unlocksEntitlement
        self.introductoryOfferMode = DeveloperIntroductoryOfferMode(offer?.paymentMode)
        self.introductoryOfferEligible = offer?.isEligible ?? true
        self.introductoryOfferPeriodValue = max(1, offer?.period.value ?? 7)
        self.introductoryOfferPeriodUnit = DeveloperIntroductoryOfferPeriodUnit(
            offer?.period.unit ?? .day
        )
        self.introductoryOfferPeriodCount = max(1, offer?.periodCount ?? 1)
        self.introductoryOfferDisplayPrice = offer?.displayPrice ?? "$0.00"
        self.introductoryOfferPrice = max(0, offer?.price ?? 0)
    }

    private init(
        id: UUID = UUID(),
        productID: String,
        displayName: String,
        productDescription: String,
        displayPrice: String,
        price: Double,
        period: DeveloperPlanPeriod,
        enabled: Bool,
        unlocksEntitlement: Bool,
        introductoryOfferMode: DeveloperIntroductoryOfferMode = .none,
        introductoryOfferEligible: Bool = true,
        introductoryOfferPeriodValue: Int = 7,
        introductoryOfferPeriodUnit: DeveloperIntroductoryOfferPeriodUnit = .day,
        introductoryOfferPeriodCount: Int = 1,
        introductoryOfferDisplayPrice: String = "$0.00",
        introductoryOfferPrice: Double = 0
    ) {
        self.id = id
        self.productID = productID
        self.displayName = displayName
        self.productDescription = productDescription
        self.displayPrice = displayPrice
        self.price = price
        self.period = period
        self.enabled = enabled
        self.unlocksEntitlement = unlocksEntitlement
        self.introductoryOfferMode = introductoryOfferMode
        self.introductoryOfferEligible = introductoryOfferEligible
        self.introductoryOfferPeriodValue = max(1, introductoryOfferPeriodValue)
        self.introductoryOfferPeriodUnit = introductoryOfferPeriodUnit
        self.introductoryOfferPeriodCount = max(1, introductoryOfferPeriodCount)
        self.introductoryOfferDisplayPrice = introductoryOfferDisplayPrice
        self.introductoryOfferPrice = max(0, introductoryOfferPrice)
    }

    static func new(index: Int) -> DeveloperPlanDraft {
        DeveloperPlanDraft(
            productID: "com.example.app.pro.plan\(index)",
            displayName: "Pro Plan \(index)",
            productDescription: "Simulated premium access.",
            displayPrice: "$9.99",
            price: 9.99,
            period: .monthly,
            enabled: true,
            unlocksEntitlement: true
        )
    }

    var introductoryOfferSummary: String? {
        guard let offer = product.introductoryOffer else { return nil }
        return "\(offer.headline) · \(offer.isEligible ? "Eligible" : "Ineligible")"
    }

    var product: StoreProduct {
        StoreProduct(
            id: productID.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: productDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            displayPrice: displayPrice.trimmingCharacters(in: .whitespacesAndNewlines),
            price: max(0, price),
            subscriptionPeriod: period.subscriptionPeriod,
            introductoryOffer: introductoryOffer
        )
    }

    private var introductoryOffer: StoreProduct.IntroductoryOffer? {
        guard period != .lifetime,
              let paymentMode = introductoryOfferMode.paymentMode
        else { return nil }

        return StoreProduct.IntroductoryOffer(
            paymentMode: paymentMode,
            period: .init(
                value: max(1, introductoryOfferPeriodValue),
                unit: introductoryOfferPeriodUnit.storeUnit
            ),
            periodCount: max(1, introductoryOfferPeriodCount),
            displayPrice: introductoryOfferDisplayPrice.trimmingCharacters(in: .whitespacesAndNewlines),
            price: max(0, introductoryOfferPrice),
            isEligible: introductoryOfferEligible
        )
    }
}

@MainActor
private struct DeveloperPlanDetailView: View {
    @Binding var plan: DeveloperPlanDraft

    var body: some View {
        Form {
            Section("Availability") {
                Toggle("Enabled", isOn: $plan.enabled)
                Toggle("Unlocks Pro", isOn: $plan.unlocksEntitlement)
                    .disabled(!plan.enabled)
            }

            Section("Product") {
                TextField("Product identifier", text: $plan.productID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Display name", text: $plan.displayName)
                TextField("Description", text: $plan.productDescription, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Pricing") {
                TextField("Displayed price", text: $plan.displayPrice)
                TextField("Numeric price", value: $plan.price, format: .number)
                    .keyboardType(.decimalPad)
                Picker("Billing period", selection: $plan.period) {
                    ForEach(DeveloperPlanPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
            }

            if plan.period != .lifetime {
                Section {
                    Picker("Offer", selection: $plan.introductoryOfferMode) {
                        ForEach(DeveloperIntroductoryOfferMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if plan.introductoryOfferMode != .none {
                        Toggle("Eligible", isOn: $plan.introductoryOfferEligible)

                        Stepper(
                            "Period length: \(plan.introductoryOfferPeriodValue)",
                            value: $plan.introductoryOfferPeriodValue,
                            in: 1...365
                        )

                        Picker("Period unit", selection: $plan.introductoryOfferPeriodUnit) {
                            ForEach(DeveloperIntroductoryOfferPeriodUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        }

                        Stepper(
                            "Number of periods: \(plan.introductoryOfferPeriodCount)",
                            value: $plan.introductoryOfferPeriodCount,
                            in: 1...52
                        )

                        if plan.introductoryOfferMode == .freeTrial {
                            LabeledContent("Offer price", value: "Free")
                        } else {
                            TextField(
                                "Displayed offer price",
                                text: $plan.introductoryOfferDisplayPrice
                            )
                            TextField(
                                "Numeric offer price",
                                value: $plan.introductoryOfferPrice,
                                format: .number
                            )
                            .keyboardType(.decimalPad)
                        }
                    }
                } header: {
                    Text("Introductory Offer")
                } footer: {
                    Text("Eligibility controls whether trial or introductory-offer copy appears in ProPaywallView. These settings affect the in-process simulator only.")
                }
            }
        }
        .navigationTitle(plan.displayName.isEmpty ? "Plan" : plan.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum DeveloperPlanPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly
    case lifetime

    var id: String { rawValue }

    init(_ period: StoreProduct.SubscriptionPeriod?) {
        guard let period else {
            self = .lifetime
            return
        }
        switch period.unit {
        case .day: self = .daily
        case .week: self = .weekly
        case .month: self = .monthly
        case .year: self = .yearly
        case .unknown: self = .monthly
        }
    }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .lifetime: "Lifetime"
        }
    }

    var subscriptionPeriod: StoreProduct.SubscriptionPeriod? {
        switch self {
        case .daily: .init(value: 1, unit: .day)
        case .weekly: .init(value: 1, unit: .week)
        case .monthly: .init(value: 1, unit: .month)
        case .yearly: .init(value: 1, unit: .year)
        case .lifetime: nil
        }
    }
}

enum DeveloperIntroductoryOfferMode: String, CaseIterable, Identifiable {
    case none
    case freeTrial
    case payAsYouGo
    case payUpFront
    case unknown

    var id: String { rawValue }

    init(_ mode: StoreProduct.IntroductoryOffer.PaymentMode?) {
        switch mode {
        case .freeTrial: self = .freeTrial
        case .payAsYouGo: self = .payAsYouGo
        case .payUpFront: self = .payUpFront
        case .unknown: self = .unknown
        case nil: self = .none
        }
    }

    var title: String {
        switch self {
        case .none: "None"
        case .freeTrial: "Free Trial"
        case .payAsYouGo: "Pay As You Go"
        case .payUpFront: "Pay Up Front"
        case .unknown: "Unknown"
        }
    }

    var paymentMode: StoreProduct.IntroductoryOffer.PaymentMode? {
        switch self {
        case .none: nil
        case .freeTrial: .freeTrial
        case .payAsYouGo: .payAsYouGo
        case .payUpFront: .payUpFront
        case .unknown: .unknown
        }
    }
}

enum DeveloperIntroductoryOfferPeriodUnit: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year
    case unknown

    var id: String { rawValue }

    init(_ unit: StoreProduct.SubscriptionPeriod.Unit) {
        switch unit {
        case .day: self = .day
        case .week: self = .week
        case .month: self = .month
        case .year: self = .year
        case .unknown: self = .unknown
        }
    }

    var title: String {
        switch self {
        case .day: "Days"
        case .week: "Weeks"
        case .month: "Months"
        case .year: "Years"
        case .unknown: "Unknown"
        }
    }

    var storeUnit: StoreProduct.SubscriptionPeriod.Unit {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        case .unknown: .unknown
        }
    }
}

private enum DeveloperPurchaseOutcome: String, CaseIterable, Identifiable {
    case success
    case pending
    case userCancelled
    case networkFailure
    case productUnavailable
    case systemFailure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .success: "Success"
        case .pending: "Pending"
        case .userCancelled: "User Cancelled"
        case .networkFailure: "Network Failure"
        case .productUnavailable: "Product Unavailable"
        case .systemFailure: "System Failure"
        }
    }

    var failure: PurchaseFailure? {
        switch self {
        case .networkFailure:
            PurchaseFailure(
                code: .networkUnavailable,
                message: "Simulated network failure."
            )
        case .productUnavailable:
            .productUnavailable
        case .systemFailure:
            PurchaseFailure(
                code: .system,
                message: "Simulated App Store system failure."
            )
        case .success, .pending, .userCancelled:
            nil
        }
    }

    var result: SimulatedPurchaseResult {
        switch self {
        case .success: .success
        case .pending: .pending
        case .userCancelled: .userCancelled
        case .networkFailure, .productUnavailable, .systemFailure:
            .failure(failure ?? .unknown)
        }
    }
}

private enum DeveloperPurchaseLatency: String, CaseIterable, Identifiable {
    case instant
    case normal
    case oneSecond
    case threeSeconds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instant: "Instant"
        case .normal: "250 ms"
        case .oneSecond: "1 second"
        case .threeSeconds: "3 seconds"
        }
    }

    var duration: Duration {
        switch self {
        case .instant: .milliseconds(0)
        case .normal: .milliseconds(250)
        case .oneSecond: .seconds(1)
        case .threeSeconds: .seconds(3)
        }
    }
}
#endif
