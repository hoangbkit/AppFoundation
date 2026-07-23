#if os(iOS) && canImport(AVFoundation) && canImport(SwiftUI)
  @preconcurrency import AVFoundation
  import CoreGraphics
  import CoreVideo
  import SwiftUI

  public enum PromoVideoExportError: LocalizedError {
    case emptyProject
    case cannotCreateWriter
    case cannotStartWriter
    case cannotCreatePixelBuffer
    case cannotRenderFrame(Int)
    case cannotAppendFrame(Int)
    case exportFailed(String)

    public var errorDescription: String? {
      switch self {
      case .emptyProject:
        "The promo video project has no scenes."
      case .cannotCreateWriter:
        "The video writer could not be configured."
      case .cannotStartWriter:
        "The video writer could not start."
      case .cannotCreatePixelBuffer:
        "A video frame buffer could not be created."
      case .cannotRenderFrame(let index):
        "Frame \(index) could not be rendered."
      case .cannotAppendFrame(let index):
        "Frame \(index) could not be written to the video."
      case .exportFailed(let message):
        message
      }
    }
  }

  public struct PromoVideoExportedFile: Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public let preset: PromoVideoOutputPreset
    public let frameRate: PromoVideoFrameRate
    public let duration: TimeInterval

    public init(
      id: UUID = UUID(),
      url: URL,
      preset: PromoVideoOutputPreset,
      frameRate: PromoVideoFrameRate,
      duration: TimeInterval
    ) {
      self.id = id
      self.url = url
      self.preset = preset
      self.frameRate = frameRate
      self.duration = duration
    }
  }

  @MainActor
  public final class PromoVideoExporter {
    public init() {}

    public func export(
      project: PromoVideoProject,
      preset: PromoVideoOutputPreset,
      frameRate: PromoVideoFrameRate,
      motionIntensity: PromoVideoMotionIntensity,
      progress: @escaping @MainActor @Sendable (Double) -> Void = { _ in }
    ) async throws -> PromoVideoExportedFile {
      guard !project.scenes.isEmpty, project.totalDuration > 0 else {
        throw PromoVideoExportError.emptyProject
      }

      let outputURL = makeOutputURL(projectName: project.name)
      try? FileManager.default.removeItem(at: outputURL)

      let writer: AVAssetWriter
      do {
        writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
      } catch {
        throw PromoVideoExportError.exportFailed(error.localizedDescription)
      }

      let width = preset.pixelSize.width
      let height = preset.pixelSize.height
      let bitrate = max(8_000_000, width * height * frameRate.rawValue / 5)

      let outputSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: bitrate,
          AVVideoExpectedSourceFrameRateKey: frameRate.rawValue,
          AVVideoMaxKeyFrameIntervalKey: frameRate.rawValue * 2,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ],
      ]

      let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
      input.expectsMediaDataInRealTime = false

      let sourceAttributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
      ]

      let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: sourceAttributes
      )

      guard writer.canAdd(input) else {
        throw PromoVideoExportError.cannotCreateWriter
      }
      writer.add(input)

      guard writer.startWriting() else {
        throw PromoVideoExportError.exportFailed(
          writer.error?.localizedDescription ?? PromoVideoExportError.cannotStartWriter.localizedDescription
        )
      }
      writer.startSession(atSourceTime: .zero)

      let frameCount = max(1, Int(ceil(project.totalDuration * Double(frameRate.rawValue))))
      let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate.rawValue))

      do {
        for frameIndex in 0..<frameCount {
          try Task.checkCancellation()

          while !input.isReadyForMoreMediaData {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(2))
          }

          guard let pool = adaptor.pixelBufferPool else {
            throw PromoVideoExportError.cannotCreatePixelBuffer
          }

          var optionalBuffer: CVPixelBuffer?
          let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
          guard status == kCVReturnSuccess, let pixelBuffer = optionalBuffer else {
            throw PromoVideoExportError.cannotCreatePixelBuffer
          }

          let playhead = min(
            Double(frameIndex) / Double(frameRate.rawValue),
            project.totalDuration
          )

          guard let image = renderFrame(
            project: project,
            playhead: playhead,
            preset: preset,
            frameRate: frameRate,
            motionIntensity: motionIntensity
          ) else {
            throw PromoVideoExportError.cannotRenderFrame(frameIndex)
          }

          draw(image: image, into: pixelBuffer, width: width, height: height)
          let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))

          guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            throw PromoVideoExportError.exportFailed(
              writer.error?.localizedDescription
                ?? PromoVideoExportError.cannotAppendFrame(frameIndex).localizedDescription
            )
          }

          if frameIndex.isMultiple(of: max(frameRate.rawValue / 3, 1)) || frameIndex == frameCount - 1 {
            progress(Double(frameIndex + 1) / Double(frameCount))
            await Task.yield()
          }
        }

        input.markAsFinished()
        await finish(writer)

        guard writer.status == .completed else {
          throw PromoVideoExportError.exportFailed(
            writer.error?.localizedDescription ?? "The video export did not complete."
          )
        }
      } catch {
        if writer.status == .writing {
          writer.cancelWriting()
        }
        try? FileManager.default.removeItem(at: outputURL)
        throw error
      }

      progress(1)
      return PromoVideoExportedFile(
        url: outputURL,
        preset: preset,
        frameRate: frameRate,
        duration: project.totalDuration
      )
    }

    private func renderFrame(
      project: PromoVideoProject,
      playhead: TimeInterval,
      preset: PromoVideoOutputPreset,
      frameRate: PromoVideoFrameRate,
      motionIntensity: PromoVideoMotionIntensity
    ) -> CGImage? {
      let size = preset.pointSize
      let content = PromoVideoCompositionView(
        project: project,
        playhead: playhead,
        preset: preset,
        frameRate: frameRate,
        motionIntensity: motionIntensity,
        showsSafeAreas: false,
        isExporting: true
      )
      .frame(width: size.width, height: size.height)

      let renderer = ImageRenderer(content: content)
      renderer.proposedSize = ProposedViewSize(size)
      renderer.scale = CGFloat(preset.scale)
      renderer.isOpaque = true
      return renderer.cgImage
    }

    private func draw(
      image: CGImage,
      into pixelBuffer: CVPixelBuffer,
      width: Int,
      height: Int
    ) {
      CVPixelBufferLockBaseAddress(pixelBuffer, [])
      defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

      guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
      let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
      let colorSpace = CGColorSpaceCreateDeviceRGB()
      let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
        | CGImageAlphaInfo.premultipliedFirst.rawValue

      guard let context = CGContext(
        data: baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
      ) else { return }

      let frame = CGRect(x: 0, y: 0, width: width, height: height)
      context.setFillColor(CGColor(gray: 0, alpha: 1))
      context.fill(frame)

      // ImageRenderer already returns the completed SwiftUI frame in the
      // orientation expected by the pixel buffer. Flipping again here would
      // invert the exported video while leaving the live preview correct.
      context.draw(image, in: frame)
    }

    private func finish(_ writer: AVAssetWriter) async {
      await withCheckedContinuation { continuation in
        writer.finishWriting {
          continuation.resume()
        }
      }
    }

    private func makeOutputURL(projectName: String) -> URL {
      let sanitized = projectName
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
      let baseName = sanitized.isEmpty ? "promo-video" : sanitized
      return FileManager.default.temporaryDirectory
        .appendingPathComponent("\(baseName)-\(UUID().uuidString).mp4")
    }
  }
#endif
