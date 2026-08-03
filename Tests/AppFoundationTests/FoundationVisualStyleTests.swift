import Foundation
import XCTest
@testable import AppFoundation

private func requireSendable<T: Sendable>(_: T.Type) {}

final class FoundationVisualStyleTests: XCTestCase {
    func testStyleIsSendable() {
        requireSendable(FoundationVisualStyle.self)
    }

    func testSignaturePreservesAutomaticCompatibilityDefaults() {
        XCTAssertEqual(FoundationVisualStyle(), .signature)
        XCTAssertEqual(FoundationVisualStyle.signature.background, .automatic)
        XCTAssertEqual(FoundationVisualStyle.signature.surface, .automatic)
        XCTAssertEqual(FoundationVisualStyle.signature.elevation, .automatic)
        XCTAssertEqual(FoundationVisualStyle.signature.primaryAction, .automatic)
        XCTAssertEqual(FoundationVisualStyle.signature.navigationChrome, .automatic)
        XCTAssertNil(FoundationVisualStyle.signature.cornerRadius)
    }

    func testNativeRemovesAtmosphericAndFloatingTreatments() {
        XCTAssertEqual(FoundationVisualStyle.native.background, .systemGrouped)
        XCTAssertEqual(FoundationVisualStyle.native.surface, .solid)
        XCTAssertEqual(FoundationVisualStyle.native.elevation, .none)
        XCTAssertEqual(FoundationVisualStyle.native.primaryAction, .system)
        XCTAssertEqual(FoundationVisualStyle.native.navigationChrome, .system)
        XCTAssertEqual(FoundationVisualStyle.native.cornerRadius, 12)
    }

    func testFlatUsesSolidSurfacesWithoutElevation() {
        XCTAssertEqual(FoundationVisualStyle.flat.background, .solid)
        XCTAssertEqual(FoundationVisualStyle.flat.surface, .solid)
        XCTAssertEqual(FoundationVisualStyle.flat.elevation, .none)
        XCTAssertEqual(FoundationVisualStyle.flat.primaryAction, .filled)
        XCTAssertEqual(FoundationVisualStyle.flat.navigationChrome, .system)
        XCTAssertEqual(FoundationVisualStyle.flat.cornerRadius, 10)
    }

    func testGlassUsesMaterialAndTransparentChrome() {
        XCTAssertEqual(FoundationVisualStyle.glass.background, .atmospheric)
        XCTAssertEqual(FoundationVisualStyle.glass.surface, .material)
        XCTAssertEqual(FoundationVisualStyle.glass.elevation, .subtle)
        XCTAssertEqual(FoundationVisualStyle.glass.primaryAction, .monochrome)
        XCTAssertEqual(FoundationVisualStyle.glass.navigationChrome, .transparent)
        XCTAssertEqual(FoundationVisualStyle.glass.cornerRadius, 26)
    }

    func testCustomNegativeCornerRadiusIsClamped() {
        let style = FoundationVisualStyle(cornerRadius: -8)
        XCTAssertEqual(style.cornerRadius, 0)
    }

    func testStyleRoundTripsThroughCodable() throws {
        let data = try JSONEncoder().encode(FoundationVisualStyle.glass)
        let decoded = try JSONDecoder().decode(FoundationVisualStyle.self, from: data)
        XCTAssertEqual(decoded, .glass)
    }
}
