import Foundation
#if canImport(StoreKit)
import StoreKit
#endif

@MainActor
public struct AppAIManagedBackend {
    public let descriptor: AppAIBackendDescriptor
    public let client: AppAIClient
    public let statusStore: AppAIStatusStore?

    public init(
        descriptor: AppAIBackendDescriptor,
        client: AppAIClient,
        statusStore: AppAIStatusStore? = nil
    ) {
        precondition(
            descriptor.id == .managed,
            "AppAIManagedBackend requires a managed backend descriptor."
        )
        self.descriptor = descriptor
        self.client = client
        self.statusStore = statusStore
    }

    public init(
        descriptor: AppAIBackendDescriptor,
        configuration: AppAIClientConfiguration,
        transport: any AppAITransport = URLSessionAppAITransport(),
        attestationProvider: (any AppAIAttestationProviding)? = nil
    ) {
        let client = AppAIClient(
            configuration: configuration,
            transport: transport,
            attestationProvider: attestationProvider
        )

        #if canImport(StoreKit)
        let statusStore = AppAIStatusStore(client: client)
        #else
        let statusStore: AppAIStatusStore? = nil
        #endif

        self.init(
            descriptor: descriptor,
            client: client,
            statusStore: statusStore
        )
    }
}
