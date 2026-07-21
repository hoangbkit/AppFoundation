import Foundation
import XCTest
@testable import AppFoundation

final class InfrastructureTests: XCTestCase {
    func testExistingContentRemainsAccessibleAfterExpiry() {
        let feature = PremiumFeature(id: "themes", title: "Premium themes")
        let policy = PremiumAccessPolicy()

        XCTAssertEqual(
            policy.decision(
                for: feature,
                requirement: .pro,
                hasPro: false,
                isExistingContent: true
            ),
            .allowed
        )
        XCTAssertEqual(
            policy.decision(for: feature, requirement: .pro, hasPro: false),
            .requiresPro(feature: feature)
        )
    }

    func testExportFilenameSanitizesUnsafeCharacters() {
        XCTAssertEqual(ExportFilename.sanitized("Mi/Love: Hero\n"), "Mi-Love- Hero-")
        XCTAssertEqual(ExportFilename.sanitized("   "), "Export")
    }

    func testBackupPackageRoundTrip() async throws {
        struct Payload: Codable, Sendable, Equatable {
            let name: String
            let count: Int
        }

        let configuration = BackupPackageConfiguration(
            format: "test.backup",
            version: 1,
            appIdentifier: "com.example.test",
            fileExtension: "testbackup"
        )
        let envelope = BackupEnvelope(
            format: configuration.format,
            version: 1,
            appIdentifier: configuration.appIdentifier,
            appVersion: "1.0",
            appBuild: "1",
            payload: Payload(name: "Hello", count: 2)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try await BackupPackageWriter().write(
            envelope: envelope,
            configuration: configuration,
            assets: [
                BackupAsset(
                    relativePath: "images/one.bin",
                    data: Data([1, 2, 3])
                )
            ],
            destinationDirectory: directory
        )
        let result = try await BackupPackageReader().read(
            Payload.self,
            from: url,
            configuration: configuration
        )

        XCTAssertEqual(result.payload, envelope.payload)
        XCTAssertEqual(result.assets["images/one.bin"], Data([1, 2, 3]))
    }

    func testBackupRejectsUnsafeAssetPath() async throws {
        struct Payload: Codable, Sendable { let value: Int }
        let configuration = BackupPackageConfiguration(
            format: "test.backup",
            version: 1,
            appIdentifier: "com.example.test",
            fileExtension: "testbackup"
        )
        let envelope = BackupEnvelope(
            format: configuration.format,
            version: 1,
            appIdentifier: configuration.appIdentifier,
            appVersion: "1.0",
            appBuild: "1",
            payload: Payload(value: 1)
        )

        do {
            _ = try await BackupPackageWriter().write(
                envelope: envelope,
                configuration: configuration,
                assets: [BackupAsset(relativePath: "../escape.bin", data: Data())]
            )
            XCTFail("Expected unsafe path rejection")
        } catch let error as BackupError {
            XCTAssertEqual(error, .unsafeAssetPath("../escape.bin"))
        }
    }

    func testReviewRequestPolicy() {
        let policy = ReviewRequestPolicy(
            minimumMeaningfulActions: 3,
            minimumDaysBetweenRequests: 30
        )
        let now = Date(timeIntervalSince1970: 4_000_000)

        XCTAssertFalse(
            policy.shouldRequest(
                meaningfulActionCount: 2,
                lastRequestDate: nil,
                now: now
            )
        )
        XCTAssertTrue(
            policy.shouldRequest(
                meaningfulActionCount: 3,
                lastRequestDate: nil,
                now: now
            )
        )
        XCTAssertFalse(
            policy.shouldRequest(
                meaningfulActionCount: 3,
                lastRequestDate: now.addingTimeInterval(-10 * 86_400),
                now: now
            )
        )
        XCTAssertTrue(
            policy.shouldRequest(
                meaningfulActionCount: 3,
                lastRequestDate: now.addingTimeInterval(-31 * 86_400),
                now: now
            )
        )
    }

    func testSharedDeepLink() {
        let link = SharedDeepLink(
            scheme: "milove",
            host: "event",
            pathComponents: ["123"]
        )
        XCTAssertEqual(link.url?.absoluteString, "milove://event/123")
    }
}
