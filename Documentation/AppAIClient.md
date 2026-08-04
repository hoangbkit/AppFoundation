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

The App Attest key identifier is intentionally stored in app-local preferences rather than Keychain. App Attest proves that requests come from a valid app instance on supported Apple hardware; it is not used as a permanent installation identity. When the app is uninstalled, the local identifier disappears. A reinstall therefore generates, attests, and registers a fresh App Attest key while retaining the existing Keychain installation ID when iOS preserves it.

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

- Stable request IDs
- Sorted deterministic JSON encoding
- App and installation headers
- Typed response and stable server-error decoding
- Retry with the same logical request ID and body
- App Attest registration and assertion headers on supported iOS devices
- Fresh one-time assertions for every transport retry
- A fresh App Attest key after reinstall
- One-time key rotation when Apple reports a locally cached key as invalid
- Re-registration when the server no longer recognizes a locally stored key

## Attestation policies

### Disabled

```swift
attestationPolicy: .disabled
```

No App Attest work is attempted. Use for development or an app whose server policy disables attestation.

### Preferred

```swift
attestationPolicy: .preferred
```

The client uses App Attest when supported. Unsupported macOS clients or temporary attestation failures proceed without assertion headers; the server decides whether to accept them and applies the configured restricted quota.

### Required

```swift
attestationPolicy: .required
```

The client fails locally when App Attest is unsupported or assertion creation fails. The server also rejects requests without a valid assertion.

## Reinstall and key rotation

The installation ID and App Attest key have separate lifecycles:

1. The installation ID remains in Keychain and continues to identify the server-side quota record when iOS preserves Keychain data.
2. The App Attest key identifier lives in app-local preferences and disappears with the app.
3. A reinstall has no local key identifier, so the client generates and registers a new App Attest key automatically.
4. If Apple later reports a cached key as invalid, the client removes that identifier, registers a fresh key, and retries the logical request once.

The server may associate more than one valid App Attest key with the same installation. Key rotation is not treated as a new device identity.

## Retry behavior

Provider generation is idempotent by logical request ID. A transport failure may mean the server completed the request even though the response did not reach the app.

The client therefore:

1. Retains the same `requestID` and encoded request body.
2. Obtains a new one-time App Attest challenge and assertion.
3. Retries the request.
4. Receives either the original stored result or the newly completed result.

It never reuses an App Attest assertion because the server consumes each challenge and enforces an increasing counter.

## Status

```swift
let status = try await aiClient.status()
```

Status includes the server-resolved attestation mode, registration state, plan, and remaining usage. It does not expose provider/model selection or attestation key material.

## Reset

```swift
try await aiClient.resetInstallationIdentity()
```

This removes the installation ID and local App Attest key reference. Use only for deliberate troubleshooting; it creates a new server installation identity and can affect quota continuity.

## Testing

Inject `AppAITransport` and `AppAIAttestationProviding` implementations to test requests without network access or DeviceCheck. Production apps normally use the default URLSession transport and Apple App Attest provider.

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
