#if canImport(SwiftUI) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
  import CoreGraphics
  import Foundation
  import ImageIO
  import SwiftUI
  import UniformTypeIdentifiers

  public enum ScreenshotStudioColorScheme: String, CaseIterable, Identifiable, Sendable {
    case light
    case dark

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    var swiftUIColorScheme: ColorScheme {
      switch self {
      case .light: .light
      case .dark: .dark
      }
    }
  }

  public struct ScreenshotExportedFile: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let screenshotID: String
    public let presetID: String
    public let pixelSize: ScreenshotPixelSize

    public init(
      id: UUID = UUID(),
      url: URL,
      screenshotID: String,
      presetID: String,
      pixelSize: ScreenshotPixelSize
    ) {
      self.id = id
      self.url = url
      self.screenshotID = screenshotID
      self.presetID = presetID
      self.pixelSize = pixelSize
    }
  }

  public enum ScreenshotStudioError: LocalizedError {
    case noRegisteredScreenshots
    case unsupportedPreset(screenshot: String, preset: String)
    case renderFailed(screenshot: String)
    case unexpectedPixelSize(expected: ScreenshotPixelSize, actual: ScreenshotPixelSize)
    case pngEncodingFailed(screenshot: String)

    public var errorDescription: String? {
      switch self {
      case .noRegisteredScreenshots:
        "No screenshots are registered for this catalog."
      case .unsupportedPreset(let screenshot, let preset):
        "\(screenshot) does not support the \(preset) preset."
      case .renderFailed(let screenshot):
        "The screenshot renderer could not render \(screenshot)."
      case .unexpectedPixelSize(let expected, let actual):
        "Expected \(expected.width)×\(expected.height) pixels but rendered \(actual.width)×\(actual.height)."
      case .pngEncodingFailed(let screenshot):
        "The rendered image for \(screenshot) could not be encoded as PNG."
      }
    }
  }

  @MainActor
  public final class ScreenshotStudioEngine {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
      self.fileManager = fileManager
    }

    public func render(
      definition: ScreenshotDefinition,
      preset: ScreenshotDevicePreset,
      locale: ScreenshotStudioLocale = .english,
      colorScheme: ScreenshotStudioColorScheme = .light,
      outputDirectory: URL? = nil,
      index: Int = 1
    ) throws -> ScreenshotExportedFile {
      guard definition.supports(preset) else {
        throw ScreenshotStudioError.unsupportedPreset(
          screenshot: definition.title,
          preset: preset.title
        )
      }

      let directory: URL
      if let outputDirectory {
        directory = outputDirectory
      } else {
        directory = try makeOutputDirectory(
          appName: "Screenshot Studio",
          preset: preset
        )
      }
      try fileManager.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )

      let fileURL = directory.appendingPathComponent(
        ScreenshotFileName.filename(
          index: index,
          baseName: definition.filename,
          presetID: preset.id
        )
      )

      let cgImage = try renderCGImage(
        definition: definition,
        preset: preset,
        locale: locale,
        colorScheme: colorScheme
      )

      guard let data = pngData(for: cgImage) else {
        throw ScreenshotStudioError.pngEncodingFailed(screenshot: definition.title)
      }

      try data.write(to: fileURL, options: .atomic)

      return ScreenshotExportedFile(
        url: fileURL,
        screenshotID: definition.id,
        presetID: preset.id,
        pixelSize: preset.pixelSize
      )
    }

    public func renderAll(
      catalog: ScreenshotCatalog,
      preset: ScreenshotDevicePreset,
      locale: ScreenshotStudioLocale = .english,
      colorScheme: ScreenshotStudioColorScheme = .light,
      outputDirectory: URL? = nil
    ) throws -> [ScreenshotExportedFile] {
      let definitions = catalog.screenshots.filter { $0.supports(preset) }
      guard !definitions.isEmpty else {
        throw ScreenshotStudioError.noRegisteredScreenshots
      }

      let directory = try outputDirectory ?? makeOutputDirectory(
        appName: catalog.appName,
        preset: preset
      )

      return try definitions.enumerated().map { offset, definition in
        try render(
          definition: definition,
          preset: preset,
          locale: locale,
          colorScheme: colorScheme,
          outputDirectory: directory,
          index: offset + 1
        )
      }
    }

    private func renderCGImage(
      definition: ScreenshotDefinition,
      preset: ScreenshotDevicePreset,
      locale: ScreenshotStudioLocale,
      colorScheme: ScreenshotStudioColorScheme
    ) throws -> CGImage {
      let pointSize = CGSize(
        width: CGFloat(preset.pointWidth),
        height: CGFloat(preset.pointHeight)
      )
      let content = ScreenshotRenderContainer(
        content: definition.makeContent(),
        pointSize: pointSize,
        displayScale: preset.scale,
        locale: Locale(identifier: locale.localeIdentifier),
        colorScheme: colorScheme.swiftUIColorScheme
      )

      let renderer = ImageRenderer(content: content)
      renderer.proposedSize = ProposedViewSize(
        width: pointSize.width,
        height: pointSize.height
      )
      renderer.scale = CGFloat(preset.scale)
      renderer.isOpaque = true

      guard let cgImage = renderer.cgImage else {
        throw ScreenshotStudioError.renderFailed(screenshot: definition.title)
      }

      let actualSize = ScreenshotPixelSize(
        width: cgImage.width,
        height: cgImage.height
      )
      guard actualSize == preset.pixelSize else {
        throw ScreenshotStudioError.unexpectedPixelSize(
          expected: preset.pixelSize,
          actual: actualSize
        )
      }

      return cgImage
    }

    private func pngData(for image: CGImage) -> Data? {
      let data = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(
        data as CFMutableData,
        UTType.png.identifier as CFString,
        1,
        nil
      ) else {
        return nil
      }

      CGImageDestinationAddImage(destination, image, nil)
      guard CGImageDestinationFinalize(destination) else { return nil }
      return data as Data
    }

    private func makeOutputDirectory(
      appName: String,
      preset: ScreenshotDevicePreset
    ) throws -> URL {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = "yyyyMMdd-HHmmss"

      let folder = [
        ScreenshotFileName.sanitizedComponent(appName),
        ScreenshotFileName.sanitizedComponent(preset.id),
        formatter.string(from: Date()),
      ].joined(separator: "-")

      let directory = fileManager.temporaryDirectory
        .appendingPathComponent("AppFoundation-ScreenshotStudio", isDirectory: true)
        .appendingPathComponent(folder, isDirectory: true)

      try fileManager.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      return directory
    }
  }

  private struct ScreenshotRenderContainer: View {
    let content: AnyView
    let pointSize: CGSize
    let displayScale: Double
    let locale: Locale
    let colorScheme: ColorScheme

    var body: some View {
      ZStack {
        colorScheme == .dark ? Color.black : Color.white
        content
      }
      .environment(\.locale, locale)
      .environment(\.colorScheme, colorScheme)
      .environment(\.displayScale, CGFloat(displayScale))
      .frame(width: pointSize.width, height: pointSize.height)
      .clipped()
    }
  }
#endif
