# Demo app

This example is generated with XcodeGen and consumes the local `AppFoundation` package.

## Generate and run

```bash
brew install xcodegen
cd Examples/Demo
make open
```

The shared `Demo` scheme automatically uses `Demo/Configuration.storekit`, so the monthly and yearly subscription products can be tested without App Store Connect.

## Project identity

- Deployment target: iOS 26.0
- Development team: `J458WW3452`
- Bundle identifier: `com.hoangbkit.appfoundationdemo`

The generated `.xcodeproj` is intentionally ignored. Treat `project.yml` as the source of truth.
