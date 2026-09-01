# Startup Resilience

`StartupResilience` helps an app launch into the safest usable state it can construct without making AppFoundation responsible for the app's persistence model.

The default philosophy is simple:

> Prefer repair and explicit safe fallback over blocking startup. Preserve user-owned data. Show full-screen recovery only when a required component exhausts every configured recovery path.

## What AppFoundation owns

- Ordered startup orchestration
- Required, important, and optional component criticality
- Load → repair → retry → fallback execution
- Structured diagnostics and per-component results
- Degraded-but-ready reporting
- A neutral last-resort `StartupRecoveryView`

## What the app owns

- Database and file formats
- Schema versions and migrations
- Repair algorithms
- Quarantine or backup locations
- Deciding whether an empty/rebuilt state is safe
- Telemetry and logging
- Branding and user-facing copy
- Destructive reset behavior

AppFoundation never deletes local data automatically.

## Component policy

Each `StartupComponent` declares an operation and optional recovery paths:

```swift
let projects = StartupComponent(
    id: "projects",
    name: "Projects",
    criticality: .important,
    operation: {
        try await projectStore.load()
    },
    repair: {
        try await projectStore.repairIndex()
    },
    fallback: {
        try await projectStore.startWithEmptyIndex()
    }
)
```

Execution is deterministic:

1. Run `operation`.
2. If it fails and `repair` exists, run repair.
3. Retry the original operation after successful repair.
4. If loading still fails and `fallback` exists, run fallback.
5. If all paths fail:
   - `required` stops startup.
   - `important` and `optional` are skipped and startup continues in a degraded state.

Use non-required criticality only when the app is genuinely safe without that component.

## Running startup

```swift
let report = await StartupResilience.run([
    primaryDatabase,
    projects,
    searchIndex,
])

switch report.readiness {
case .ready:
    showApp()

case .degraded:
    // Usually launch normally. Log or surface a quiet notice only when useful.
    showApp()

case .failed(let failure):
    showRecovery(failure)
}
```

A progress callback is available for apps that want a startup indicator:

```swift
let report = await StartupResilience.run(components) { progress in
    await startupModel.update(progress)
}
```

## Choosing criticality

### `required`

Use when the app cannot construct a safe usable state without the component. A required component may still return a degraded launch if its explicit fallback succeeds.

Examples:

- Primary user database in a data-centric app
- Encryption material needed to interpret all stored content

### `important`

Use when loss of the component reduces functionality but the app remains safe to use.

Examples:

- Search index
- Downloaded catalog that can be fetched later
- Secondary workspace

### `optional`

Use for components users should generally never know failed.

Examples:

- Derived caches
- Thumbnail metadata
- Nonessential analytics state

## Recovery principles

### Prefer derived-data rebuilds

If data can be recreated from a source of truth, rebuild it silently and continue.

### Preserve before replacing

For user-owned persisted data, copy or quarantine the original before an app-owned fallback replaces the live store.

### Do not turn decode failure into delete

A failed decode is evidence that the app does not understand the data. It is not permission to erase it.

### Keep recovered failures quiet

If repair succeeds or an optional cache is rebuilt, the user usually does not need an alert.

### Make fallback explicit

`fallback` means the app developer has decided the fallback state is safe. AppFoundation does not invent empty stores or delete files on an app's behalf.

## Last-resort recovery UI

`StartupRecoveryView` is intentionally not the normal startup experience. It is for an exhausted required component.

```swift
StartupRecoveryView(
    configuration: StartupRecoveryConfiguration(
        title: "We Couldn't Open Your Data",
        message: "The app couldn't finish preparing its local data safely.",
        dataSafetyMessage: "Your existing data has not been deleted."
    ),
    retry: {
        await restartStartup()
    },
    makeRecoveryCopy: {
        try await recoveryExporter.makeCopy()
    },
    startFresh: {
        try await localStorage.resetAfterBackup()
    }
)
```

The primary screen emphasizes retry. Recovery-copy and start-fresh actions are progressively disclosed under Recovery Options. Both secondary actions are optional.

`makeRecoveryCopy` returns an `ExportFile`; AppFoundation presents the standard share sheet. `startFresh` is always app-owned and receives a destructive confirmation before execution.

## Recommended indie-app policy

For apps maintained by a small team or solo developer:

- Make startup self-healing wherever the repair is deterministic.
- Treat caches and indexes as optional.
- Let secondary features degrade instead of blocking launch.
- Preserve damaged user data locally before replacing it.
- Avoid support-oriented UI unless the app actually offers support.
- Keep the recovery screen to Try Again, optional Save a Recovery Copy, and optional Start Fresh.
- Use diagnostics primarily for logs and debugging rather than exposing technical migration terminology to users.

## Demo

The iOS Demo exposes **New APIs → Startup resilience** with four deterministic scenarios:

- Healthy
- Auto-repaired
- Safe fallback / degraded
- Fatal required component

The fatal scenario presents the real `StartupRecoveryView`, including recovery-copy export and simulated start-fresh behavior.
