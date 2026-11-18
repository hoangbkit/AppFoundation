# Analytics

`AppFoundation` includes a lightweight first-party analytics client for the native `/v1/analytics/batch` contract in `analytics-server`.

It is intentionally small: apps explicitly record their own product events while the foundation handles stable installation identity, foreground session accounting, local cumulative counters, bounded offline storage, and batched uploads. When `.managesAnalytics(...)` is installed, AppFoundation-owned purchase surfaces may also reuse that same optional client for a small bounded commerce funnel.

## Server requirements

Register the app in `analytics-server` with the `ios` platform enabled. `AppAnalyticsClient` supports an optional native app key and intentionally does not send App Attest data. If the server requires native app-key authentication, configure `appKey`; otherwise the SDK omits `X-App-Key` entirely.

The native request uses:

- `X-App-ID`
- `X-App-Key` when `appKey` is configured
- `X-Installation-ID`
- `X-Request-ID`
- `X-App-Version` when available
- `X-App-Build` when available

No StoreKit transaction, entitlement, or App Attest assertion is sent with analytics.

## Setup

Create one client at app scope:

```swift
private let analytics = AppAnalyticsClient(
    configuration: AppAnalyticsConfiguration(
        appID: "my-app",
        baseURL: URL(string: "https://api.example.com")!
    )
)
```

When the server requires a native key, pass it explicitly:

```swift
AppAnalyticsConfiguration(
    appID: "my-app",
    appKey: "your-native-app-key",
    baseURL: URL(string: "https://api.example.com")!
)
```

Attach lifecycle management to the main app content:

```swift
ContentView()
    .managesAnalytics(analytics)
```

The modifier also places that same optional app-scoped client into AppFoundation's SwiftUI environment. If analytics is not configured, package-owned views remain silent and fully functional.

To keep analytics integrated while disabling collection and uploads, set `enabled: false`:

```swift
AppAnalyticsConfiguration(
    appID: "my-app",
    baseURL: URL(string: "https://api.example.com")!,
    enabled: false
)
```

Disabled analytics is fully inert: event/error tracking, lifecycle accounting, opportunistic uploads, and explicit `flush()` calls are no-ops. No analytics state is read or written, and no installation identity is created while disabled. Previously persisted analytics state remains untouched and is not uploaded until analytics is enabled again; `resetLocalState()` remains available if the app wants to discard that state explicitly. The default is `enabled: true`.

To change this at runtime — for example from a settings toggle — call `setEnabled` on the existing client:

```swift
await analytics.setEnabled(false)  // user opted out
await analytics.setEnabled(true)   // user opted back in
```

The modifier keeps observing the same client, so there is no need to reinstall `.managesAnalytics(...)`. Disabling takes effect immediately, performs no final upload, and **clears locally pending analytics state** (unlike a client created with `enabled: false`, which leaves existing state untouched). The installation identity is not changed. Re-enabling resumes with a clean local slate.

### Automatic Pro paywall events

The canonical `ProPaywallView` records only this bounded commerce funnel when the shared analytics client is present:

- `paywall_viewed`
- `paywall_closed`
- `paywall_plan_selected` with `monthly`, `yearly`, `recurring`, or `lifetime`
- `purchase_started`, `purchase_succeeded`, `purchase_pending`, or `purchase_cancelled` with the same bounded plan dimension
- `purchase_failed` using `<plan>:<PurchaseFailure.Code>`
- `restore_started`, `restore_succeeded`, `restore_nothing_to_restore`, or `restore_failed`

The paywall never sends product identifiers, StoreKit transaction identifiers, prices, receipts, localized error messages, or user content.

On iOS, lifecycle tracking uses `UIApplication.didBecomeActiveNotification`, `UIApplication.willResignActiveNotification`, and `UIApplication.didEnterBackgroundNotification`. It is application-level rather than view-level, so navigation and scene content changes inside the active app do not end a session. A short background execution assertion is held from `willResignActive` until the background upload finishes; it does not post a user notification or require any background mode. Apps that do not use `.managesAnalytics(...)` (for example, UIKit-only apps) can call `applicationDidEnterBackground()` from their own background callback.

## Events

Events are explicit:

```swift
try await analytics.track("export_completed")
try await analytics.track("generation_completed", dimension: "nano")
try await analytics.track("purchase_started", dimension: "yearly")
```

Event names must be lowercase snake case. Dimensions use the server-safe character set and are intended for bounded categories such as model, plan, feature, or export type. Do not put free-form user content, prompts, filenames, email addresses, or other high-cardinality/private values in dimensions.


## Native context

Each daily iOS snapshot automatically includes bounded runtime context when available:

- `osVersion` — for example `26.0.1`
- `appBuild` — `CFBundleVersion`
- `deviceFamily` — for example `iphone` or `ipad`
- `architecture` — `arm64` or `x86_64`

`appVersion` continues to come from the explicit configuration override or `CFBundleShortVersionString`.

These values are stored with the local daily snapshot so offline uploads preserve the context associated with that day. AppFoundation does not collect a hardware model, serial number, device name, storage size, or other hardware fingerprint.

## Errors

Use the dedicated bounded error stream for stable product diagnostics:

```swift
try await analytics.trackError(
    "model_load_failed",
    component: "generation"
)

try await analytics.trackError(
    "unexpected_termination",
    component: "app",
    severity: .fatal
)
```

Error `code` and `component` must be lowercase snake case. Severity is `.error` or `.fatal`. Counters are cumulative per UTC day, using the same retry-safe semantics as normal events.

Do not send exception messages, `localizedDescription`, stack traces, filesystem paths, URLs, prompts, filenames, or arbitrary metadata as error identifiers. Map failures to a small stable vocabulary such as `model_load_failed`, `database_open_failed`, or `export_failed`.

## Sessions

A session starts when the application becomes active. If the app becomes active again within 30 minutes, the existing session resumes; after a longer gap, a new session is counted.

Only active application time contributes to `sessionSeconds`. Time while the app is inactive is excluded.

## Upload behavior

The client stores cumulative UTC-day snapshots locally and uploads opportunistically. Defaults are aligned with the server contract:

- 20-second upload interval
- 7 UTC days per batch
- 6-day offline age plus the current day
- 50 event/dimension counters per day
- 100 event counters per batch
- 500 maximum occurrences per event/day
- 2,000 total event occurrences per day
- 20 error counters per day
- 140 error counters per batch
- 100 total error occurrences per day
- 1,000 sessions per day
- 86,400 session seconds per day
- 32 KiB maximum request body
- 1 transport retry

There are three upload tiers:

- **Opportunistic** — tracking and lifecycle calls attempt an upload at most once per `uploadInterval` (20 seconds by default).
- **Background** — entering the background calls `applicationDidEnterBackground()`, which bypasses `uploadInterval` so the latest activity is uploaded promptly. It skips the request when no local data changed since the last successful upload, and still respects the server's `Retry-After` window.
- **Explicit** — call `flush()` when the upload operation should surface an error:

  ```swift
  try await analytics.flush()
  ```

  This bypasses both the interval and the backoff.

All automatic uploads are best effort: tracking, lifecycle, and background calls suppress upload errors so analytics cannot block normal product behavior.

The server stores cumulative snapshots using retry-safe maximum semantics. The client therefore keeps the current UTC day cumulative and may safely resend it. Successful historical days are removed locally after acceptance.

If the server returns HTTP `429 rate_limited`, opportunistic and background uploads persist and respect the server's `Retry-After` window before trying again. Events continue accumulating locally during that backoff. Explicit `flush()` bypasses the opportunistic schedule and surfaces the server error to the caller.

## Installation identity

The client creates a random installation UUID and, by default, stores it in Keychain under `<appID>.installation`. The opaque identifier is sent to `analytics-server` so cumulative snapshots from the same app installation can be associated. It is an installation identifier, not a human identity.

To keep **all** analytics data in memory — both the installation ID and the daily counters — opt in explicitly:

```swift
let analytics = AppAnalyticsClient(
    configuration: AppAnalyticsConfiguration(
        appID: "my-app",
        baseURL: URL(string: "https://api.example.com")!,
        storageMode: .inMemory
    )
)
```

`storageMode` defaults to `.persisted`, which is the behavior described above. In `.inMemory` mode the client generates a random UUID on first upload and holds it for that client instance only; it never reads or writes the Keychain, and daily counters are held in `InMemoryAppAnalyticsStateStore` rather than `UserDefaults`. Nothing analytics-related survives process death: a new client instance gets a new ID and empty counters, while repeated uploads from the same client stay consistent. `resetLocalState()` and `setEnabled(false)` clear the in-memory state; the installation ID itself is kept until the client is deallocated.

The default Keychain service is:

```text
com.hoangbkit.AppFoundation.AppAI
```

This intentionally matches `AppAIClient`, so an app using the default configuration reuses the same app-scoped installation identity. Analytics requests themselves remain independent and do not use the App AI client's App Attest path. Override `keychainService` when an app needs a separate identity namespace.

## Local state

Daily counters use `UserDefaults` with the default `.persisted` storage mode. `.inMemory` mode uses `InMemoryAppAnalyticsStateStore` instead, so nothing is written to disk. Supply your own `AppAnalyticsStateStoring` implementation through the injecting initializer when the app needs a different local store or deterministic tests; an explicitly supplied store is used regardless of `storageMode`.

To clear local counters without changing the installation identity:

```swift
try await analytics.resetLocalState()
```

Corrupt local analytics state is discarded safely rather than crashing the app. In `.persisted` mode the installation identity remains in Keychain and is not affected by `resetLocalState()`.

## Cross-package parity

`AppFoundation` and `MacAppFoundation` intentionally expose the same analytics configuration, client, transport, state-storage, error-stream, retry/backoff, batching, retention, validation, native-context, and cumulative-snapshot semantics.

The platform-specific differences are limited to:

- `AppFoundation` sends `platform: ios`, reports the iOS device family, and observes iOS application lifecycle notifications;
- `MacAppFoundation` sends `platform: macos`, reports `deviceFamily: mac`, and observes macOS application lifecycle notifications;
- each package has its own default persistence namespace, while AppFoundation intentionally shares its default Keychain installation namespace with `AppAIClient`.

## Privacy boundary

The client automatically collects only the bounded native context documented above: OS version, app build, device family, and CPU architecture. It does not collect screen names, text content, hardware model, serial number, device name, IP addresses, contacts, files, prompts, exception text, stack traces, or purchase receipts. Apps decide which bounded event names, dimensions, and error codes to record.

Review each shipping app's App Privacy answers and privacy policy based on the events that app actually sends; adding this package does not make every possible analytics field appropriate to collect.
