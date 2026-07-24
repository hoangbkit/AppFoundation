# Demo app

This example is generated with XcodeGen and consumes the local `AppFoundation` package.

## Generate and run

```bash
brew install xcodegen
cd Examples/Demo
make open
```

Debug deployments use live StoreKit by default. Explicitly opt in to AppFoundation's in-process purchase simulator with:

```bash
mycli deploy SE2 --billing simulated
```

Simulated purchases persist locally, and the Demo includes a reset button for repeated paywall testing.

The shared `Demo` Xcode scheme attaches `Demo/Configuration.storekit`, so Product > Run uses Xcode's StoreKit test environment with the default live provider.

To deploy with real StoreKit, omit the billing option or state it explicitly:

```bash
mycli deploy SE2
mycli deploy SE2 --billing live
```

## Project identity

- Deployment target: iOS 26.0
- Development team: `J458WW3452`
- Bundle identifier (iOS and macOS): `com.hoangbkit.afdemo`
- Display name (iOS and macOS): `AF`

The generated `.xcodeproj` is intentionally ignored. Treat `project.yml` as the source of truth.
