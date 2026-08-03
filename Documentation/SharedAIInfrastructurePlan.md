# Shared AI Infrastructure Plan

Status: Proposed implementation plan

Primary consumers: DraftX and MenuLens

Target branch: `develop`

## Decision

AppFoundation will own how an app securely reaches AI.

Each product will continue to own what it asks AI to do and what the result means.

The shared infrastructure will support two intentionally different execution paths:

1. Managed AI through the existing `AppAIClient` and `ai-proxy-server`.
2. Direct BYOK requests through reusable provider clients, secure credential storage, provider/model preferences, connection testing, backend selection, and small reusable settings components.

Managed AI and BYOK will share configuration and presentation infrastructure, but they will not be forced behind one universal generation method. Their request contracts, security boundaries, quota behavior, and retry guarantees are materially different.

## Goals

- Reuse the existing production-oriented `AppAIClient` for managed AI in DraftX, MenuLens, and future apps.
- Remove duplicated provider, Keychain, model preference, error mapping, and settings code from individual apps.
- Support both free/paid managed AI and user-supplied provider credentials.
- Keep DraftX writing concepts out of AppFoundation.
- Keep MenuLens menu-analysis concepts out of AppFoundation.
- Preserve typed managed capability contracts.
- Support plain-text and structured JSON direct-provider output.
- Make provider exposure and preferred models app-configurable.
- Prevent unsafe automatic retries for non-idempotent direct-provider requests.
- Keep the initial public API small enough to stabilize across multiple apps.

## Non-goals

This work will not add:

- provider or model selection to `ai-proxy-server` requests;
- app prompts, capability definitions, or domain response models to AppFoundation;
- a universal app-level generation coordinator;
- automatic direct-provider retry after an ambiguous transport failure;
- streaming;
- tools or function calling;
- multimodal image transport in the first shared BYOK release;
- user accounts or cross-app credential sharing;
- cloud synchronization of API keys;
- dynamic remote provider catalogs owned by AppFoundation;
- a mandatory all-in-one AI settings screen.

MenuLens will continue to prepare images and run OCR on device. Its BYOK path will initially send recognized text, not the original menu image.

## Existing managed AI foundation

The existing AppFoundation managed stack remains authoritative for proxy-backed AI:

- `AppAIClient`
- `AppAIClientConfiguration`
- `AppAIResponse`
- `AppAIStatus`
- `AppAIUsage`
- `AppAIAccess`
- `AppAIError`
- `AppAISecureStore`
- `AppleAppAttestationProvider`
- installation identity
- App Attest registration and per-request assertions
- exact-body assertion binding
- stable logical request IDs
- idempotent transport retry
- unknown-key recovery
- StoreKit JWS entitlement synchronization
- server-resolved plan and quota state

Apps using managed AI submit only a capability and typed input:

```swift
let response: AppAIResponse<MenuInterpretOutput> = try await client.generate(
    capability: "menu.interpret",
    input: input,
    requestID: requestID
)
```

The proxy remains responsible for:

- provider credentials;
- model selection;
- system prompts;
- output constraints;
- provider fallback;
- quotas and budgets;
- App Attest policy;
- StoreKit verification;
- idempotency and stored replay.

No new abstraction should duplicate or wrap away these guarantees.

## Shared architecture

The AppFoundation AI directory will be organized by responsibility:

```text
Sources/AppFoundation/AI/
├── Managed/
│   ├── AppAIClient.swift
│   ├── AppAIModels.swift
│   ├── AppAISecureStore.swift
│   └── AppAttestProvider.swift
│
├── Direct/
│   ├── AppAIDirectModels.swift
│   ├── AppAIDirectProviderClient.swift
│   ├── AppAIDirectError.swift
│   ├── OpenAIResponsesClient.swift
│   ├── AnthropicMessagesClient.swift
│   ├── GeminiGenerateContentClient.swift
│   └── OpenAICompatibleClient.swift
│
├── Backend/
│   ├── AppAIProviderID.swift
│   ├── AppAIBackendDescriptor.swift
│   ├── AppAIBackendCatalog.swift
│   ├── AppAIBackendManager.swift
│   ├── AppAICredentialStore.swift
│   ├── AppAIBackendPreferences.swift
│   └── AppAIStatusStore.swift
│
└── UI/
    ├── AppAIBackendPicker.swift
    ├── AppAIBackendStatusRow.swift
    ├── AppAIDirectProviderConfigurationView.swift
    └── AppAIManagedUsageSection.swift
```

The existing files may be moved into `Managed/` only when that can be done without unnecessary public API churn. Directory organization is secondary to API stability.

The AI code will remain in the main `AppFoundation` library product initially. A separate package product should be considered only if future dependencies, binary size, or adoption patterns make separation useful.

## Public identifiers

A closed provider enum is too restrictive because apps may expose different providers and future OpenAI-compatible services should not require editing a central switch.

Use an extensible value type:

```swift
public struct AppAIProviderID:
    RawRepresentable,
    Hashable,
    Codable,
    Sendable
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let openAI = Self(rawValue: "openai")
    public static let anthropic = Self(rawValue: "anthropic")
    public static let gemini = Self(rawValue: "gemini")
    public static let openRouter = Self(rawValue: "openrouter")
    public static let deepSeek = Self(rawValue: "deepseek")
    public static let nvidia = Self(rawValue: "nvidia")
}
```

Managed AI is a backend type, not a direct provider:

```swift
public enum AppAIBackendID: Hashable, Codable, Sendable {
    case managed
    case direct(AppAIProviderID)
}
```

This prevents app-owned labels such as “DraftX AI” or “MenuLens AI” from leaking into the transport layer.

## Backend descriptors

Apps define which backends are visible and how they are presented:

```swift
public struct AppAIBackendDescriptor: Identifiable, Sendable {
    public let id: AppAIBackendID
    public let title: String
    public let subtitle: String?
    public let symbolName: String?
    public let capabilities: AppAIBackendCapabilities
}
```

```swift
public struct AppAIBackendCapabilities: Sendable {
    public let supportsText: Bool
    public let supportsStructuredOutput: Bool
    public let supportsModelDiscovery: Bool
    public let providesManagedUsage: Bool
    public let guaranteesIdempotentReplay: Bool
}
```

Expected values:

- Managed proxy: structured output, managed usage, and idempotent replay are available according to the configured capability.
- Direct provider: text and possibly structured output are available; managed usage and idempotent replay are not.

Apps build their own catalog:

```swift
let catalog = AppAIBackendCatalog(
    backends: [
        .managed(
            title: "MenuLens AI",
            subtitle: "Included monthly analyses"
        ),
        .openAI(preferredModel: AppModels.openAI),
        .anthropic(preferredModel: AppModels.anthropic),
        .gemini(preferredModel: AppModels.gemini),
        .openRouter(preferredModel: AppModels.openRouter)
    ]
)
```

AppFoundation supplies provider presets and transport factories. Each app decides which presets to include.

## Direct request contract

The direct-provider API must be neutral to both writing and menu analysis.

```swift
public struct AppAIDirectRequest: Sendable {
    public let model: String
    public let messages: [AppAIMessage]
    public let responseFormat: AppAIResponseFormat
    public let temperature: Double?
    public let maxOutputTokens: Int?
}
```

```swift
public struct AppAIMessage: Sendable {
    public enum Role: String, Sendable {
        case system
        case user
        case assistant
    }

    public let role: Role
    public let content: String
}
```

The initial shared request remains text-only. This is enough for:

- DraftX prompts and candidate generation;
- MenuLens OCR-derived menu interpretation;
- future text summarization, translation, extraction, and classification apps.

Multimodal input should be added later as a separate, deliberate extension after a real consumer requires it. This avoids prematurely fixing image encoding, upload limits, privacy behavior, and provider-specific formats into the first public API.

## Structured output

Direct BYOK must support both plain text and structured JSON.

```swift
public enum AppAIResponseFormat: Sendable {
    case text
    case jsonObject
    case jsonSchema(AppAIJSONSchema)
}
```

```swift
public struct AppAIJSONSchema: Sendable {
    public let name: String
    public let schema: AppAIJSONValue
    public let strict: Bool
}
```

`AppAIJSONValue` will be a Sendable JSON value representation that can encode objects, arrays, strings, numbers, booleans, and null without depending on `[String: Any]`.

Provider implementations may map the requested format differently:

- OpenAI Responses: native structured output where supported.
- Gemini: response MIME type and schema where supported.
- Anthropic: prompt-enforced JSON unless a stronger supported API is adopted.
- OpenAI-compatible providers: native response format when supported, otherwise prompt-enforced JSON.

The shared layer guarantees only that it returns normalized text and useful metadata. Each app remains responsible for decoding and validating its domain model.

## Direct response contract

```swift
public struct AppAIDirectResponse: Sendable {
    public let text: String
    public let providerID: AppAIProviderID
    public let modelID: String
    public let finishReason: String?
    public let usage: AppAIDirectUsage?
}
```

```swift
public struct AppAIDirectUsage: Sendable, Equatable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cachedInputTokens: Int?
}
```

Provide a convenience decoder:

```swift
public extension AppAIDirectResponse {
    func decodeJSON<Value: Decodable>(
        _ type: Value.Type,
        using decoder: JSONDecoder = .init()
    ) throws -> Value
}
```

The decoder may remove one outer markdown JSON fence before decoding. It must not implement DraftX candidate limits, MenuLens dish validation, or any product-specific fallback value.

## Direct provider protocol

```swift
public protocol AppAIDirectProviderClient: Sendable {
    var providerID: AppAIProviderID { get }

    func hasCredential() async -> Bool
    func saveCredential(_ value: String) async throws
    func removeCredential() async throws

    func testConnection(model: String) async throws
    func generate(
        _ request: AppAIDirectRequest
    ) async throws -> AppAIDirectResponse

    func availableModels() async throws -> [AppAIModel]
}
```

`availableModels()` may return an empty array. Manual model entry remains supported because model-list endpoints vary in quality and permissions.

```swift
public struct AppAIModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let contextLength: Int?
}
```

## Direct provider implementations

The first implementation set will be:

1. `OpenAIResponsesClient`
2. `AnthropicMessagesClient`
3. `GeminiGenerateContentClient`
4. `OpenAICompatibleClient`

`OpenAICompatibleClient` will be configuration-driven and cover:

- OpenRouter;
- DeepSeek;
- NVIDIA;
- compatible future services.

```swift
public struct OpenAICompatibleConfiguration: Sendable {
    public let providerID: AppAIProviderID
    public let title: String
    public let baseURL: URL
    public let authentication: AppAIProviderAuthentication
    public let additionalHeaders: [String: String]
    public let defaultModel: String?
}
```

Provider presets must not hardcode DraftX-specific HTTP referer or application-title headers. Apps pass their website and display name when constructing an OpenRouter preset.

## Credential storage

BYOK credentials will be stored in an app-specific Keychain namespace.

```swift
public protocol AppAICredentialStoring: Sendable {
    func hasCredential(for provider: AppAIProviderID) async -> Bool
    func credential(for provider: AppAIProviderID) async throws -> String?
    func setCredential(
        _ credential: String,
        for provider: AppAIProviderID
    ) async throws
    func removeCredential(
        for provider: AppAIProviderID
    ) async throws
}
```

The public manager should expose only `has`, `save`, and `remove`. Raw credential retrieval is needed by provider clients but should not be encouraged in app UI code.

The default implementation will:

- use generic-password Keychain items;
- use `AfterFirstUnlockThisDeviceOnly` accessibility;
- disable synchronization;
- trim leading/trailing whitespace;
- delete the item when an empty credential is saved;
- use the provider ID as the account namespace;
- accept an app-specific service identifier;
- support an injectable in-memory test store.

Example service names:

```text
com.hoangbkit.draftx.ai-providers
com.hoangbkit.menulens.ai-providers
```

The proxy app key remains separate. It is a build secret used by `AppAIClientConfiguration`, not a user credential managed by the BYOK UI.

## Preferences

Selected backend and model choices are app-local preferences.

```swift
public protocol AppAIBackendPreferences: Sendable {
    func selectedBackend() async -> AppAIBackendID?
    func setSelectedBackend(_ backend: AppAIBackendID) async

    func model(for provider: AppAIProviderID) async -> String?
    func setModel(
        _ model: String?,
        for provider: AppAIProviderID
    ) async
}
```

The default implementation will use namespaced `UserDefaults` keys.

AppFoundation will not own long-lived preferred model constants. DraftX and MenuLens can choose different defaults because their quality, language, structure, speed, and cost requirements differ.

## Backend manager

`AppAIBackendManager` coordinates selection and provider configuration, but does not become a universal generation service.

```swift
@MainActor
@Observable
public final class AppAIBackendManager {
    public private(set) var selectedBackendID: AppAIBackendID
    public let catalog: AppAIBackendCatalog

    public func select(_ backend: AppAIBackendID)
    public func isConfigured(_ backend: AppAIBackendID) async -> Bool

    public func saveCredential(
        _ credential: String,
        for provider: AppAIProviderID
    ) async throws

    public func removeCredential(
        for provider: AppAIProviderID
    ) async throws

    public func model(for provider: AppAIProviderID) -> String
    public func setModel(
        _ model: String,
        for provider: AppAIProviderID
    )

    public func test(
        provider: AppAIProviderID,
        model: String
    ) async throws

    public func directClient(
        for provider: AppAIProviderID
    ) throws -> any AppAIDirectProviderClient
}
```

It intentionally will not expose `generate(...)`.

Managed generation remains typed by capability:

```swift
appAIClient.generate(
    capability: "menu.interpret",
    input: input,
    requestID: requestID
)
```

Direct generation remains message-based:

```swift
client.generate(
    AppAIDirectRequest(
        model: model,
        messages: MenuLensPrompt.messages(for: input),
        responseFormat: .jsonSchema(MenuLensPrompt.schema),
        temperature: 0.1,
        maxOutputTokens: 2_000
    )
)
```

Each app owns the small coordinator that selects the correct path and maps results into its domain.

## Retry and idempotency rules

This distinction is mandatory.

### Managed AI

The managed path supports:

- stable logical request IDs;
- deterministic encoded bodies;
- server idempotency;
- stored replay;
- safe transport retry with a fresh App Attest assertion;
- `request_in_progress` recovery.

Apps may resume the same logical request when the body is unchanged.

### Direct BYOK

The direct path does not guarantee provider-side idempotency.

Therefore AppFoundation must not automatically retry generation after a transport failure where the provider may already have processed the request.

Allowed behavior:

- retry connection tests when they are explicitly re-triggered by the user;
- retry before a request is sent;
- retry safe model-list requests;
- surface a typed ambiguous-transport error for generation;
- let the app decide whether to create a fresh request.

MenuLens must record which backend was used in pending analysis state. A proxy-backed pending request can resume with the same request ID. A direct-provider request with uncertain completion must be treated as a fresh retry and may require explicit user messaging that the provider could charge twice.

DraftX may offer a simpler “Try again” flow because it does not depend on durable server replay for local persistence.

## Error model

Keep managed and direct transport errors separate.

- `AppAIError` remains the managed proxy error type.
- Add `AppAIDirectError` for direct providers.

```swift
public enum AppAIDirectError: LocalizedError, Sendable, Equatable {
    case missingCredential(AppAIProviderID)
    case invalidModel
    case invalidRequest(String)
    case invalidResponse
    case authenticationFailed
    case permissionDenied
    case insufficientCredits
    case rateLimited(retryAfter: String?)
    case modelUnavailable
    case emptyOutput
    case structuredOutputUnsupported
    case transport(message: String, completionUnknown: Bool)
    case provider(status: Int, message: String)
}
```

Provider implementations will normalize known provider-specific status codes and response envelopes into this type.

Apps remain responsible for deciding:

- retry mode;
- paywall or upgrade presentation;
- privacy copy;
- user-facing domain errors;
- whether a malformed domain result can be repaired locally.

## Managed status store

MenuLens already demonstrates reusable status behavior: entitlement sync, refresh queuing, stale status preservation, and refresh after generation.

Move the neutral behavior into AppFoundation:

```swift
@MainActor
@Observable
public final class AppAIStatusStore {
    public enum State {
        case idle
        case refreshing
        case current(AppAIStatus, updatedAt: Date)
        case stale(AppAIStatus, updatedAt: Date, error: AppAIError)
        case failed(AppAIError)
    }

    public private(set) var state: State

    public func refresh(syncEntitlements: Bool)
    public func refreshAndWait(syncEntitlements: Bool) async
    public func purchaseStateDidChange()
    public func generationDidComplete()
}
```

The store owns refresh coordination. Apps own logging, labels, and presentation copy.

## Shared SwiftUI components

Share small composable views:

- `AppAIBackendPicker`
- `AppAIBackendStatusRow`
- `AppAIDirectProviderConfigurationView`
- `AppAIAPIKeyField`
- `AppAIModelField`
- `AppAIConnectionTestButton`
- `AppAIManagedUsageSection`
- optional `AppAIBackendSettingsSection`

Configuration will control:

- managed backend title;
- exposed providers;
- preferred models;
- manual model entry;
- model browsing;
- privacy and data-routing footers;
- app-specific supporting content;
- theme behavior.

Do not ship one mandatory full settings screen. DraftX and MenuLens have different surrounding commercial, usage, support, and privacy sections.

## DraftX ownership

DraftX keeps:

- `AIWritingWorkflow`;
- prompt presets;
- user-created instructions;
- `AIPromptComposer`;
- platform context;
- workflow-to-capability mapping;
- candidate count and candidate parsing;
- `GeneratedDraft`;
- generation history;
- DraftX retry and error presentation;
- product rules governing whether BYOK is visible or available.

DraftX removes or replaces:

- its custom managed server configuration;
- its custom installation ID store;
- `DraftXAIService`;
- duplicated managed status and quota models;
- duplicated provider Keychain service;
- direct provider clients after equivalent AppFoundation clients exist;
- generic provider/model settings infrastructure.

The DraftX coordinator will:

1. Read the selected backend from `AppAIBackendManager`.
2. For managed AI, map the writing workflow to a capability and call `AppAIClient`.
3. For BYOK, compose direct messages and call the selected direct client.
4. Parse candidates and create `GeneratedDraft`.
5. Record DraftX generation history.

## MenuLens ownership

MenuLens keeps:

- image preparation;
- on-device OCR;
- `MenuInterpretInput`;
- `MenuInterpretOutput`;
- the menu JSON schema;
- direct-provider menu prompt construction;
- dish validation;
- allergy and dietary safety wording;
- pending analysis persistence;
- menu persistence and history;
- UI state and recovery presentation;
- mapping to the managed `menu.interpret` capability.

MenuLens removes or replaces:

- app-local provider credential storage once BYOK is added;
- app-local provider/model settings plumbing;
- app-local neutral status refresh coordination after `AppAIStatusStore` is available.

The MenuLens coordinator will:

1. Complete image preparation and OCR locally.
2. Store the selected backend with pending request metadata.
3. For managed AI, call `AppAIClient` with `menu.interpret` and the stable request ID.
4. For BYOK, build direct messages and request structured JSON.
5. Decode `MenuInterpretOutput` and call `validatedAnalysis()`.
6. Save the completed response locally before final menu persistence.
7. Apply backend-specific retry semantics.

## Implementation phases

### Phase 0 — Baseline and tests

- Keep existing `AppAIClient` behavior unchanged.
- Add or retain coverage for managed request identity, exact-body retry, App Attest recovery, entitlement batching, and status decoding.
- Document managed-versus-direct guarantees before adding new public APIs.

Exit criteria:

- Current AppFoundation AI tests pass.
- MenuLens managed flow still compiles against AppFoundation.

### Phase 1 — Neutral direct models and storage

Add:

- `AppAIProviderID`;
- `AppAIBackendID`;
- backend descriptors and capability metadata;
- `AppAIMessage`;
- direct request/response types;
- structured response-format types;
- `AppAIDirectError`;
- credential storage protocol and Keychain implementation;
- preference protocol and default implementation.

Exit criteria:

- no provider network implementation is required yet;
- all storage and serialization tests pass;
- no DraftX or MenuLens domain type is imported.

### Phase 2 — Direct provider transports

Implement and test:

- OpenAI Responses;
- Anthropic Messages;
- Gemini GenerateContent;
- generic OpenAI-compatible Chat Completions;
- provider presets for OpenRouter, DeepSeek, and NVIDIA.

Tests must verify:

- URL and method;
- authentication headers;
- additional headers;
- request body shape;
- model and token fields;
- structured-output mapping;
- response extraction;
- empty and malformed responses;
- provider error normalization;
- no automatic generation retry.

Exit criteria:

- all clients work through injected transports;
- no live provider credentials are required for tests.

### Phase 3 — Backend catalog and manager

Implement:

- app-configured backend catalog;
- selected backend persistence;
- per-provider model persistence;
- configuration status;
- connection testing;
- direct-client lookup;
- managed backend descriptor support.

Exit criteria:

- a test app can expose any subset of managed and direct backends;
- app-specific labels and defaults are not hardcoded in AppFoundation.

### Phase 4 — Status store and UI components

Implement:

- `AppAIStatusStore`;
- stale/current/failed state handling;
- refresh queuing;
- entitlement synchronization hooks;
- small provider and usage UI components.

Exit criteria:

- MenuLens can replace its neutral status coordination without losing behavior;
- DraftX can build its provider screen from shared pieces;
- no mandatory full-screen design is imposed.

### Phase 5 — DraftX migration

- Update DraftX to the AppFoundation branch/version containing the new APIs.
- Replace `DraftXAIService` with `AppAIClient`.
- Replace direct clients with AppFoundation clients.
- Replace Keychain and model preference code.
- Keep DraftX prompts, workflows, result parsing, and history local.
- Migrate existing saved provider keys where service/account names change, or preserve the old Keychain service identifiers through configuration.
- Migrate existing provider/model UserDefaults keys.
- Remove dead duplicate code only after migration tests pass.

Exit criteria:

- managed DraftX requests use `ai-proxy-server` through `AppAIClient`;
- all existing BYOK providers still work;
- existing users do not silently lose configured keys or models;
- DraftX direct-provider tests are either moved or replaced by AppFoundation coverage;
- DraftX domain tests remain in DraftX.

### Phase 6 — MenuLens BYOK integration

- Add an app-configured backend catalog.
- Add provider settings using shared components.
- Add a MenuLens direct prompt and JSON schema.
- Store selected backend in pending analysis metadata.
- Keep OCR text as the direct-provider input.
- Apply managed and direct retry semantics separately.
- Decide product rules for BYOK access and managed quota presentation.
- Update privacy policy and in-app disclosure for direct provider routing.

Exit criteria:

- MenuLens managed flow remains unchanged for existing users;
- users can select and test a BYOK provider;
- structured direct output decodes into `MenuInterpretOutput`;
- malformed or empty dish output fails through MenuLens validation;
- direct ambiguous failures are never silently retried;
- original menu photos remain local in the initial BYOK implementation.

### Phase 7 — Stabilization and release

- Add complete public documentation and examples for DraftX-style text generation and MenuLens-style structured extraction.
- Add migration notes.
- Review Sendable and actor isolation under Swift 6.
- Run package tests on supported iOS and macOS configurations.
- Mark the public API experimental while AppFoundation remains pre-1.0.
- Adopt the implementation in both consumers before declaring the API stable.

Exit criteria:

- DraftX and MenuLens both use the shared infrastructure;
- no duplicated neutral provider plumbing remains in either app;
- API names are validated by two materially different products.

## Test matrix

### Credential and preference tests

- credentials are isolated by app service and provider account;
- empty values delete credentials;
- whitespace is normalized;
- credentials do not synchronize through iCloud;
- selected backend survives relaunch;
- per-provider model choices are independent;
- legacy DraftX values migrate correctly.

### Provider transport tests

For every provider:

- credential header is correct;
- request URL is correct;
- selected model is transmitted;
- text messages are mapped correctly;
- token limits are mapped correctly;
- structured-output requests use the strongest supported mechanism;
- plain text is extracted correctly;
- JSON fences can be normalized by the response decoder;
- authentication, credits, rate limits, model errors, policy blocks, and malformed responses map correctly;
- cancellation propagates;
- an ambiguous transport error reports `completionUnknown = true`;
- generation is not automatically retried.

### Backend manager tests

- only configured catalog entries are exposed;
- managed and direct backends have correct capability metadata;
- direct backend status reflects credential presence;
- managed backend status comes from `AppAIStatusStore`;
- connection testing does not change the selected backend unless explicitly requested;
- app-specific titles and preferred models are preserved.

### Consumer contract tests

DraftX:

- prompt composition remains app-owned;
- managed workflow maps to the expected capability;
- direct response candidate parsing remains deterministic;
- generation history records backend and model correctly.

MenuLens:

- OCR-derived input remains versioned and deterministic;
- managed request resumes safely with the same request ID;
- direct request uses a fresh retry after ambiguous completion;
- structured output decodes and validates dishes;
- completed response is persisted before final menu persistence;
- menu images are not included in the initial direct request.

## Migration and compatibility rules

- Do not rename existing managed public types merely for directory consistency.
- Do not break `AppAIClient` call sites during the direct-provider implementation.
- Preserve Keychain identifiers during app migration when possible.
- When identifiers must change, perform a one-time copy-then-delete migration only after the new value is stored successfully.
- Preserve existing DraftX selected-provider and model settings through explicit legacy-key lookup.
- Do not automatically select BYOK merely because a key exists; preserve the user’s selected backend.
- AppFoundation provider presets may evolve, but app-owned preferred model values should remain explicit.
- Adding a provider preset must not require adding a new enum case.

## Security and privacy requirements

- Never log API keys, proxy app keys, raw App Attest assertions, StoreKit JWS values, menu OCR text, DraftX draft text, or provider response bodies by default.
- Direct-provider diagnostics may include provider ID, model ID, HTTP status, and normalized error code only.
- Keychain credentials remain this-device-only.
- Managed app keys remain build configuration secrets.
- UI copy must clearly distinguish managed AI from direct BYOK routing.
- MenuLens must identify that recognized menu text is sent directly to the selected provider when BYOK is active.
- DraftX must identify that draft text is sent directly to the selected provider when BYOK is active.
- AppFoundation must not claim that direct providers offer server-side quota, idempotency, or entitlement enforcement.

## Acceptance criteria

The shared infrastructure is complete when:

1. `AppAIClient` remains the single managed-AI client for both apps.
2. DraftX and MenuLens can each expose managed AI plus an app-selected subset of BYOK providers.
3. Both apps use the same credential store, provider clients, model preferences, connection testing, and reusable provider UI pieces.
4. DraftX retains all writing-specific prompts, workflows, candidate parsing, results, and history.
5. MenuLens retains OCR, menu contracts, schema, validation, persistence, and safety copy.
6. Direct providers support text and structured JSON without importing app domain types.
7. Managed and direct retry guarantees are represented explicitly and handled safely.
8. Existing DraftX user keys and model choices survive migration.
9. MenuLens does not upload menu images in its initial BYOK flow.
10. Unit tests cover storage, provider transports, backend management, error normalization, and both consumer contracts.

## Final boundary

AppFoundation owns:

- secure AI transport infrastructure;
- managed proxy communication;
- App Attest and entitlement synchronization;
- direct provider clients;
- BYOK credential storage;
- provider/model preferences;
- backend catalogs and selection;
- neutral status coordination;
- small reusable configuration and usage views.

DraftX and MenuLens own:

- app prompts and capability mapping;
- typed domain input/output contracts;
- product validation;
- persistence and recovery workflows;
- user-facing product copy;
- monetization decisions;
- the final mapping from AI output into app behavior.

This is the intended rule for future apps as well:

> AppFoundation owns how the app reaches AI. The app owns what AI is asked to do and what the answer means.
