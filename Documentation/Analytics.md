# App Analytics

`AppAnalyticsClient` provides small first-party product analytics for AppFoundation apps using the native `/v1/analytics/batch` contract in `ai-proxy-server`.

It is deliberately not a clickstream SDK. The client keeps a stable app-scoped installation ID, counts foreground sessions, accumulates a bounded set of product events locally, and uploads cumulative UTC-day snapshots only occasionally.

## Server requirements

Register the app in `ai-proxy-server` with analytics enabled and no web origins:

```yaml
- id: my-app
  bundleId: com.example.myapp
  teamId: YOUR_TEAM_ID
  enabled: true
  analytics:
    enabled: true
    webOrigins: []
  attestMode: disabled
  capabilities: []
  products: []
  creditProducts: []
```

Native analytics still requires an active app key. App Attest and commerce are independent: an analytics-only app may use `attestMode: disabled` and have no StoreKit products or AI capabilities.

## Configure the client

```swift
import AppFoundation

let analytics = AppAnalyticsClient(
    configuration: AppAnalyticsConfiguration(
        appID: "my-app",
        appKey: "your-native-app-key",
        baseURL: URL(string: "https://api.example.com")!
    )
)
```

The default Keychain service matches `AppAIClient`, so analytics and managed AI reuse the same `<appID>.installation` identity when both features are enabled. Analytics state itself is a small Codable snapshot in `UserDefaults` and contains counters only.

## Session tracking

Attach the lifecycle helper at the app root:

```swift
WindowGroup {
    RootView()
        .managesAnalytics(analytics)
}
```

A session uses the server contract's 30-minute inactivity timeout. Foreground time is accumulated as active duration; inactive/background time is excluded. Re-entering the app within 30 minutes resumes the same session.

## Product events

Track only a small, bounded set of meaningful events:

```swift
try? await analytics.track("generation_completed")
try? await analytics.track("generation_completed", dimension: "nano")
try? await analytics.track("export_completed")
```

Event names must be lowercase snake case. Dimensions are intentionally short scalar labels, not arbitrary properties. Do not send prompts, filenames, URLs, user-generated text, provider keys, or other content as event names or dimensions.

Counters are cumulative and monotonic for each UTC day. The client enforces the server limits before upload: at most 50 event/dimension counters per day, 100 counters per batch, seven days per batch, and the six-day offline age window.

## Upload behavior

The default upload interval is six hours. Lifecycle changes and tracked events opportunistically call the due-check, but network failures are ignored by those automatic attempts so analytics never blocks the product flow.

For diagnostics or an explicit background flush:

```swift
try await analytics.flush()
```

`flush()` is the API that reports transport/server errors. Successful past-day snapshots are removed locally; the current day remains because later counters must continue from its cumulative values. Exact retries are safe because the server persists cumulative snapshots with monotonic upserts.

## Testing

Inject `AppAnalyticsTransport` to capture outgoing requests and `AppAnalyticsStateStoring` to replace `UserDefaults`:

```swift
let client = AppAnalyticsClient(
    configuration: configuration,
    transport: mockTransport,
    stateStore: memoryStore
)
```

The package tests cover the native batch contract, foreground session accounting, 30-minute session continuation, event validation, and installation-identity reuse with `AppAIClient`.

## Privacy

Analytics is opt-in at the app integration layer and does not automatically inspect screens or application models. The shared client sends only the app ID/key headers, an app-scoped random installation ID, app version/build metadata, session counters, and explicitly recorded bounded product events.

Apps using analytics are responsible for keeping their App Store privacy disclosures and app-level privacy policy consistent with the events they choose to record. Product-interaction analytics sent off-device should be reflected in the adopting app's privacy disclosures even when it is first-party and not used for tracking.
