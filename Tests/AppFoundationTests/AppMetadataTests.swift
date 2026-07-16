import XCTest
@testable import AppFoundation

final class AppMetadataTests: XCTestCase {
    func testVersionAndBuildFormatting() {
        let metadata = AppMetadata(name: "Demo", version: "2.1", build: "42")
        XCTAssertEqual(metadata.versionAndBuild, "2.1 (42)")
    }
}
