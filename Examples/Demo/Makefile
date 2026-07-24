.PHONY: bootstrap generate open test build-mac clean

bootstrap:
	@command -v xcodegen >/dev/null 2>&1 || brew install xcodegen

generate:
	xcodegen generate --spec project.yml

open: generate
	open Demo.xcodeproj

test: generate
	xcodebuild test \
		-project Demo.xcodeproj \
		-scheme Demo \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
		CODE_SIGNING_ALLOWED=NO

build-mac: generate
	xcodebuild build \
		-project Demo.xcodeproj \
		-scheme DemoMac \
		-destination 'platform=macOS' \
		CODE_SIGNING_ALLOWED=NO

clean:
	rm -rf Demo.xcodeproj .xcodegen ~/Library/Developer/Xcode/DerivedData/Demo-*
