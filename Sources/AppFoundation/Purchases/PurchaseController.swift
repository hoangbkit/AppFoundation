#if canImport(Observation) && canImport(StoreKit)
import Foundation
import Observation
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
    @ObservationIgnored private let simulatedProducts: [StoreProduct]
    @ObservationIgnored private let simulatedPersistenceKey: String?
    @ObservationIgnored private let simulatedOperationDelay: Duration
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    @ObservationIgnored private var hasPrepared = false

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
        self.simulatedProducts = []
        self.simulatedPersistenceKey = nil
        self.simulatedOperationDelay = .milliseconds(250)
        self.service = service
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

    public var preferredProduct: StoreProduct? {
        if let preferredProductID = configuration.preferredProductID,
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
        let records = await service.currentEntitlements()
        entitlementState = EntitlementEvaluator.evaluate(
            records,
            entitledProductIDs: configuration.entitledProductIDs
        )
    }

    public func purchase(_ product: StoreProduct) async {
        guard !isBusy else {
            return
        }

        guard configuration.productIDs.contains(product.id) else {
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

    @discardableResult
    public func restorePurchases() async -> RestoreOutcome {
        guard !isBusy else {
            return isEntitled ? .restored : .nothingToRestore
        }

        activity = .restoring

        do {
            try await service.sync()
            await refreshEntitlements()
            activity = .idle
            return isEntitled ? .restored : .nothingToRestore
        } catch {
            let failure = Self.mapFailure(error)
            activity = .failed(failure)
            return .failed(failure)
        }
    }

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
        hasPrepared = false
        products = []
        productLoadingState = .idle
        entitlementState = .checking
        activity = .idle

        await prepare()
    }

    /// Clears simulator state and refreshes the observable entitlement state.
    public func resetSimulatedPurchases() async {
        guard let simulatedService = service as? SimulatedPurchaseService else {
            return
        }

        simulatedService.reset()
        activity = .idle
        await refreshEntitlements()
    }
    #endif

    private func startObservingTransactions() {
        updateTask?.cancel()
        updateTask = Task { [weak self, service] in
            for await _ in service.entitlementUpdates() {
                guard !Task.isCancelled else {
                    return
                }
                await self?.refreshEntitlements()
                self?.activity = .idle
            }
        }
    }

    private static func mapFailure(_ error: Error) -> PurchaseFailure {
        if let failure = error as? PurchaseFailure {
            return failure
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
                return PurchaseFailure(
                    code: .unknown,
                    message: "The purchase was cancelled."
                )
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