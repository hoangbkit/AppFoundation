# AppAIClient

`AppAIClient` is the provider-neutral client for `ai-proxy-server`. Apps submit typed capabilities and never choose a provider, model, system prompt, reasoning mode, or token limit.

## Setup

```swift
import AppFoundation

let aiClient = AppAIClient(
    configuration: AppAIClientConfiguration(
        appID: "draftx",
        appKey: AppSecrets.aiProxyKey,
        baseURL: URL(string: "https://ai.example.com")!,
        attestationPolicy: .preferred
    )
)
```

Each app uses a different app ID and app key. The client creates an installation ID once and stores it in the Keychain with `AfterFirstUnlockThisDeviceOnly` accessibility.

The App Attest key identifier is intentionally stored in app-local preferences rather than Keychain. The identifier is not secret; Apple retains the private key. App Attest proves that requests come from a valid app instance on supported Apple hardware, while the Keychain installation ID remains the server-side quota identity. Removing the app removes the local App Attest identifier, so a reinstall naturally creates and registers a fresh App Attest key.

This storage choice is deliberate. Apple generally recommends retaining key identifiers in Keychain, but that can preserve an unusable identifier across uninstall and reinstall. AppFoundation instead optimizes for automatic reinstall recovery and retains a bounded runtime fallback for restored or stale identifiers.

## Generate

```swift
struct RewriteInput: Codable, Sendable {
    let text: String
    let tone: String
}

struct RewriteOutput: Codable, Sendable {
    let text: String
}

let response: AppAIResponse<RewriteOutput> = try await aiClient.generate(
    capability: "rewrite.polish",
    input: RewriteInput(text: draft, tone: "confident")
)

let polishedText = response.data.text
```

The client owns:

- Stable request IDs and deterministic request bodies
- App and installation headers
- Typed response and stable server-error decoding
- Process-wide coordination of installation identity creation
- App Attest registration and request-bound assertion headers
- Process-wide serialization of attested protected requests
- Fresh one-time assertions for transport and rejected-assertion retries
- Automatic creation of a fresh App Attest key after reinstall
- One-time rotation of a cached key when Apple reports `invalidKey` or the observed stale-state `invalidInput`
- Re-registration when the app server no longer recognizes a local key
- Cancellation propagation without hidden retries

## Prepare attestation before the first paid or AI action

Registration can contact both the app server and Apple. An app can warm it during a suitable background or low-friction moment:

```swift
Task {
    try? await aiClient.prepareAttestation()
}
```

`prepareAttestation()` creates and registers a key but does not generate an assertion or consume AI quota. Do not block app launch on it. For a large installed base, roll out attestation gradually rather than causing every upgraded installation to attest simultaneously.

Under `.preferred`, preparation failures are nonblocking and a later protected request tries again. Under `.required`, the error is returned to the caller.

## Attestation policies

### Disabled

```swift
attestationPolicy: .disabled
```

No App Attest work is attempted. Use only when the matching app-server policy disables attestation.

### Preferred

```swift
attestationPolicy: .preferred
```

The client uses App Attest when supported. Unsupported clients or temporary attestation failures proceed without assertion headers; the server decides whether to accept them and applies the configured restricted quota.

### Required

```swift
attestationPolicy: .required
```

The client fails locally when App Attest is unsupported or assertion creation fails. The server also rejects requests without a valid assertion.

For low-cost free credits, `.preferred` is normally the safer product policy. A verified StoreKit entitlement should remain the source of paid access rather than a transient App Attest result.

## Reinstall, upgrade, and restore

The installation ID and App Attest key have separate lifecycles:

1. The installation ID remains in Keychain and continues to identify the quota record when iOS preserves Keychain data.
2. The App Attest key identifier lives in app-local preferences and normally disappears with an uninstall.
3. A reinstall therefore generates, attests, and registers a new App Attest key automatically.
4. An app update from an older AppFoundation build migrates its valid legacy Keychain identifier into app-local preferences without generating another key.
5. If that migrated identifier actually came from a previous installation or a restored backup, `generateAssertion` can report `invalidKey` or `invalidInput`. AppFoundation removes it, registers one fresh key, and retries the logical request once.
6. A failure from the fresh key is surfaced; rotation never loops.

The app server may associate more than one valid App Attest key with the same installation. Key rotation is not treated as a new device or quota identity, and previous keys are not immediately invalidated merely because a new valid key appears.

## Registration failure behavior

A pending registration stores the generated key identifier and the exact one-time server challenge in app-local preferences.

- `serverUnavailable` from Apple preserves that pending registration. The next attempt uses the same key and the same `clientDataHash`, as Apple requires.
- Any other `attestKey` error discards the pending key.
- If the one-time app-server challenge expires before a retry, AppFoundation discards that attempt and begins a fresh registration instead of reusing the same key with different client data.
- After Apple successfully attests a key, AppFoundation remembers it before sending the registration object to the app server. If the network response is lost, the next assertion determines whether the server committed registration. A definite server rejection discards the key.

Apps should retry later with backoff after temporary preparation failures. AppFoundation preserves the required inputs but does not run an uncontrolled background retry loop.

## Assertion ordering and retries

App Attest assertions contain a strictly increasing counter. Two concurrent requests using the same key can arrive at the server out of order and cause a valid request to appear stale. AppFoundation therefore serializes the complete protected request lifecycle process-wide for each `(keychainService, appID)` pair.

This favors correctness over parallel AI throughput. Do not remove this gate unless the server protocol is redesigned to commit assertions separately from long-running generation.

For a transport retry, AppFoundation:

1. Retains the same logical `requestID` and exact encoded request body.
2. Fetches a new one-time challenge and generates a new assertion.
3. Retries within the configured transport retry limit.
4. Relies on server idempotency to return an already-completed result when the first response was lost.

It also retries one server-rejected assertion with a fresh challenge and counter, and resets an unknown local key once when the server returns `attestation_key_not_registered`.

Task cancellation and `URLError.cancelled` are propagated as `CancellationError`; they are never treated as retryable transport failures.

## Status

```swift
let status = try await aiClient.status()
```

Status includes the server-resolved attestation mode, registration state, plan, and remaining usage. It does not expose provider/model selection or attestation key material.

## Reset

```swift
try await aiClient.resetInstallationIdentity()
```

This removes the Keychain installation ID, the current app-local App Attest identifier, pending registration state, and the legacy Keychain key reference. It works even before the client has made its first protected request.

Use it only for deliberate troubleshooting. It creates a new server installation identity and can affect quota continuity. Because reset is process-coordinated and clients do not retain per-instance installation or default-provider caches, another `AppAIClient` instance with the same configuration reads the new identity on its next request.

## Testing

Inject `AppAITransport` and `AppAIAttestationProviding` implementations to test requests without network access or DeviceCheck. Production apps normally use the default URLSession transport and Apple App Attest provider.

The regression suite covers:

- New installation and reinstall registration
- Upgrade migration from the legacy Keychain identifier
- Stale restored-key rotation for `invalidKey` and `invalidInput`
- No infinite rotation for a failing fresh key
- Same-key and same-hash retry after Apple `serverUnavailable`
- Pending-key discard after nontransient Apple errors
- Uncertain versus definite app-server registration outcomes
- Unknown-server-key recovery
- Assertion-counter serialization across concurrent clients
- Shared installation identity creation
- Reset before first use
- Cancellation without transport retry

Physical-device validation remains necessary because mocked tests cannot reproduce DeviceCheck, Secure Enclave, provisioning, or development-versus-production entitlement behavior.

## StoreKit entitlement sync

The server—not local `hasPro` state—decides whether an installation receives paid AI quota.

After a purchase, restore, or `Transaction.updates`, verify the result and send its StoreKit JWS:

```swift
if case .verified = verification {
    let result = try await aiClient.syncEntitlements(
        transactions: [verification.jwsRepresentation]
    )

    print(result.access.plan)
    print(result.access.quotaLimit)
}
```

The request uses the same app headers, installation identity, retry behavior, and App Attest protection as generation. The server verifies Apple’s signature, certificate chain, bundle ID, environment, configured product ID, expiry, and revocation state.

To refresh all currently active StoreKit entitlements:

```swift
let status = try await aiClient.syncCurrentEntitlements()
```

`syncCurrentEntitlements()` is available when StoreKit can be imported. It sends only StoreKit-verified current entitlements, batching requests at the server's 20-transaction limit, and then returns fresh server status. Apps should still observe `Transaction.updates` and submit each newly verified transaction promptly.

Do not use local purchase state to select a paid quota or send a claimed premium flag. `AppAIStatus.plan` and `AppAIStatus.entitlement` are server-resolved.
