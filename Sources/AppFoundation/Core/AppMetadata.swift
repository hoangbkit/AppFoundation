import Foundation

public struct AppMetadata: Sendable, Equatable {
    public let name: String
    public let version: String
    public let build: String

    public init(name: String, version: String, build: String) {
        self.name = name
        self.version = version
        self.build = build
    }

    public static func current(bundle: Bundle = .main) -> AppMetadata {
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "App"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        return AppMetadata(name: name, version: version, build: build)
    }

    public var versionAndBuild: String {
        "\(version) (\(build))"
    }
}
