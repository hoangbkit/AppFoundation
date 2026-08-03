# Shared AI Infrastructure Implementation

Status: AppFoundation core implemented; DraftX and MenuLens migrations pending

Branch: `agent/shared-ai-infrastructure-plan`

Base: `develop`

## Implemented in AppFoundation

### Managed AI

The existing managed stack remains unchanged and authoritative:

- `AppAIClient`
- App Attest registration and assertions
- stable installation identity
- StoreKit JWS entitlement synchronization
- server-resolved plan and quota status
- managed request idempotency and transport retry

`AppAIStatusStore` now provides reusable entitlement/status refresh coordination, queued refreshes, stale-status preservation, and generation/purchase refresh hooks.

### Direct BYOK foundation

The branch adds:

- extensible `AppAIProviderID` values;
- managed/direct `AppAIBackendID` values;
- app-configured backend descriptors and catalogs;
- explicit backend capability metadata;
- neutral text-message requests;
- plain-text, JSON-object, and JSON-schema output requests;
- Sendable JSON schema values;
- normalized direct responses, token usage, model metadata, and errors;
- JSON-fence removal before typed decoding;
- explicit ambiguous-transport errors;
- no automatic direct-generation retry.

### Credential and preference storage

The branch adds:

- app-namespaced Keychain credential storage;
- `AfterFirstUnlockThisDeviceOnly` accessibility through the existing secure store;
- provider-isolated accounts;
- whitespace normalization and empty-value deletion;
- in-memory credential storage for tests;
- namespaced selected-backend and per-provider model preferences;
- in-memory preferences for tests.

The proxy app key remains separate from user BYOK credentials.

### Direct providers

Implemented clients:

1. `OpenAIResponsesClient`
2. `AnthropicMessagesClient`
3. `GeminiGenerateContentClient`
4. `OpenAICompatibleClient`

The OpenAI-compatible client supports configurable authentication, headers, endpoints, model listing, and structured output. Presets are included for:

- OpenRouter
- DeepSeek
- NVIDIA

Provider presets do not include DraftX- or MenuLens-specific prompts, model defaults, website URLs, or display titles beyond the neutral provider name.

### Backend coordination

`AppAIBackendManager` provides:

- app-configured backend exposure;
- selected-backend restoration and persistence;
- per-provider model restoration and persistence;
- credential setup status;
- connection tests;
- model listing;
- direct-client lookup.

It intentionally does not expose a universal `generate` method. Apps retain separate managed-capability and direct-message coordinators.

### Reusable SwiftUI pieces

Added:

- `AppAIBackendPicker`
- `AppAIBackendStatusRow`
- `AppAIAPIKeyField`
- `AppAIModelField`
- `AppAIConnectionTestButton`
- `AppAIDirectProviderConfigurationView`
- `AppAIManagedUsageSection`

These are composable pieces rather than one mandatory settings screen.

## Safety guarantees

### Managed path

The existing proxy path retains stable request IDs, exact encoded bodies, App Attest assertions, server idempotency, stored replay, quota enforcement, and entitlement verification.

### Direct path

Direct generation performs one transport attempt. A network failure is surfaced as `AppAIDirectError.transport` with `completionUnknown: true`, because the provider may have completed and charged for the request before the response was lost.

Model-list and connection-test requests can be explicitly retriggered by the caller, but AppFoundation does not silently retry generation.

## Provider wire formats

The implementation uses:

- Responses API message items with `type: "message"` and text content items;
- Responses API structured output through `text.format`;
- Anthropic Messages with system instructions and prompt-enforced JSON when structured output is requested;
- Gemini GenerateContent with `responseMimeType` and `responseJsonSchema`;
- OpenAI-compatible Chat Completions with `response_format` for JSON object or JSON schema output.

## Validation performed

- The full new AppFoundation source set compiles in a reconstructed Swift 6.2 package.
- Eight direct-provider, credential, preference, structured-output, and retry-safety tests pass under Swift 6.2.
- Backend-manager and status-store source files compile under Swift 6.2.
- No live API credentials or provider calls are required by tests.
- GitHub Actions were not run.

The execution environment cannot clone the GitHub repository because outbound DNS is unavailable, so a real Apple-platform package build and Xcode test run must still be performed before merging.

## Remaining work

### DraftX migration

- replace its custom managed service with `AppAIClient`;
- replace direct provider clients with AppFoundation clients;
- preserve or migrate existing Keychain credentials;
- preserve selected provider and model preferences;
- retain DraftX prompts, workflows, candidate parsing, result models, and history.

### MenuLens migration

- add the app-configured backend catalog and settings;
- create its direct menu prompt and JSON schema;
- store the selected backend with pending analysis state;
- retain OCR, typed menu contracts, validation, persistence, and recovery;
- apply different retry behavior for managed and direct requests;
- keep original menu photos local in the initial BYOK flow.

### Before merge

Run on an Apple development machine:

```bash
swift test
```

Then build the AppFoundation Demo for iOS and macOS to validate the reusable SwiftUI components and actor isolation in the supported deployment targets.

## Example catalog

```swift
let catalog = AppAIBackendCatalog(
    backends: [
        .managed(
            title: "MenuLens AI",
            subtitle: "Included monthly analyses"
        ),
        .openAI(preferredModel: MenuLensModels.openAI),
        .anthropic(preferredModel: MenuLensModels.anthropic),
        .gemini(preferredModel: MenuLensModels.gemini),
        .openRouter(preferredModel: MenuLensModels.openRouter)
    ]
)
```

## Example direct request

```swift
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
```

The app remains responsible for validating `MenuInterpretOutput` and mapping it into product state.
