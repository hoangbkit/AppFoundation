#if canImport(Observation) && canImport(StoreKit)
import Foundation
import Observation
import OSLog
import StoreKit

@MainActor
@Observable
public final class PurchaseController {
    public private(set) var products: [StoreProduct] = []
    public private(set) var productLoadingState: ProductLoadingState = .idle
    public private(set) var entitlementState: EntitlementState = .checking
    public private(set) var activity: PurchaseActivity = .idle

    public let configuration: PurchaseConfiguration

    @ObservationIgnored private var service: any PurchaseServing
    @ObservationIgnored private var simulatedConfiguration: PurchaseConfiguration
    @ObservationIgnored private var simulatedProducts: [StoreProduct]
    @ObservationIgnored private let simulatedPersistenceKey: String?
    @ObservationIgnored private var simulatedOperationDelay: Duration
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    @ObservationIgnored private var restoreTask: Task<RestoreOutcome, Never>?
    @ObservationIgnored private var restoreGeneration = 0
    @ObservationIgnored private var hasPrepared = false

    @ObservationIgnored private static let logger = Logger(
        subsystem: "com.appfoundation.purchases",
        category: "restore"
    )

    /// Creates a purchase controller backed by live StoreKit by default.
    ///
    /// Set `simulated` to `true` in a Debug build to use AppFoundation's
    /// in-process simulator. Release builds always fall back to live StoreKit.
    public init(
        configuration: PurchaseConfiguration,
        simulated: Bool = false,
        simulatedProducts: [StoreProduct] = [],
        simulatedPersistenceKey: String? = nil,
        simulatedOperationDelay: Duration = .milliseconds(250)
    ) {
        self.configuration = configuration
        self.simulatedConfiguration = configuration
        self.simulatedProducts = simulatedProducts
        self.simulatedPersistenceKey = simulatedPersistenceKey
        self.simulatedOperationDelay = simulatedOperationDelay
        self.service = PurchaseServiceFactory.make(
            mode: simulated ? .simulated : .live,
            simulatedProducts: simulatedProducts,
            simulatedPersistenceKey: simulatedPersistenceKey,
            simulatedOperationDelay: simulatedOperationDelay
        )
    }

    public init(
        configuration: PurchaseConfiguration,
        service: any PurchaseServing
    ) {
        self.configuration = configuration
        self.simulatedConfiguration = configuration
        self.simulatedProducts = []
        self.simulatedPersistenceKey = nil
        self.simulatedOperationDelay = .milliseconds(250)
        self.service = service
    }

    /// Creates a deterministic purchase controller for Screenshot Studio and SwiftUI previews.
    ///
    /// The supplied products are ordered and exposed synchronously so an `ImageRenderer`
    /// can render the app's real paywall without waiting for StoreKit or an asynchronous task.
    /// The returned controller starts with an inactive entitlement and should only be used for
    /// non-interactive previews and screenshot generation.
    public static func screenshotPreview(
        configuration: PurchaseConfiguration,
        products: [StoreProduct]
    ) -> PurchaseController {
        let controller = PurchaseController(
            configuration: configuration,
            simulated: true,
            simulatedProducts: products,
            simulatedOperationDelay: .milliseconds(0)
        )
        let orderedProducts = ProductCatalog.ordered(
            products,
            using: configuration.productIDs
        )
        controller.products = orderedProducts
        controller.productLoadingState = orderedProducts.isEmpty
            ? .failed(.noProductsAvailable)
            : .loaded
        controller.entitlementState = .inactive
        return controller
    }

    deinit {
        updateTask?.cancel()
    }

    public var isEntitled: Bool {
        entitlementState.isActive
    }

    public var isBusy: Bool {
        activity.isBusy
    }

    /// True while a StoreKit purchase flow is in flight (a purchase sheet could be up).
    public var isPurchasing: Bool {
        if case .purchasing = activity {
            return true
        }
        return false
    }

    /// True while an App Store restore sync is in flight.
    public var isRestoring: Bool {
        if case .restoring = activity {
            return true
        }
        return false
    }

    public var preferredProduct: StoreProduct? {
        if let preferredProductID = activeConfiguration.preferredProductID,
            let preferredProduct = products.first(where: { $0.id == preferredProductID })
        {
            return preferredProduct
        }
        return products.first
    }

    #if DEBUG
    /// Whether this controller is currently backed by the in-process purchase simulator.
    public var isUsingSimulatedPurchases: Bool {
        service is SimulatedPurchaseService
    }

    /// The configuration currently used by the Debug simulator.
    public var simulatedConfigurationSnapshot: PurchaseConfiguration {
        simulatedConfiguration
    }

    /// All products retained for the Debug simulator, including products disabled by its configuration.
    public var simulatedCatalogProducts: [StoreProduct] {
        simulatedProducts
    }

    /// The currently active simulated entitlement product identifiers.
    public var simulatedPurchasedProductIDs: Set<String> {
        (service as? SimulatedPurchaseService)?.purchasedProductIDs ?? []
    }

    /// Artificial latency applied to simulated StoreKit operations.
    public var simulatedPurchaseOperationDelay: Duration {
        simulatedOperationDelay
    }
    #endif

    public func product(withID productID: String) -> StoreProduct? {
        products.first(where: { $0.id == productID })
    }

    /// Starts transaction observation, verifies entitlements, and loads the product catalog.
    /// Calling this method repeatedly is safe.
    public func prepare() async {
        if !hasPrepared {
            hasPrepared = true
            startObservingTransactions()
        }

        await refreshEntitlements()
        await loadProducts()
    }

    public func loadProducts(force: Bool = false) async {
        if !force, productLoadingState == .loaded || productLoadingState == .loading {
            return
        }

        let configuration = activeConfiguration
        guard !configuration.productIDs.isEmpty else {
            products = []
            productLoadingState = .failed(.noProductsAvailable)
            return
        }

        productLoadingState = .loading
        var lastFailure = PurchaseFailure.noProductsAvailable

        for attempt in 1...configuration.productLoadAttempts {
            do {
                let loadedProducts = try await service.products(for: configuration.productIDs)
                let orderedProducts = ProductCatalog.ordered(
                    loadedProducts,
                    using: configuration.productIDs
                )

                guard !orderedProducts.isEmpty else {
                    throw PurchaseFailure.noProductsAvailable
                }

                products = orderedProducts
                productLoadingState = .loaded
                return
            } catch {
                lastFailure = Self.mapFailure(error)
                guard attempt < configuration.productLoadAttempts else {
                    break
                }

                let delay = UInt64(attempt) * 350_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
        }

        productLoadingState = .failed(lastFailure)
    }

    public func refreshEntitlements() async {
        _ = await refreshEntitlementsWithRecords()
    }

    @discardableResult
    private func refreshEntitlementsWithRecords() async -> [EntitlementRecord] {
        let records = await service.currentEntitlements()
        entitlementState = EntitlementEvaluator.evaluate(
            records,
            entitledProductIDs: activeConfiguration.entitledProductIDs
        )
        return records
    }

    public func purchase(_ product: StoreProduct) async {
        guard !isBusy else {
            return
        }

        guard activeConfiguration.productIDs.contains(product.id) else {
            activity = .failed(.productUnavailable)
            return
        }

        activity = .purchasing(productID: product.id)

        do {
            let outcome = try await service.purchase(productID: product.id)
            switch outcome {
            case .success:
                await refreshEntitlements()
                activity = .idle
            case .pending:
                activity = .pending(productID: product.id)
            case .userCancelled:
                activity = .idle
            }
        } catch {
            activity = .failed(Self.mapFailure(error))
        }
    }

    /// Restores purchases by syncing with the App Store and re-evaluating entitlements.
    ///
    /// Concurrent calls coalesce into the in-flight attempt and receive its outcome.
    /// Pass a `timeout` to stop waiting when the App Store never answers; the abandoned
    /// sync may still finish later, but its late result is discarded. Cancellation via
    /// `cancelRestore()` behaves the same way — the wait ends immediately for UI
    /// purposes while a stuck request drains in the background.
    @discardableResult
    public func restorePurchases(timeout: Duration? = nil) async -> RestoreOutcome {
        if let restoreTask {
            return await restoreTask.value
        }

        restoreGeneration += 1
        let generation = restoreGeneration
        activity = .restoring

        let task = Task { [weak self] () -> RestoreOutcome in
            guard let self else { return .nothingToRestore }
            return await self.performRestore(timeout: timeout, generation: generation)
        }
        restoreTask = task

        defer {
            if restoreGeneration == generation {
                restoreTask = nil
            }
        }
        return await task.value
    }

    /// Stops waiting on the in-flight restore, if any, and resets `activity` to idle.
    ///
    /// A request that ignores cancellation (for example an App Store sync that never
    /// answers) keeps draining in the background; its eventual outcome is discarded.
    public func cancelRestore() {
        guard restoreTask != nil || isBusy else { return }

        restoreGeneration += 1
        restoreTask?.cancel()
        restoreTask = nil
        activity = .idle
    }

    private func performRestore(timeout: Duration?, generation: Int) async -> RestoreOutcome {
        do {
            try await runSyncOperation(timeout: timeout)
            guard restoreGeneration == generation else {
                return .failed(.userCancelled)
            }

            let records = await refreshEntitlementsWithRecords()
            #if DEBUG
            Self.logRestoreDiagnostics(
                records,
                entitledProductIDs: activeConfiguration.entitledProductIDs
            )
            #endif
            guard restoreGeneration == generation else {
                return .failed(.userCancelled)
            }

            activity = .idle
            return isEntitled ? .restored : .nothingToRestore
        } catch {
            guard restoreGeneration == generation else {
                return .failed(.userCancelled)
            }

            let failure = Self.mapFailure(error)
            // A user-initiated cancellation ends silently instead of surfacing as
            // a failure state that other surfaces might replay.
            activity = failure.code == .userCancelled ? .idle : .failed(failure)
            return .failed(failure)
        }
    }

    /// Runs the StoreKit sync, racing it against `timeout`.
    ///
    /// The timeout does not rely on `sync()` honoring cancellation: whichever side
    /// settles first wins, and a slow sync is simply abandoned.
    private func runSyncOperation(timeout: Duration?) async throws {
        guard let timeout else {
            try await service.sync()
            return
        }

        let gate = RestoreGate()
        return try await withCheckedThrowingContinuation { continuation in
            gate.activate(continuation)

            // Abandoned intentionally on timeout; the gate discards its late result.
            Task { [service, gate] in
                do {
                    try await service.sync()
                    gate.resumeReturning()
                } catch {
                    gate.resumeThrowing(error)
                }
            }

            let timeoutTask = Task { [gate] in
                try? await Task.sleep(for: timeout)
                gate.resumeThrowing(PurchaseFailure.timeout)
            }
            gate.attachTimeoutTask(timeoutTask)
        }
    }

    /// Resume-once gate shared by the sync task and the timeout task.
    ///
    /// Both sides run on the main actor, so plain fields are safe; the flag only
    /// guards against double resumption.
    @MainActor
    private final class RestoreGate {
        private var continuation: CheckedContinuation<Void, Error>?
        private var timeoutTask: Task<Void, Never>?
        private var didFinish = false

        func activate(_ continuation: CheckedContinuation<Void, Error>) {
            self.continuation = continuation
        }

        func attachTimeoutTask(_ task: Task<Void, Never>) {
            guard !didFinish else {
                task.cancel()
                return
            }
            timeoutTask = task
        }

        func resumeReturning() {
            finish { $0.resume(returning: ()) }
        }

        func resumeThrowing(_ error: Error) {
            finish { $0.resume(throwing: error) }
        }

        private func finish(_ resume: (CheckedContinuation<Void, Error>) -> Void) {
            guard !didFinish, let continuation else { return }
            didFinish = true
            self.continuation = nil
            timeoutTask?.cancel()
            timeoutTask = nil
            resume(continuation)
        }
    }

    #if DEBUG
    /// Surfaces configuration mistakes that would otherwise reach users as a
    /// plain "no previous purchases were found" result.
    private static func logRestoreDiagnostics(
        _ records: [EntitlementRecord],
        entitledProductIDs: Set<String>
    ) {
        let returnedProductIDs = Set(records.map(\.productID))
        let matchedIDs = returnedProductIDs.intersection(entitledProductIDs)

        if matchedIDs.isEmpty {
            let returnedList = returnedProductIDs.sorted().joined(separator: ", ")
            let configuredList = entitledProductIDs.sorted().joined(separator: ", ")
            logger.fault("""
            Restore found transactions for [\(returnedList, privacy: .public)] but none match \
            the configured entitlement products [\(configuredList, privacy: .public)]; users will \
            see "No previous purchases were found." Check PurchaseConfiguration.productIDs.
            """)
        } else if matchedIDs.count < returnedProductIDs.count {
            let unmatchedList = returnedProductIDs
                .subtracting(entitledProductIDs)
                .sorted()
                .joined(separator: ", ")
            logger.notice("""
            Restore matched \(matchedIDs.count) of \(returnedProductIDs.count) transaction(s), \
            ignoring [\(unmatchedList, privacy: .public)].
            """)
        }
    }
    #endif

    public func clearActivity() {
        activity = .idle
    }

    #if DEBUG
    /// Switches this controller between live StoreKit and the in-process simulator.
    /// The configured simulator products, persistence key, and delay are reused.
    public func setSimulatedPurchasesEnabled(_ enabled: Bool) async {
        guard isUsingSimulatedPurchases != enabled else {
            return
        }

        updateTask?.cancel()
        updateTask = nil
        service = PurchaseServiceFactory.make(
            mode: enabled ? .simulated : .live,
            simulatedProducts: simulatedProducts,
            simulatedPersistenceKey: simulatedPersistenceKey,
            simulatedOperationDelay: simulatedOperationDelay
        )
        resetObservableStateForServiceChange()
        await prepare()
    }

    /// Replaces the Debug simulator's catalog without changing the live StoreKit configuration.
    ///
    /// Disabled products may remain in `products`; only `configuration.productIDs` are loaded by
    /// simulated paywalls. If the simulator is active, its current entitlement is preserved when
    /// that product still exists in the replacement catalog.
    public func configureSimulatedCatalog(
        configuration: PurchaseConfiguration,
        products: [StoreProduct]
    ) async {
        let purchasedProductIDs = simulatedPurchasedProductIDs
        simulatedConfiguration = configuration
        simulatedProducts = products

        guard isUsingSimulatedPurchases else {
            return
        }

        updateTask?.cancel()
        updateTask = nil
        service = SimulatedPurchaseService(
            products: products,
            initiallyPurchasedProductIDs: purchasedProductIDs,
            persistenceKey: simulatedPersistenceKey,
            operationDelay: simulatedOperationDelay
        )
        resetObservableStateForServiceChange()
        await prepare()
    }

    /// Sets the simulated outcome for a product's future purchase attempts.
    public func setSimulatedPurchaseResult(
        _ result: SimulatedPurchaseResult,
        for productID: String
    ) {
        (service as? SimulatedPurchaseService)?.setPurchaseResult(result, for: productID)
    }

    /// Sets the simulated entitlement directly and refreshes observable entitlement state.
    public func setSimulatedPurchasedProductIDs(_ productIDs: Set<String>) async {
        guard let simulatedService = service as? SimulatedPurchaseService else {
            return
        }
        simulatedService.setPurchasedProductIDs(productIDs)
        activity = .idle
        await refreshEntitlements()
    }

    /// Injects or clears product-catalog loading failure and immediately reloads the catalog.
    public func setSimulatedProductLoadingFailure(_ failure: PurchaseFailure?) async {
        guard let simulatedService = service as? SimulatedPurchaseService else {
            return
        }
        simulatedService.setProductLoadingFailure(failure)
        await loadProducts(force: true)
    }

    /// Injects or clears restore failure for future simulated restore attempts.
    public func setSimulatedRestoreFailure(_ failure: PurchaseFailure?) {
        (service as? SimulatedPurchaseService)?.setSyncFailure(failure)
    }

    /// Updates artificial latency for subsequent simulated StoreKit operations.
    public func setSimulatedOperationDelay(_ delay: Duration) {
        simulatedOperationDelay = delay
        (service as? SimulatedPurchaseService)?.setOperationDelay(delay)
    }

    /// Clears purchase, catalog, and restore failure injection while keeping entitlement state.
    public func resetSimulatedFailures() async {
        guard let simulatedService = service as? SimulatedPurchaseService else {
            return
        }
        simulatedService.resetFailures()
        activity = .idle
        await loadProducts(force: true)
    }

    /// Clears simulator state and refreshes the observable entitlement and product state.
    public func resetSimulatedPurchases() async {
        guard let simulatedService = service as? SimulatedPurchaseService else {
            return
        }

        simulatedService.reset()
        activity = .idle
        await refreshEntitlements()
        await loadProducts(force: true)
    }
    #endif

    private var activeConfiguration: PurchaseConfiguration {
        #if DEBUG
        if service is SimulatedPurchaseService {
            return simulatedConfiguration
        }
        #endif
        return configuration
    }

    private func resetObservableStateForServiceChange() {
        hasPrepared = false
        products = []
        productLoadingState = .idle
        entitlementState = .checking
        activity = .idle
    }

    private func startObservingTransactions() {
        updateTask?.cancel()
        updateTask = Task { [weak self, service] in
            for await _ in service.entitlementUpdates() {
                guard !Task.isCancelled else {
                    return
                }
                guard let self else {
                    return
                }
                await self.refreshEntitlements()
                // Only retire ask-to-buy style pending state; in-flight purchase and
                // restore flows own their own activity transitions.
                if case .pending = self.activity {
                    self.activity = .idle
                }
            }
        }
    }

    private static func mapFailure(_ error: Error) -> PurchaseFailure {
        if let failure = error as? PurchaseFailure {
            return failure
        }

        if error is CancellationError {
            return .userCancelled
        }

        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .networkError:
                return PurchaseFailure(
                    code: .networkUnavailable,
                    message: "Check your internet connection and try again."
                )
            case .notAvailableInStorefront:
                return PurchaseFailure(
                    code: .storefrontUnavailable,
                    message: "This purchase is not available in your App Store region."
                )
            case .notEntitled:
                return PurchaseFailure(
                    code: .notEntitled,
                    message: "This Apple ID is not entitled to the purchase."
                )
            case .unsupported:
                return PurchaseFailure(
                    code: .system,
                    message: "This purchase is not supported on this device."
                )
            case .systemError:
                return PurchaseFailure(
                    code: .system,
                    message: "The App Store could not complete the request. Please try again."
                )
            case .userCancelled:
                return .userCancelled
            case .unknown:
                return .unknown
            @unknown default:
                return .unknown
            }
        }

        if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .productUnavailable:
                return .productUnavailable
            case .purchaseNotAllowed:
                return PurchaseFailure(
                    code: .purchaseNotAllowed,
                    message: "Purchases are restricted on this device."
                )
            case .ineligibleForOffer:
                return PurchaseFailure(
                    code: .productUnavailable,
                    message: "This offer is not available for this Apple ID."
                )
            case .invalidOfferIdentifier,
                .invalidOfferPrice,
                .invalidOfferSignature,
                .invalidQuantity,
                .missingOfferParameters:
                return PurchaseFailure(
                    code: .productUnavailable,
                    message: "The selected offer could not be applied."
                )
            @unknown default:
                return .unknown
            }
        }

        return .unknown
    }
}
#endif