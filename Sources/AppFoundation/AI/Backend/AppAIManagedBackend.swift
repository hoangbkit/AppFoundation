import Foundation

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
}
