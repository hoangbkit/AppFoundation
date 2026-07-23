#if os(iOS) && canImport(SwiftUI)
  import Combine
  import SwiftUI

  @MainActor
  public struct PromoVideoPreviewView: View {
    private let project: PromoVideoProject
    private let preset: PromoVideoOutputPreset
    private let frameRate: PromoVideoFrameRate
    private let motionIntensity: PromoVideoMotionIntensity
    private let showsSafeAreas: Bool

    @Binding private var playhead: TimeInterval
    @Binding private var isPlaying: Bool

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    public init(
      project: PromoVideoProject,
      preset: PromoVideoOutputPreset,
      frameRate: PromoVideoFrameRate,
      motionIntensity: PromoVideoMotionIntensity,
      showsSafeAreas: Bool = false,
      playhead: Binding<TimeInterval>,
      isPlaying: Binding<Bool>
    ) {
      self.project = project
      self.preset = preset
      self.frameRate = frameRate
      self.motionIntensity = motionIntensity
      self.showsSafeAreas = showsSafeAreas
      _playhead = playhead
      _isPlaying = isPlaying
    }

    public var body: some View {
      VStack(spacing: 12) {
        PromoVideoCompositionView(
          project: project,
          playhead: playhead,
          preset: preset,
          frameRate: frameRate,
          motionIntensity: motionIntensity,
          showsSafeAreas: showsSafeAreas
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.10))
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)

        VStack(spacing: 9) {
          Slider(
            value: Binding(
              get: { min(playhead, max(project.totalDuration, 0)) },
              set: {
                playhead = min(max($0, 0), project.totalDuration)
              }
            ),
            in: 0...max(project.totalDuration, 0.01)
          )
          .disabled(project.scenes.isEmpty)
          .accessibilityLabel("Video playhead")

          HStack {
            Text(formatTime(playhead))
              .monospacedDigit()

            Spacer()

            HStack(spacing: 18) {
              Button {
                restart()
              } label: {
                Image(systemName: "backward.end.fill")
              }
              .disabled(project.scenes.isEmpty)
              .accessibilityLabel("Restart preview")

              Button {
                togglePlayback()
              } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                  .font(.title3)
                  .frame(width: 36, height: 36)
              }
              .buttonStyle(.borderedProminent)
              .buttonBorderShape(.circle)
              .disabled(project.scenes.isEmpty)
              .accessibilityLabel(isPlaying ? "Pause preview" : "Play preview")
            }

            Spacer()

            Text(formatTime(project.totalDuration))
              .monospacedDigit()
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      .onReceive(timer) { _ in
        advancePlayback()
      }
      .onChange(of: project.totalDuration) { _, total in
        if playhead > total {
          playhead = total
        }
        if total <= 0 {
          isPlaying = false
        }
      }
      .onDisappear {
        isPlaying = false
      }
    }

    private func advancePlayback() {
      guard isPlaying, project.totalDuration > 0 else { return }
      let step = 1.0 / Double(max(frameRate.rawValue, 1))
      let next = playhead + step

      if next >= project.totalDuration {
        playhead = project.totalDuration
        isPlaying = false
      } else {
        playhead = next
      }
    }

    private func restart() {
      playhead = 0
    }

    private func togglePlayback() {
      if playhead >= project.totalDuration {
        playhead = 0
      }
      isPlaying.toggle()
    }

    private func formatTime(_ seconds: Double) -> String {
      let safe = max(seconds, 0)
      return String(
        format: "%d:%02d.%01d",
        Int(safe) / 60,
        Int(safe) % 60,
        Int((safe * 10).rounded(.down)) % 10
      )
    }
  }

  @MainActor
  struct PromoVideoFullScreenPreview: View {
    let project: PromoVideoProject
    let preset: PromoVideoOutputPreset
    let frameRate: PromoVideoFrameRate
    let motionIntensity: PromoVideoMotionIntensity
    let initialPlayhead: TimeInterval
    let showsSafeAreas: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var playhead: TimeInterval
    @State private var isPlaying = true

    init(
      project: PromoVideoProject,
      preset: PromoVideoOutputPreset,
      frameRate: PromoVideoFrameRate,
      motionIntensity: PromoVideoMotionIntensity,
      initialPlayhead: TimeInterval,
      showsSafeAreas: Bool
    ) {
      self.project = project
      self.preset = preset
      self.frameRate = frameRate
      self.motionIntensity = motionIntensity
      self.initialPlayhead = initialPlayhead
      self.showsSafeAreas = showsSafeAreas
      _playhead = State(initialValue: initialPlayhead)
    }

    var body: some View {
      NavigationStack {
        ZStack {
          Color.black.ignoresSafeArea()

          PromoVideoPreviewView(
            project: project,
            preset: preset,
            frameRate: frameRate,
            motionIntensity: motionIntensity,
            showsSafeAreas: showsSafeAreas,
            playhead: $playhead,
            isPlaying: $isPlaying
          )
          .padding()
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
              dismiss()
            }
          }
        }
      }
      .preferredColorScheme(.dark)
    }
  }
#endif
