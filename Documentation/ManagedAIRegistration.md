# Managed AI Registration

An app registers managed AI with AppFoundation by constructing one `AppAIManagedBackend` and passing it to `AppAIBackendManager`.

The app does not manually register installations or App Attest keys. `AppAIClient` creates a stable Keychain installation ID and performs App Attest registration automatically on the first protected request.

## App setup

```swift
let managedBackend = AppAIManagedBackend(
    descriptor: .managed(
        title: "MenuLens AI",
        subtitle: "Included monthly analyses"
    ),
    configuration: AppAIClientConfiguration(
        appID: "menulens",
        appKey: MenuLensEnvironment.aiProxyAppKey,
        baseURL: MenuLensEnvironment.aiProxyURL,
        attestationPolicy: .required,
        keychainService: "com.hoangbkit.menulens.managed-ai"
    )
)

let backendManager = AppAIBackendManager(
    catalog: AppAIBackendCatalog(
        backends: [
            .openAI(preferredModel: MenuLensModels.openAI),
            .anthropic(preferredModel: MenuLensModels.anthropic),
            .gemini(preferredModel: MenuLensModels.gemini),
        ]
    ),
    managedBackend: managedBackend,
    clients: directProviderClients,
    credentialStore: credentialStore,
    preferences: preferences
)
```

The managed descriptor is inserted at the beginning of the catalog when the catalog does not already contain `.managed`. When a placeholder managed descriptor exists, the registered descriptor replaces it.

## Checking configuration

```swift
let isManagedReady = await backendManager.isConfigured(.managed)
```

Managed AI is configured only when an `AppAIManagedBackend` was supplied. Merely placing a `.managed` descriptor in the catalog does not make it configured.

```swift
let client = try backendManager.requireManagedClient()
```

`requireManagedClient()` throws `AppAIError.invalidConfiguration` when the app did not register managed AI.

## Generation coordinator

```swift
switch backendManager.selectedBackendID {
case .managed:
    let client = try backendManager.requireManagedClient()

    let response: AppAIResponse<MenuInterpretOutput> = try await client.generate(
        capability: "menu.interpret",
        input: input,
        requestID: requestID
    )

    let output = response.data

case .direct(let providerID):
    let client = try backendManager.directClient(for: providerID)
    let response = try await client.generate(
        AppAIDirectRequest(
            model: backendManager.model(for: providerID),
            messages: MenuLensPrompt.messages(for: input),
            responseFormat: .jsonSchema(MenuLensPrompt.schema),
            temperature: 0.1,
            maxOutputTokens: 2_000
        )
    )

    let output = try response.decodeJSON(MenuInterpretOutput.self)
}
```

AppFoundation owns transport and security. The app still owns its capability mapping, direct prompts, typed domain models, validation, persistence, and user-facing errors.

## Managed status

On Apple platforms, the configuration initializer creates an `AppAIStatusStore` automatically:

```swift
let statusStore = backendManager.managedStatusStore
statusStore?.refresh(syncEntitlements: true)
```

Apps should call:

- `purchaseStateDidChange()` after StoreKit purchase or restore changes;
- `generationDidComplete()` after a managed generation finishes;
- `refresh(syncEntitlements: true)` during launch entitlement refresh.

## Server provisioning remains separate

Before the app can connect, its tenant must exist in `ai-proxy-server` with:

- app ID and bundle ID;
- app-key hash;
- team ID and App Store Apple ID;
- App Attest mode;
- capabilities;
- products and quotas;
- provider and model routing.

The raw app key belongs in the app's protected build configuration. It is not a BYOK credential and must not be shown in provider settings UI.
