import Foundation

public struct ScreenshotPixelSize: Codable, Hashable, Sendable {
  public var width: Int
  public var height: Int

  public init(width: Int, height: Int) {
    self.width = width
    self.height = height
  }

  public var isLandscape: Bool { width > height }
  public var aspectRatio: Double { Double(width) / Double(height) }
}

public struct ScreenshotDevicePreset: Identifiable, Codable, Hashable, Sendable {
  public let id: String
  public var title: String
  public var pixelSize: ScreenshotPixelSize
  public var scale: Double

  public init(
    id: String,
    title: String,
    pixelSize: ScreenshotPixelSize,
    scale: Double
  ) {
    precondition(
      pixelSize.width > 0 && pixelSize.height > 0, "Screenshot dimensions must be positive.")
    precondition(scale > 0, "Screenshot scale must be positive.")

    self.id = id
    self.title = title
    self.pixelSize = pixelSize
    self.scale = scale
  }

  public var pointWidth: Double { Double(pixelSize.width) / scale }
  public var pointHeight: Double { Double(pixelSize.height) / scale }

  public func landscape(
    id: String? = nil,
    title: String? = nil
  ) -> ScreenshotDevicePreset {
    ScreenshotDevicePreset(
      id: id ?? "\(self.id)-landscape",
      title: title ?? "\(self.title) Landscape",
      pixelSize: ScreenshotPixelSize(
        width: pixelSize.height,
        height: pixelSize.width
      ),
      scale: scale
    )
  }
}

extension ScreenshotDevicePreset {
  /// One accepted 6.9-inch iPhone App Store screenshot size.
  public static let iPhone69Portrait = ScreenshotDevicePreset(
    id: "iphone-6.9-1320x2868",
    title: "iPhone 6.9-inch",
    pixelSize: ScreenshotPixelSize(width: 1320, height: 2868),
    scale: 3
  )

  /// A common 6.5-inch iPhone App Store screenshot size.
  public static let iPhone65Portrait = ScreenshotDevicePreset(
    id: "iphone-6.5-1242x2688",
    title: "iPhone 6.5-inch",
    pixelSize: ScreenshotPixelSize(width: 1242, height: 2688),
    scale: 3
  )

  /// One accepted 13-inch iPad App Store screenshot size.
  public static let iPad13Portrait = ScreenshotDevicePreset(
    id: "ipad-13-2064x2752",
    title: "iPad 13-inch",
    pixelSize: ScreenshotPixelSize(width: 2064, height: 2752),
    scale: 2
  )

  /// A high-resolution 16:10 Mac App Store screenshot size.
  public static let mac16x10 = ScreenshotDevicePreset(
    id: "mac-2880x1800",
    title: "Mac 16:10",
    pixelSize: ScreenshotPixelSize(width: 2880, height: 1800),
    scale: 2
  )

  public static let appStoreDefaults: [ScreenshotDevicePreset] = [
    .iPhone69Portrait,
    .iPhone65Portrait,
    .iPad13Portrait,
  ]
}

public struct ScreenshotStudioLocale: Identifiable, Codable, Hashable, Sendable {
  public let id: String
  public var title: String
  public var localeIdentifier: String

  public init(
    id: String? = nil,
    title: String,
    localeIdentifier: String
  ) {
    self.id = id ?? localeIdentifier
    self.title = title
    self.localeIdentifier = localeIdentifier
  }
}

extension ScreenshotStudioLocale {
  public static let english = ScreenshotStudioLocale(
    title: "English",
    localeIdentifier: "en-US"
  )
}

public enum ScreenshotFileName {
  public static func sanitizedComponent(_ value: String) -> String {
    let lowercase =
      value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()

    var result = ""
    var lastWasSeparator = false

    for scalar in lowercase.unicodeScalars {
      let isAllowed = CharacterSet.alphanumerics.contains(scalar)
      if isAllowed {
        result.unicodeScalars.append(scalar)
        lastWasSeparator = false
      } else if !lastWasSeparator, !result.isEmpty {
        result.append("-")
        lastWasSeparator = true
      }
    }

    while result.last == "-" {
      result.removeLast()
    }

    return result.isEmpty ? "screenshot" : result
  }

  public static func filename(
    index: Int,
    baseName: String,
    presetID: String,
    fileExtension: String = "png"
  ) -> String {
    let position = String(format: "%02d", max(index, 0))
    let base = sanitizedComponent(baseName)
    let preset = sanitizedComponent(presetID)
    let ext = sanitizedComponent(fileExtension)
    return "\(position)-\(base)-\(preset).\(ext)"
  }
}

#if canImport(SwiftUI)
  import SwiftUI

  @MainActor
  public struct ScreenshotDefinition: Identifiable {
    public let id: String
    public var title: String
    public var filename: String
    public var supportedPresetIDs: Set<String>?

    private let contentBuilder: () -> AnyView

    public init<Content: View>(
      id: String,
      title: String,
      filename: String? = nil,
      supportedPresetIDs: Set<String>? = nil,
      @ViewBuilder content: @escaping () -> Content
    ) {
      self.id = id
      self.title = title
      self.filename = filename ?? title
      self.supportedPresetIDs = supportedPresetIDs
      self.contentBuilder = { AnyView(content()) }
    }

    public func supports(_ preset: ScreenshotDevicePreset) -> Bool {
      supportedPresetIDs?.contains(preset.id) ?? true
    }

    public func makeContent() -> AnyView {
      contentBuilder()
    }
  }

  @MainActor
  @resultBuilder
  public enum ScreenshotDefinitionBuilder {
    public static func buildBlock(_ components: ScreenshotDefinition...) -> [ScreenshotDefinition] {
      components
    }

    public static func buildArray(_ components: [[ScreenshotDefinition]]) -> [ScreenshotDefinition]
    {
      components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [ScreenshotDefinition]?) -> [ScreenshotDefinition]
    {
      component ?? []
    }

    public static func buildEither(first component: [ScreenshotDefinition])
      -> [ScreenshotDefinition]
    {
      component
    }

    public static func buildEither(second component: [ScreenshotDefinition])
      -> [ScreenshotDefinition]
    {
      component
    }

    public static func buildExpression(_ expression: ScreenshotDefinition) -> [ScreenshotDefinition]
    {
      [expression]
    }

    public static func buildExpression(_ expression: [ScreenshotDefinition])
      -> [ScreenshotDefinition]
    {
      expression
    }
  }

  @MainActor
  public struct ScreenshotCatalog {
    public var appName: String
    public var presets: [ScreenshotDevicePreset]
    public var locales: [ScreenshotStudioLocale]
    public var screenshots: [ScreenshotDefinition]
    public var defaultPresetID: String?
    public var defaultLocaleID: String?
    public var defaultScreenshotID: String?

    public init(
      appName: String,
      presets: [ScreenshotDevicePreset] = .appStoreDefaults,
      locales: [ScreenshotStudioLocale] = [.english],
      defaultPresetID: String? = nil,
      defaultLocaleID: String? = nil,
      defaultScreenshotID: String? = nil,
      @ScreenshotDefinitionBuilder screenshots: () -> [ScreenshotDefinition]
    ) {
      self.appName = appName
      self.presets = presets.isEmpty ? .appStoreDefaults : presets
      self.locales = locales.isEmpty ? [.english] : locales
      self.screenshots = screenshots()
      self.defaultPresetID = defaultPresetID
      self.defaultLocaleID = defaultLocaleID
      self.defaultScreenshotID = defaultScreenshotID
    }
  }
#endif
