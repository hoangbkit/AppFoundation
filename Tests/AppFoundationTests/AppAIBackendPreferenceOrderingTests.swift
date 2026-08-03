import Foundation
import Testing
@testable import AppFoundation

private actor ControlledBackendPreferences: AppAIBackendPreferences {
    private var backend: AppAIBackendID?
    private var models: [AppAIProviderID: String] = [:]
    private var writeCount = 0
    private var completedWriteCount = 0

    private var firstWriteStarted = false
    private var firstWriteReleased = false
    private var firstWriteRelease: CheckedContinuation<Void, Never>?
    private var firstWriteStartWaiters: [
        CheckedContinuation<Void, Never>
    ] = []
    private var completionWaiters: [
        Int: [CheckedContinuation<Void, Never>]
    ] = [:]

    func selectedBackend() async -> AppAIBackendID? {
        backend
    }

    func setSelectedBackend(_ backend: AppAIBackendID) async {
        writeCount += 1
        let currentWrite = writeCount

        if currentWrite == 1 {
            firstWriteStarted = true
            for waiter in firstWriteStartWaiters {
                waiter.resume()
            }
            firstWriteStartWaiters.removeAll()

            if !firstWriteReleased {
                await withCheckedContinuation { continuation in
                    if firstWriteReleased {
                        continuation.resume()
                    } else {
                        firstWriteRelease = continuation
                    }
                }
            }
        }

        self.backend = backend
        completedWriteCount += 1
        if let waiters = completionWaiters.removeValue(
            forKey: completedWriteCount
        ) {
            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func model(for provider: AppAIProviderID) async -> String? {
        models[provider]
    }

    func setModel(
        _ model: String?,
        for provider: AppAIProviderID
    ) async {
        if let model {
            models[provider] = model
        } else {
            models.removeValue(forKey: provider)
        }
    }

    func waitForFirstWriteToStart() async {
        if firstWriteStarted { return }
        await withCheckedContinuation { continuation in
            firstWriteStartWaiters.append(continuation)
        }
    }

    func releaseFirstWrite() {
        firstWriteReleased = true
        firstWriteRelease?.resume()
        firstWriteRelease = nil
    }

    func waitForCompletedWrites(_ expected: Int) async {
        if completedWriteCount >= expected { return }
        await withCheckedContinuation { continuation in
            completionWaiters[expected, default: []].append(continuation)
        }
    }
}

@Test @MainActor
func backendPreferenceWritesPreserveInvocationOrder() async {
    let preferences = ControlledBackendPreferences()
    let manager = AppAIBackendManager(
        catalog: AppAIBackendCatalog(
            backends: [
                .managed(title: "Managed AI"),
                .openAI(preferredModel: "model-a"),
            ]
        ),
        clients: [],
        credentialStore: AppAIInMemoryCredentialStore(),
        preferences: preferences
    )

    manager.select(.managed)
    await preferences.waitForFirstWriteToStart()

    let secondWrite = Task { @MainActor in
        await manager.selectAndWait(.direct(.openAI))
    }

    await Task.yield()
    await preferences.releaseFirstWrite()
    await secondWrite.value
    await preferences.waitForCompletedWrites(2)

    #expect(
        await preferences.selectedBackend()
            == .direct(.openAI)
    )
}
