import Foundation

public struct BackupEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let format: String
    public let version: Int
    public let appIdentifier: String
    public let appVersion: String
    public let appBuild: String
    public let createdAt: Date
    public let payload: Payload
    public let metadata: [String: String]

    public init(
        format: String,
        version: Int,
        appIdentifier: String,
        appVersion: String,
        appBuild: String,
        createdAt: Date = .now,
        payload: Payload,
        metadata: [String: String] = [:]
    ) {
        self.format = format
        self.version = version
        self.appIdentifier = appIdentifier
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.createdAt = createdAt
        self.payload = payload
        self.metadata = metadata
    }
}

public struct BackupAsset: Sendable, Equatable {
    public let relativePath: String
    public let data: Data

    public init(relativePath: String, data: Data) {
        self.relativePath = relativePath
        self.data = data
    }
}

public struct BackupPackageConfiguration: Sendable, Equatable {
    public let format: String
    public let version: Int
    public let supportedVersions: ClosedRange<Int>
    public let appIdentifier: String
    public let fileExtension: String

    public init(
        format: String,
        version: Int,
        supportedVersions: ClosedRange<Int>? = nil,
        appIdentifier: String,
        fileExtension: String
    ) {
        self.format = format
        self.version = version
        self.supportedVersions = supportedVersions ?? version...version
        self.appIdentifier = appIdentifier
        self.fileExtension = fileExtension
    }
}

public struct BackupPackageManifest: Codable, Sendable, Equatable {
    public let format: String
    public let version: Int
    public let appIdentifier: String
    public let appVersion: String
    public let appBuild: String
    public let createdAt: Date
    public let payloadChecksum: String
    public let assetPaths: [String]
}

public struct BackupReadResult<Payload: Sendable>: Sendable {
    public let manifest: BackupPackageManifest
    public let payload: Payload
    public let assets: [String: Data]
}

public enum BackupError: Error, Sendable, Equatable {
    case invalidFormat
    case unsupportedVersion(Int)
    case wrongApplication(String)
    case missingManifest
    case missingPayload
    case corruptPayload
    case checksumMismatch
    case unsafeAssetPath(String)
    case fileOperationFailed(String)
}

public enum BackupChecksum {
    /// Stable FNV-1a checksum used for accidental-corruption detection.
    public static func value(for data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}

public actor BackupPackageWriter {
    private let fileManager: FileManager
    private let encoder: JSONEncoder

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func write<Payload: Codable & Sendable>(
        envelope: BackupEnvelope<Payload>,
        configuration: BackupPackageConfiguration,
        assets: [BackupAsset] = [],
        destinationDirectory: URL = FileManager.default.temporaryDirectory,
        filename: String = "Backup"
    ) throws -> URL {
        guard envelope.format == configuration.format else { throw BackupError.invalidFormat }
        guard configuration.supportedVersions.contains(envelope.version) else {
            throw BackupError.unsupportedVersion(envelope.version)
        }
        guard envelope.appIdentifier == configuration.appIdentifier else {
            throw BackupError.wrongApplication(envelope.appIdentifier)
        }

        for asset in assets where !Self.isSafe(relativePath: asset.relativePath) {
            throw BackupError.unsafeAssetPath(asset.relativePath)
        }

        let safeName = ExportFilename.sanitized(filename, fallback: "Backup")
        let staging = destinationDirectory.appendingPathComponent(".backup-\(UUID().uuidString)", isDirectory: true)
        let finalURL = destinationDirectory
            .appendingPathComponent("\(safeName)-\(UUID().uuidString)", isDirectory: true)
            .appendingPathExtension(configuration.fileExtension)

        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            let payloadData = try encoder.encode(envelope.payload)
            try payloadData.write(to: staging.appendingPathComponent("payload.json"), options: .atomic)

            if !assets.isEmpty {
                let assetsRoot = staging.appendingPathComponent("assets", isDirectory: true)
                try fileManager.createDirectory(at: assetsRoot, withIntermediateDirectories: true)
                for asset in assets {
                    let target = assetsRoot.appendingPathComponent(asset.relativePath)
                    try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try asset.data.write(to: target, options: .atomic)
                }
            }

            let manifest = BackupPackageManifest(
                format: envelope.format,
                version: envelope.version,
                appIdentifier: envelope.appIdentifier,
                appVersion: envelope.appVersion,
                appBuild: envelope.appBuild,
                createdAt: envelope.createdAt,
                payloadChecksum: BackupChecksum.value(for: payloadData),
                assetPaths: assets.map(\.relativePath).sorted()
            )
            try encoder.encode(manifest).write(
                to: staging.appendingPathComponent("manifest.json"),
                options: .atomic
            )
            try fileManager.moveItem(at: staging, to: finalURL)
            return finalURL
        } catch let error as BackupError {
            try? fileManager.removeItem(at: staging)
            throw error
        } catch {
            try? fileManager.removeItem(at: staging)
            throw BackupError.fileOperationFailed(error.localizedDescription)
        }
    }

    private static func isSafe(relativePath: String) -> Bool {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/"), !relativePath.contains("\\") else { return false }
        return !relativePath.split(separator: "/").contains("..")
    }
}

public actor BackupPackageReader {
    private let fileManager: FileManager
    private let decoder: JSONDecoder

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func read<Payload: Codable & Sendable>(
        _ type: Payload.Type,
        from packageURL: URL,
        configuration: BackupPackageConfiguration
    ) throws -> BackupReadResult<Payload> {
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        let payloadURL = packageURL.appendingPathComponent("payload.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else { throw BackupError.missingManifest }
        guard fileManager.fileExists(atPath: payloadURL.path) else { throw BackupError.missingPayload }

        do {
            let manifest = try decoder.decode(BackupPackageManifest.self, from: Data(contentsOf: manifestURL))
            guard manifest.format == configuration.format else { throw BackupError.invalidFormat }
            guard configuration.supportedVersions.contains(manifest.version) else {
                throw BackupError.unsupportedVersion(manifest.version)
            }
            guard manifest.appIdentifier == configuration.appIdentifier else {
                throw BackupError.wrongApplication(manifest.appIdentifier)
            }

            let payloadData = try Data(contentsOf: payloadURL)
            guard BackupChecksum.value(for: payloadData) == manifest.payloadChecksum else {
                throw BackupError.checksumMismatch
            }
            let payload: Payload
            do { payload = try decoder.decode(Payload.self, from: payloadData) }
            catch { throw BackupError.corruptPayload }

            var assets: [String: Data] = [:]
            for path in manifest.assetPaths {
                guard BackupPathValidator.isSafe(path) else { throw BackupError.unsafeAssetPath(path) }
                let url = packageURL.appendingPathComponent("assets").appendingPathComponent(path)
                assets[path] = try Data(contentsOf: url)
            }
            return BackupReadResult(manifest: manifest, payload: payload, assets: assets)
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.fileOperationFailed(error.localizedDescription)
        }
    }
}

private enum BackupPathValidator {
    static func isSafe(_ relativePath: String) -> Bool {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/"), !relativePath.contains("\\") else { return false }
        return !relativePath.split(separator: "/").contains("..")
    }
}
