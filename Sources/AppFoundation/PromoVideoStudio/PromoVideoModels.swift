#if os(iOS) && canImport(SwiftUI)
  import CoreGraphics
  import Foundation
  import SwiftUI

  public struct PromoVideoPixelSize: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
      precondition(width > 0 && height > 0, "Promo video dimensions must be positive.")
      self.width = width
      self.height = height
    }

    public var aspectRatio: Double { Double(width) / Double(height) }
    public var cgSize: CGSize { CGSize(width: CGFloat(width), height: CGFloat(height)) }
  }

  public struct PromoVideoOutputPreset: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var pixelSize: PromoVideoPixelSize
    public var scale: Double

    public init(
      id: String,
      title: String,
      pixelSize: PromoVideoPixelSize,
      scale: Double = 3
    ) {
      precondition(scale > 0, "Promo video output scale must be positive.")
      self.id = id
      self.title = title
      self.pixelSize = pixelSize
      self.scale = scale
    }

    public var pointSize: CGSize {
      CGSize(
        width: Double(pixelSize.width) / scale,
        height: Double(pixelSize.height) / scale
      )
    }
  }

  extension PromoVideoOutputPreset {
    public static let verticalFullHD = PromoVideoOutputPreset(
      id: "vertical-1080x1920",
      title: "Vertical 9:16",
      pixelSize: PromoVideoPixelSize(width: 1080, height: 1920)
    )

    public static let socialPortrait = PromoVideoOutputPreset(
      id: "portrait-1080x1350",
      title: "Portrait 4:5",
      pixelSize: PromoVideoPixelSize(width: 1080, height: 1350)
    )

    public static let square = PromoVideoOutputPreset(
      id: "square-1080x1080",
      title: "Square 1:1",
      pixelSize: PromoVideoPixelSize(width: 1080, height: 1080)
    )

    public static let landscapeFullHD = PromoVideoOutputPreset(
      id: "landscape-1920x1080",
      title: "Landscape 16:9",
      pixelSize: PromoVideoPixelSize(width: 1920, height: 1080)
    )

    public static let socialDefaults: [PromoVideoOutputPreset] = [
      .verticalFullHD,
      .socialPortrait,
      .square,
      .landscapeFullHD,
    ]
  }

  public enum PromoVideoFrameRate: Int, CaseIterable, Identifiable, Sendable {
    case fps30 = 30
    case fps60 = 60

    public var id: Int { rawValue }
    public var title: String { "\(rawValue) fps" }
  }

  public enum PromoVideoMotionIntensity: String, CaseIterable, Identifiable, Sendable {
    case subtle
    case balanced
    case cinematic

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    public var scale: Double {
      switch self {
      case .subtle: 0.58
      case .balanced: 1
      case .cinematic: 1.38
      }
    }
  }

  public enum PromoVideoTransition: String, CaseIterable, Identifiable, Sendable {
    case none
    case crossfade
    case slide
    case zoom

    public var id: String { rawValue }

    public var title: String {
      switch self {
      case .none: "None"
      case .crossfade: "Crossfade"
      case .slide: "Slide"
      case .zoom: "Zoom"
      }
    }
  }

  public struct PromoVideoSceneContext: Sendable {
    public let sceneID: String
    public let sceneTitle: String
    public let sceneIndex: Int
    public let sceneCount: Int
    public let elapsedTime: TimeInterval
    public let sceneElapsedTime: TimeInterval
    public let sceneDuration: TimeInterval
    public let progress: Double
    public let globalProgress: Double
    public let canvasSize: CGSize
    public let preset: PromoVideoOutputPreset
    public let frameRate: PromoVideoFrameRate
    public let motionIntensity: PromoVideoMotionIntensity
    public let isExporting: Bool

    public init(
      sceneID: String,
      sceneTitle: String,
      sceneIndex: Int,
      sceneCount: Int,
      elapsedTime: TimeInterval,
      sceneElapsedTime: TimeInterval,
      sceneDuration: TimeInterval,
      progress: Double,
      globalProgress: Double,
      canvasSize: CGSize,
      preset: PromoVideoOutputPreset,
      frameRate: PromoVideoFrameRate,
      motionIntensity: PromoVideoMotionIntensity,
      isExporting: Bool
    ) {
      self.sceneID = sceneID
      self.sceneTitle = sceneTitle
      self.sceneIndex = sceneIndex
      self.sceneCount = sceneCount
      self.elapsedTime = elapsedTime
      self.sceneElapsedTime = sceneElapsedTime
      self.sceneDuration = sceneDuration
      self.progress = min(max(progress, 0), 1)
      self.globalProgress = min(max(globalProgress, 0), 1)
      self.canvasSize = canvasSize
      self.preset = preset
      self.frameRate = frameRate
      self.motionIntensity = motionIntensity
      self.isExporting = isExporting
    }

    public func phase(
      from start: Double,
      to end: Double,
      curve: PromoVideoAnimationCurve = .smooth
    ) -> Double {
      guard end > start else { return progress >= end ? 1 : 0 }
      let normalized = min(max((progress - start) / (end - start), 0), 1)
      return curve.value(at: normalized)
    }
  }

  public enum PromoVideoAnimationCurve: String, CaseIterable, Identifiable, Sendable {
    case linear
    case easeIn
    case easeOut
    case smooth
    case spring

    public var id: String { rawValue }

    public func value(at progress: Double) -> Double {
      let value = min(max(progress, 0), 1)
      switch self {
      case .linear:
        return value
      case .easeIn:
        return value * value
      case .easeOut:
        return 1 - pow(1 - value, 2)
      case .smooth:
        return value * value * (3 - 2 * value)
      case .spring:
        let damping = exp(-6 * value)
        return min(max(1 - damping * cos(10 * value), 0), 1.08)
      }
    }
  }

  @MainActor
  public struct PromoVideoSceneDefinition: Identifiable {
    public let id: String
    public var title: String
    public var duration: TimeInterval
    public var transition: PromoVideoTransition
    public var transitionDuration: TimeInterval

    private let contentBuilder: (PromoVideoSceneContext) -> AnyView

    public init<Content: View>(
      id: String,
      title: String,
      duration: TimeInterval = 2.6,
      transition: PromoVideoTransition = .crossfade,
      transitionDuration: TimeInterval = 0.45,
      @ViewBuilder content: @escaping (PromoVideoSceneContext) -> Content
    ) {
      precondition(duration > 0, "Promo video scene duration must be positive.")
      self.id = id
      self.title = title
      self.duration = duration
      self.transition = transition
      self.transitionDuration = transition == .none
        ? 0
        : min(max(transitionDuration, 0), duration * 0.45)
      self.contentBuilder = { context in AnyView(content(context)) }
    }

    public func makeContent(context: PromoVideoSceneContext) -> AnyView {
      contentBuilder(context)
    }
  }

  @MainActor
  @resultBuilder
  public enum PromoVideoSceneBuilder {
    public static func buildBlock(_ components: [PromoVideoSceneDefinition]...)
      -> [PromoVideoSceneDefinition]
    {
      components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: PromoVideoSceneDefinition)
      -> [PromoVideoSceneDefinition]
    {
      [expression]
    }

    public static func buildExpression(_ expression: [PromoVideoSceneDefinition])
      -> [PromoVideoSceneDefinition]
    {
      expression
    }

    public static func buildArray(_ components: [[PromoVideoSceneDefinition]])
      -> [PromoVideoSceneDefinition]
    {
      components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [PromoVideoSceneDefinition]?)
      -> [PromoVideoSceneDefinition]
    {
      component ?? []
    }

    public static func buildEither(first component: [PromoVideoSceneDefinition])
      -> [PromoVideoSceneDefinition]
    {
      component
    }

    public static func buildEither(second component: [PromoVideoSceneDefinition])
      -> [PromoVideoSceneDefinition]
    {
      component
    }
  }

  public struct PromoVideoTimelinePosition: Sendable {
    public let primarySceneIndex: Int
    public let fromSceneIndex: Int?
    public let toSceneIndex: Int?
    public let transition: PromoVideoTransition
    public let transitionProgress: Double

    public var isTransitioning: Bool {
      fromSceneIndex != nil && toSceneIndex != nil && transition != .none
    }
  }

  @MainActor
  public struct PromoVideoProject {
    public var name: String
    public var scenes: [PromoVideoSceneDefinition]
    public var presets: [PromoVideoOutputPreset]
    public var defaultPresetID: String?
    public var defaultFrameRate: PromoVideoFrameRate
    public var defaultMotionIntensity: PromoVideoMotionIntensity

    public init(
      name: String,
      presets: [PromoVideoOutputPreset] = PromoVideoOutputPreset.socialDefaults,
      defaultPresetID: String? = PromoVideoOutputPreset.verticalFullHD.id,
      defaultFrameRate: PromoVideoFrameRate = .fps30,
      defaultMotionIntensity: PromoVideoMotionIntensity = .balanced,
      @PromoVideoSceneBuilder scenes: () -> [PromoVideoSceneDefinition]
    ) {
      self.name = name
      self.scenes = scenes()
      self.presets = presets.isEmpty ? PromoVideoOutputPreset.socialDefaults : presets
      self.defaultPresetID = defaultPresetID
      self.defaultFrameRate = defaultFrameRate
      self.defaultMotionIntensity = defaultMotionIntensity
    }

    public var totalDuration: TimeInterval {
      guard let lastIndex = scenes.indices.last else { return 0 }
      return sceneStartTimes[lastIndex] + scenes[lastIndex].duration
    }

    public var sceneIDs: [String] { scenes.map(\.id) }

    public var sceneStartTimes: [TimeInterval] {
      guard !scenes.isEmpty else { return [] }
      var result: [TimeInterval] = [0]
      result.reserveCapacity(scenes.count)

      for index in 1..<scenes.count {
        let previous = scenes[index - 1]
        let overlap = min(
          previous.transitionDuration,
          previous.duration * 0.45,
          scenes[index].duration * 0.45
        )
        result.append(result[index - 1] + previous.duration - overlap)
      }
      return result
    }

    public func startTime(forSceneAt index: Int) -> TimeInterval {
      guard sceneStartTimes.indices.contains(index) else { return 0 }
      return sceneStartTimes[index]
    }

    public func timelinePosition(at rawTime: TimeInterval) -> PromoVideoTimelinePosition? {
      guard !scenes.isEmpty else { return nil }
      let time = min(max(rawTime, 0), totalDuration)
      let starts = sceneStartTimes

      var primaryIndex = 0
      for index in starts.indices where starts[index] <= time {
        primaryIndex = index
      }

      if primaryIndex > 0 {
        let previousIndex = primaryIndex - 1
        let previousEnd = starts[previousIndex] + scenes[previousIndex].duration
        let overlap = previousEnd - starts[primaryIndex]

        if overlap > 0, time < previousEnd {
          let progress = min(max((time - starts[primaryIndex]) / overlap, 0), 1)
          return PromoVideoTimelinePosition(
            primarySceneIndex: primaryIndex,
            fromSceneIndex: previousIndex,
            toSceneIndex: primaryIndex,
            transition: scenes[previousIndex].transition,
            transitionProgress: progress
          )
        }
      }

      return PromoVideoTimelinePosition(
        primarySceneIndex: primaryIndex,
        fromSceneIndex: nil,
        toSceneIndex: nil,
        transition: .none,
        transitionProgress: 0
      )
    }

    public func context(
      forSceneAt index: Int,
      playhead: TimeInterval,
      canvasSize: CGSize,
      preset: PromoVideoOutputPreset,
      frameRate: PromoVideoFrameRate,
      motionIntensity: PromoVideoMotionIntensity,
      isExporting: Bool
    ) -> PromoVideoSceneContext {
      let scene = scenes[index]
      let sceneElapsed = min(max(playhead - startTime(forSceneAt: index), 0), scene.duration)
      let progress = scene.duration > 0 ? sceneElapsed / scene.duration : 0
      let globalProgress = totalDuration > 0 ? playhead / totalDuration : 0

      return PromoVideoSceneContext(
        sceneID: scene.id,
        sceneTitle: scene.title,
        sceneIndex: index,
        sceneCount: scenes.count,
        elapsedTime: playhead,
        sceneElapsedTime: sceneElapsed,
        sceneDuration: scene.duration,
        progress: progress,
        globalProgress: globalProgress,
        canvasSize: canvasSize,
        preset: preset,
        frameRate: frameRate,
        motionIntensity: motionIntensity,
        isExporting: isExporting
      )
    }
  }
#endif
