# Analytics

`AppFoundation` includes a first-party native analytics client that follows the same privacy-oriented v1 contract as `web-app-foundation`.

It records only cumulative daily product metrics:

- session count;
- active session duration;
- bounded event counters;
- one optional short token-like dimension per event;
- app version and native platform.

It does not collect prompts, generated content, filenames, URLs, contacts, location, advertising identifiers, device fingerprints, or arbitrary event properties.

## Setup

Use the same `AppAIClientConfiguration` that the app already uses for the shared backend. This deliberately reuses the app-scoped installation identity, app key, and App Attest policy.

```swift
let analytics = AppAnalytics(
    configuration: AppAIClientConfiguration(
        appID: "my-app",
        appKey: appKey,
        baseURL: URL(string: "https://api.example.com")!,
        attestationPolicy: .preferred
    ),
    appVersion: "1.5.0"
)

await analytics.start()
```

`start()` begins native lifecycle/session tracking and a best-effort periodic flush loop. Keep the `AppAnalytics` instance alive for the lifetime of the app.

Call `stop()` only when the host intentionally tears down the analytics service:

```swift
await analytics.stop()
```

## Events

Track only small product-action counters that are useful for product decisions:

```swift
await analytics.track("paywall_viewed")
await analytics.track("generation_completed", dimension: "nano")
await analytics.track("export_completed", dimension: "pdf")
```

Event names must be lowercase snake_case, start with a lowercase ASCII letter, and be at most 48 characters. Invalid event names are ignored.

Dimensions are optional, trimmed, capped at 64 ASCII token characters, and may contain letters, numbers, `.`, `_`, `:`, `/`, `+`, and `-`. Invalid dimensions are dropped while the event itself is still counted.

Never place user-entered text, email addresses, prompts, messages, generated content, filenames, full URLs, or other personal/content data in event names or dimensions.

## Session semantics

The native client mirrors the server contract:

- a session begins on the first active event after there is no current session;
- 30 minutes of inactivity ends the session;
- background/inactive time is not counted as active duration;
- sessions are attributed to the UTC day on which they start;
- active duration crossing UTC midnight is split between the two UTC days.

On iOS, `start()` observes application active/inactive/background notifications automatically. A background transition settles active duration and attempts a best-effort flush.

## Storage and retry behavior

Analytics state is stored locally as cumulative daily snapshots. The default store uses `UserDefaults` with an app-scoped key. A custom `AppAnalyticsStorage` can be supplied when an app needs a different persistence location.

The client retains at most seven UTC days and enforces the same v1 bounds used by the server:

- 50 distinct event/dimension counters per day;
- 100 distinct counters per batch;
- 100,000 maximum count per event/day;
- 1,000 sessions per day;
- 86,400 active seconds per day.

Dirty snapshots are flushed no more than once per minute. Failed uploads remain local and are retried later. Successful uploads do not clear the cumulative snapshots; the server uses monotonic upserts so retries and later larger snapshots remain idempotent.

## Native security path

Uploads are sent to:

```text
POST /v1/analytics/batch
```

through the existing `AppAIClient` protected POST path. Requests therefore use the same:

```text
X-App-ID
X-App-Key
X-Installation-ID
```

and the same App Attest policy as other native backend requests. The App Attest assertion is bound to the exact analytics request ID, method, path, and encoded body.

This is intentional: native analytics must not create a second installation identity or a telemetry-specific attestation bypass.

## Inspecting a snapshot

`buildBatch(now:)` exposes the current cumulative batch for diagnostics and tests without sending it:

```swift
if let batch = await analytics.buildBatch() {
    print(batch.days)
}
```

Do not use this as an event log. The batch is aggregated state only.
