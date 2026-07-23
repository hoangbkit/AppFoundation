#if os(iOS) && canImport(SwiftUI)
  import SwiftUI

  @MainActor
  public struct PromoVideoCompositionView: View {
    private let project: PromoVideoProject
    private let playhead: TimeInterval
    private let preset: PromoVideoOutputPreset
    private let frameRate: PromoVideoFrameRate
    private let motionIntensity: PromoVideoMotionIntensity
    private let showsSafeAreas: Bool
    private let isExporting: Bool

    public init(
      project: PromoVideoProject,
      playhead: TimeInterval,
      preset: PromoVideoOutputPreset,
      frameRate: PromoVideoFrameRate,
      motionIntensity: PromoVideoMotionIntensity,
      showsSafeAreas: Bool = false,
      isExporting: Bool = false
    ) {
      self.project = project
      self.playhead = playhead
      self.preset = preset
      self.frameRate = frameRate
      self.motionIntensity = motionIntensity
      self.showsSafeAreas = showsSafeAreas
      self.isExporting = isExporting
    }

    public var body: some View {
      GeometryReader { proxy in
        let canvasSize = proxy.size

        ZStack {
          Color.black

          if let position = project.timelinePosition(at: playhead) {
            composition(position: position, canvasSize: canvasSize)
          }

          if showsSafeAreas {
            PromoVideoSafeAreaOverlay()
          }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
      }
      .aspectRatio(CGFloat(preset.pixelSize.aspectRatio), contentMode: .fit)
      .background(Color.black)
    }

    @ViewBuilder
    private func composition(
      position: PromoVideoTimelinePosition,
      canvasSize: CGSize
    ) -> some View {
      if position.isTransitioning,
         let fromIndex = position.fromSceneIndex,
         let toIndex = position.toSceneIndex
      {
        transitionComposition(
          fromIndex: fromIndex,
          toIndex: toIndex,
          transition: position.transition,
          progress: position.transitionProgress,
          canvasSize: canvasSize
        )
      } else {
        sceneView(index: position.primarySceneIndex, canvasSize: canvasSize)
      }
    }

    @ViewBuilder
    private func transitionComposition(
      fromIndex: Int,
      toIndex: Int,
      transition: PromoVideoTransition,
      progress: Double,
      canvasSize: CGSize
    ) -> some View {
      let normalized = min(max(progress, 0), 1)
      let amount = CGFloat(normalized)

      switch transition {
      case .none:
        sceneView(index: toIndex, canvasSize: canvasSize)

      case .crossfade:
        ZStack {
          sceneView(index: fromIndex, canvasSize: canvasSize)
            .opacity(1 - normalized)
          sceneView(index: toIndex, canvasSize: canvasSize)
            .opacity(normalized)
        }

      case .slide:
        ZStack {
          sceneView(index: fromIndex, canvasSize: canvasSize)
            .offset(x: -canvasSize.width * amount * 0.28)
            .opacity(1 - normalized * 0.28)

          sceneView(index: toIndex, canvasSize: canvasSize)
            .offset(x: canvasSize.width * (1 - amount))
        }

      case .zoom:
        ZStack {
          sceneView(index: fromIndex, canvasSize: canvasSize)
            .scaleEffect(1 + amount * 0.08)
            .opacity(1 - normalized)

          sceneView(index: toIndex, canvasSize: canvasSize)
            .scaleEffect(0.90 + amount * 0.10)
            .opacity(normalized)
        }
      }
    }

    private func sceneView(index: Int, canvasSize: CGSize) -> some View {
      let context = project.context(
        forSceneAt: index,
        playhead: playhead,
        canvasSize: canvasSize,
        preset: preset,
        frameRate: frameRate,
        motionIntensity: motionIntensity,
        isExporting: isExporting
      )

      return project.scenes[index]
        .makeContent(context: context)
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
    }
  }

  public struct PromoVideoSafeAreaOverlay: View {
    public init() {}

    public var body: some View {
      GeometryReader { proxy in
        let horizontal = proxy.size.width * 0.075
        let vertical = proxy.size.height * 0.065

        RoundedRectangle(cornerRadius: max(16, proxy.size.width * 0.035), style: .continuous)
          .strokeBorder(
            Color.white.opacity(0.72),
            style: StrokeStyle(lineWidth: 1.5, dash: [8, 7])
          )
          .padding(.horizontal, horizontal)
          .padding(.vertical, vertical)
          .overlay(alignment: .topLeading) {
            Text("SAFE AREA")
              .font(.system(size: 10, weight: .bold, design: .rounded))
              .tracking(1)
              .foregroundStyle(.white.opacity(0.82))
              .padding(.horizontal, 9)
              .padding(.vertical, 6)
              .background(.black.opacity(0.46), in: Capsule())
              .padding(.leading, horizontal + 8)
              .padding(.top, vertical + 8)
          }
      }
      .allowsHitTesting(false)
    }
  }
#endif
