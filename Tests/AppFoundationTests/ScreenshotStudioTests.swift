import Testing
@testable import AppFoundation

@Suite("Screenshot Studio")
struct ScreenshotStudioTests {
  @Test("Built-in iPhone preset uses exact App Store pixels")
  func iPhonePresetDimensions() {
    let preset = ScreenshotDevicePreset.iPhone69Portrait

    #expect(preset.pixelSize == ScreenshotPixelSize(width: 1320, height: 2868))
    #expect(preset.pointWidth == 440)
    #expect(preset.pointHeight == 956)
  }

  @Test("Landscape preset swaps dimensions and preserves scale")
  func landscapePreset() {
    let portrait = ScreenshotDevicePreset.iPad13Portrait
    let landscape = portrait.landscape()

    #expect(landscape.pixelSize.width == portrait.pixelSize.height)
    #expect(landscape.pixelSize.height == portrait.pixelSize.width)
    #expect(landscape.scale == portrait.scale)
    #expect(landscape.pixelSize.isLandscape)
  }

  @Test("Export filenames are stable and safe")
  func safeFilenames() {
    let filename = ScreenshotFileName.filename(
      index: 2,
      baseName: "Beautiful Widgets!",
      presetID: "iPhone 6.9-inch"
    )

    #expect(filename == "02-beautiful-widgets-iphone-6-9-inch.png")
  }
}
