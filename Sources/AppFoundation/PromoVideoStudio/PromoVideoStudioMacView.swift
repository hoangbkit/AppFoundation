#if os(macOS) && canImport(AppKit) && canImport(SwiftUI)
  import AppKit
  import Combine
  import SwiftUI
  import UniformTypeIdentifiers

  public struct PromoVideoStudioStyle: Sendable {
    public let accentColor: Color
    public let primaryTextColor: Color
    public let secondaryTextColor: Color
    public let surfaceColor: Color
    public let elevatedSurfaceColor: Color
    public let borderColor: Color
    public let backgroundColor: Color
    public let gradientStartColor: Color
    public let gradientEndColor: Color

    public init(
      accentColor: Color,
      primaryTextColor: Color = .primary,
      secondaryTextColor: Color = .secondary,
      surfaceColor: Color = Color(nsColor: .controlBackgroundColor),
      elevatedSurfaceColor: Color = Color(nsColor: .underPageBackgroundColor),
      borderColor: Color = Color.primary.opacity(0.10),
      backgroundColor: Color = Color(nsColor: .windowBackgroundColor),
      gradientStartColor: Color? = nil,
      gradientEndColor: Color? = nil
    ) {
      self.accentColor = accentColor
      self.primaryTextColor = primaryTextColor
      self.secondaryTextColor = secondaryTextColor
      self.surfaceColor = surfaceColor
      self.elevatedSurfaceColor = elevatedSurfaceColor
      self.borderColor = borderColor
      self.backgroundColor = backgroundColor
      self.gradientStartColor = gradientStartColor ?? accentColor.opacity(0.34)
      self.gradientEndColor = gradientEndColor ?? accentColor.opacity(0.08)
    }

    public static let standard = PromoVideoStudioStyle(accentColor: .accentColor)
  }

  public enum PromoVideoStudioControlScope: String, CaseIterable, Identifiable, Sendable {
    case scene
    case video

    public var id: String { rawValue }

    public var title: String {
      switch self {
      case .scene: "Scene"
      case .video: "Video"
      }
    }
  }

  public struct PromoVideoStudioControlContext: Sendable {
    public let selectedSceneID: String
    public let selectedSceneTitle: String
    public let selectedSceneIndex: Int
    public let sceneCount: Int
    public let preset: PromoVideoOutputPreset
    public let frameRate: PromoVideoFrameRate
    public let motionIntensity: PromoVideoMotionIntensity
    public let playhead: TimeInterval
    public let totalDuration: TimeInterval

    public init(
      selectedSceneID: String,
      selectedSceneTitle: String,
      selectedSceneIndex: Int,
      sceneCount: Int,
      preset: PromoVideoOutputPreset,
      frameRate: PromoVideoFrameRate,
      motionIntensity: PromoVideoMotionIntensity,
      playhead: TimeInterval,
      totalDuration: TimeInterval
    ) {
      self.selectedSceneID = selectedSceneID
      self.selectedSceneTitle = selectedSceneTitle
      self.selectedSceneIndex = selectedSceneIndex
      self.sceneCount = sceneCount
      self.preset = preset
      self.frameRate = frameRate
      self.motionIntensity = motionIntensity
      self.playhead = playhead
      self.totalDuration = totalDuration
    }
  }

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
              set: { playhead = min(max($0, 0), project.totalDuration) }
            ),
            in: 0...max(project.totalDuration, 0.01)
          )
          .disabled(project.scenes.isEmpty)
          .accessibilityLabel("Video playhead")

          HStack {
            Text(formatTime(playhead))
              .monospacedDigit()
            Spacer()
            Button {
              playhead = 0
              isPlaying = false
            } label: {
              Image(systemName: "backward.end.fill")
            }
            .buttonStyle(.borderless)
            .disabled(project.scenes.isEmpty)
            .accessibilityLabel("Restart preview")

            Button {
              if playhead >= project.totalDuration { playhead = 0 }
              isPlaying.toggle()
            } label: {
              Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderedProminent)
            .disabled(project.scenes.isEmpty)
            .accessibilityLabel(isPlaying ? "Pause preview" : "Play preview")

            Spacer()
            Text(formatTime(project.totalDuration))
              .monospacedDigit()
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      .onReceive(timer) { _ in advancePlayback() }
      .onChange(of: project.totalDuration) { _, total in
        if playhead > total { playhead = total }
        if total <= 0 { isPlaying = false }
      }
      .onDisappear { isPlaying = false }
    }

    private func advancePlayback() {
      guard isPlaying, project.totalDuration > 0 else { return }
      let next = playhead + 1.0 / Double(max(frameRate.rawValue, 1))
      if next >= project.totalDuration {
        playhead = project.totalDuration
        isPlaying = false
      } else {
        playhead = next
      }
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
  public struct PromoVideoStudio<SceneControls: View, VideoControls: View>: View {
    private let videos: [PromoVideoProject]
    private let style: PromoVideoStudioStyle
    private let sceneControls: (PromoVideoStudioControlContext) -> SceneControls
    private let videoControls: (PromoVideoStudioControlContext) -> VideoControls
    private let exporter = PromoVideoExporter()

    @State private var selectedVideoIndex: Int
    @State private var selectedSceneID: String
    @State private var selectedPresetID: String
    @State private var frameRate: PromoVideoFrameRate
    @State private var motionIntensity: PromoVideoMotionIntensity
    @State private var scope: PromoVideoStudioControlScope = .scene
    @State private var playhead: TimeInterval = 0
    @State private var isPlaying = false
    @State private var showsSafeAreas = false
    @State private var isShowingFullPreview = false
    @State private var isExporting = false
    @State private var exportProgress = 0.0
    @State private var exportedFile: PromoVideoExportedFile?
    @State private var errorMessage: String?

    public init(
      videos: [PromoVideoProject],
      style: PromoVideoStudioStyle = .standard,
      @ViewBuilder sceneControls: @escaping (PromoVideoStudioControlContext) -> SceneControls,
      @ViewBuilder videoConfigurationControls:
        @escaping (PromoVideoStudioControlContext) -> VideoControls
    ) {
      precondition(!videos.isEmpty, "Promo Video Studio requires at least one video.")
      let firstVideo = videos[0]
      self.videos = videos
      self.style = style
      self.sceneControls = sceneControls
      self.videoControls = videoConfigurationControls
      _selectedVideoIndex = State(initialValue: 0)
      _selectedSceneID = State(initialValue: firstVideo.scenes.first?.id ?? "")
      _selectedPresetID = State(
        initialValue: firstVideo.defaultPresetID ?? firstVideo.presets.first?.id ?? ""
      )
      _frameRate = State(initialValue: firstVideo.defaultFrameRate)
      _motionIntensity = State(initialValue: firstVideo.defaultMotionIntensity)
    }

    public init(
      project: PromoVideoProject,
      style: PromoVideoStudioStyle = .standard,
      @ViewBuilder sceneControls: @escaping (PromoVideoStudioControlContext) -> SceneControls,
      @ViewBuilder videoConfigurationControls:
        @escaping (PromoVideoStudioControlContext) -> VideoControls
    ) {
      self.init(
        videos: [project],
        style: style,
        sceneControls: sceneControls,
        videoConfigurationControls: videoConfigurationControls
      )
    }

    public var body: some View {
      NavigationSplitView {
        sidebar
          .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
      } content: {
        previewWorkspace
          .navigationSplitViewColumnWidth(min: 440, ideal: 620)
      } detail: {
        inspector
          .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
      }
      .frame(minWidth: 1120, minHeight: 720)
      .background(PromoVideoStudioBackground(style: style))
      .foregroundStyle(style.primaryTextColor)
      .tint(style.accentColor)
      .toolbar { editorToolbar }
      .sheet(isPresented: $isShowingFullPreview) {
        PromoVideoMacFullPreview(
          project: project,
          preset: selectedPreset ?? .verticalFullHD,
          frameRate: frameRate,
          motionIntensity: motionIntensity,
          initialPlayhead: playhead,
          showsSafeAreas: showsSafeAreas
        )
      }
      .alert("Promo Video Studio", isPresented: errorBinding) {
        Button("OK", role: .cancel) { errorMessage = nil }
      } message: {
        Text(errorMessage ?? "Unknown error")
      }
      .onChange(of: selectedVideoIndex) { _, _ in resetForSelectedVideo() }
      .onChange(of: selectedSceneID) { _, newValue in jumpToScene(id: newValue) }
      .onAppear {
        repairVideoSelection()
        repairSceneSelection()
        repairPresetSelection()
      }
    }

    private var sidebar: some View {
      List(
        selection: Binding<String?>(
          get: { selectedSceneID.isEmpty ? nil : selectedSceneID },
          set: { newValue in
            if let newValue { selectedSceneID = newValue }
          }
        )
      ) {
        if videos.count > 1 {
          Section("Promo Video") {
            Picker("Video", selection: $selectedVideoIndex) {
              ForEach(Array(videos.enumerated()), id: \.offset) { index, video in
                Text(video.name).tag(index)
              }
            }
            .labelsHidden()
          }
        }

        Section("Scenes") {
          if project.scenes.isEmpty {
            ContentUnavailableView(
              "No Registered Scenes",
              systemImage: "rectangle.stack.badge.exclamationmark"
            )
          } else {
            ForEach(Array(project.scenes.enumerated()), id: \.element.id) { index, scene in
              HStack(spacing: 10) {
                PromoVideoCompositionView(
                  project: project,
                  playhead: project.startTime(forSceneAt: index) + scene.duration * 0.55,
                  preset: selectedPreset ?? .verticalFullHD,
                  frameRate: frameRate,
                  motionIntensity: motionIntensity
                )
                .frame(width: 52, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                  Text(scene.title)
                    .font(.headline)
                    .lineLimit(2)
                  Text(formatDuration(scene.duration))
                    .font(.caption)
                    .foregroundStyle(style.secondaryTextColor)
                }
              }
              .padding(.vertical, 4)
              .tag(scene.id)
            }
          }
        }
      }
      .navigationTitle("Promo Studio")
    }

    private var previewWorkspace: some View {
      ZStack {
        PromoVideoStudioBackground(style: style)
        if let selectedPreset {
          PromoVideoPreviewView(
            project: project,
            preset: selectedPreset,
            frameRate: frameRate,
            motionIntensity: motionIntensity,
            showsSafeAreas: showsSafeAreas,
            playhead: $playhead,
            isPlaying: $isPlaying
          )
          .padding(28)
        } else {
          ContentUnavailableView(
            "No Output Preset",
            systemImage: "rectangle.slash",
            description: Text("Register at least one promo video output preset.")
          )
        }
      }
      .navigationTitle(project.name)
    }

    private var inspector: some View {
      VStack(spacing: 0) {
        Picker("Editor Settings", selection: $scope) {
          ForEach(PromoVideoStudioControlScope.allCases) { value in
            Text(value.title).tag(value)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(16)
        .background(style.surfaceColor)

        Form {
          switch scope {
          case .scene:
            selectedSceneSection
            if let controlContext {
              sceneControls(controlContext)
            }
          case .video:
            outputSection
            if let controlContext {
              videoControls(controlContext)
            }
            exportSection
          }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(style.backgroundColor.opacity(0.76))
      }
      .navigationTitle(scope.title)
    }

    @ViewBuilder
    private var selectedSceneSection: some View {
      if let selectedScene {
        Section("Selected Scene") {
          LabeledContent("Scene", value: selectedScene.title)
          LabeledContent("Duration", value: formatDuration(selectedScene.duration))
          LabeledContent("Transition", value: selectedScene.transition.title)
          Button {
            playSelectedScene()
          } label: {
            Label("Play Selected Scene", systemImage: "play.fill")
          }
        }
      }
    }

    private var outputSection: some View {
      Section("Output") {
        Picker("Format", selection: $selectedPresetID) {
          ForEach(project.presets) { preset in
            Text(preset.title).tag(preset.id)
          }
        }
        Picker("Frame rate", selection: $frameRate) {
          ForEach(PromoVideoFrameRate.allCases) { rate in
            Text(rate.title).tag(rate)
          }
        }
        Picker("Motion", selection: $motionIntensity) {
          ForEach(PromoVideoMotionIntensity.allCases) { intensity in
            Text(intensity.title).tag(intensity)
          }
        }
        Toggle("Show safe area", isOn: $showsSafeAreas)
        LabeledContent("Duration", value: formatDuration(project.totalDuration))
        LabeledContent("Audio", value: "Silent MP4")
        if let selectedPreset {
          LabeledContent(
            "Resolution",
            value: "\(selectedPreset.pixelSize.width) × \(selectedPreset.pixelSize.height)"
          )
        }
      }
    }

    private var exportSection: some View {
      Section("Export") {
        if isExporting {
          ProgressView(value: exportProgress) {
            Text("Rendering video")
          } currentValueLabel: {
            Text(exportProgress, format: .percent.precision(.fractionLength(0)))
          }
        }

        Button {
          exportVideo()
        } label: {
          Label(
            exportedFile == nil ? "Export Promo Video" : "Export Again",
            systemImage: "square.and.arrow.up"
          )
        }
        .disabled(isExporting || project.scenes.isEmpty || selectedPreset == nil)

        if let exportedFile {
          Button {
            NSWorkspace.shared.activateFileViewerSelecting([exportedFile.url])
          } label: {
            Label("Reveal Last Export", systemImage: "folder")
          }
          LabeledContent("Last export", value: exportedFile.url.lastPathComponent)
        }
      }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
      ToolbarItemGroup(placement: .primaryAction) {
        if videos.count > 1 {
          Menu {
            ForEach(Array(videos.enumerated()), id: \.offset) { index, video in
              Button {
                selectedVideoIndex = index
              } label: {
                Label(
                  video.name,
                  systemImage: index == selectedVideoIndex ? "checkmark" : "film"
                )
              }
            }
          } label: {
            Image(systemName: "film.stack")
          }
          .disabled(isExporting)
        }

        Button {
          isShowingFullPreview = true
        } label: {
          Image(systemName: "play.rectangle.fill")
        }
        .disabled(project.scenes.isEmpty || selectedPreset == nil)
        .help("Preview full promo video")

        if isExporting {
          ProgressView().controlSize(.small)
        } else {
          Button {
            exportVideo()
          } label: {
            Image(systemName: "square.and.arrow.up")
          }
          .disabled(project.scenes.isEmpty || selectedPreset == nil)
          .help("Export promo video")
        }
      }
    }

    private var project: PromoVideoProject {
      videos[min(max(selectedVideoIndex, 0), videos.count - 1)]
    }

    private var selectedPreset: PromoVideoOutputPreset? {
      project.presets.first(where: { $0.id == selectedPresetID }) ?? project.presets.first
    }

    private var selectedSceneIndex: Int? {
      project.scenes.firstIndex(where: { $0.id == selectedSceneID })
    }

    private var selectedScene: PromoVideoSceneDefinition? {
      guard let selectedSceneIndex else { return nil }
      return project.scenes[selectedSceneIndex]
    }

    private var controlContext: PromoVideoStudioControlContext? {
      guard let selectedSceneIndex, let selectedScene, let selectedPreset else { return nil }
      return PromoVideoStudioControlContext(
        selectedSceneID: selectedScene.id,
        selectedSceneTitle: selectedScene.title,
        selectedSceneIndex: selectedSceneIndex,
        sceneCount: project.scenes.count,
        preset: selectedPreset,
        frameRate: frameRate,
        motionIntensity: motionIntensity,
        playhead: playhead,
        totalDuration: project.totalDuration
      )
    }

    private func repairVideoSelection() {
      selectedVideoIndex = min(max(selectedVideoIndex, 0), videos.count - 1)
    }

    private func resetForSelectedVideo() {
      let selectedProject = project
      selectedSceneID = selectedProject.scenes.first?.id ?? ""
      selectedPresetID = selectedProject.defaultPresetID ?? selectedProject.presets.first?.id ?? ""
      frameRate = selectedProject.defaultFrameRate
      motionIntensity = selectedProject.defaultMotionIntensity
      scope = .scene
      playhead = 0
      isPlaying = false
      isShowingFullPreview = false
      exportedFile = nil
      exportProgress = 0
      errorMessage = nil
      repairSceneSelection()
      repairPresetSelection()
    }

    private func repairSceneSelection() {
      guard !project.scenes.isEmpty else {
        selectedSceneID = ""
        playhead = 0
        isPlaying = false
        return
      }
      if !project.scenes.contains(where: { $0.id == selectedSceneID }) {
        selectedSceneID = project.scenes[0].id
      }
    }

    private func repairPresetSelection() {
      guard !project.presets.isEmpty else {
        selectedPresetID = ""
        return
      }
      if !project.presets.contains(where: { $0.id == selectedPresetID }) {
        selectedPresetID = project.defaultPresetID ?? project.presets[0].id
      }
    }

    private func jumpToScene(id: String) {
      guard let index = project.scenes.firstIndex(where: { $0.id == id }) else { return }
      playhead = project.startTime(forSceneAt: index)
      isPlaying = false
    }

    private func playSelectedScene() {
      guard let selectedSceneIndex else { return }
      playhead = project.startTime(forSceneAt: selectedSceneIndex)
      isPlaying = true
    }

    private func exportVideo() {
      guard !isExporting, let selectedPreset, let outputURL = chooseOutputURL() else { return }
      let exportingVideoIndex = selectedVideoIndex
      let exportingProject = project
      isPlaying = false
      isExporting = true
      exportProgress = 0
      errorMessage = nil

      Task { @MainActor in
        do {
          let file = try await exporter.export(
            project: exportingProject,
            preset: selectedPreset,
            frameRate: frameRate,
            motionIntensity: motionIntensity,
            outputURL: outputURL
          ) { value in
            exportProgress = value
          }
          guard selectedVideoIndex == exportingVideoIndex else {
            isExporting = false
            return
          }
          exportedFile = file
          isExporting = false
          NSWorkspace.shared.activateFileViewerSelecting([file.url])
        } catch is CancellationError {
          isExporting = false
        } catch {
          isExporting = false
          errorMessage = error.localizedDescription
        }
      }
    }

    private func chooseOutputURL() -> URL? {
      let panel = NSSavePanel()
      panel.title = "Export Promo Video"
      panel.message = "Choose where to save the rendered silent MP4."
      panel.prompt = "Export"
      panel.allowedContentTypes = [.mpeg4Movie]
      panel.canCreateDirectories = true
      panel.nameFieldStringValue = suggestedFilename
      return panel.runModal() == .OK ? panel.url : nil
    }

    private var suggestedFilename: String {
      let value = project.name
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
      return "\(value.isEmpty ? "promo-video" : value).mp4"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
      String(format: "%.1f sec", duration)
    }

    private var errorBinding: Binding<Bool> {
      Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    }
  }

  extension PromoVideoStudio where SceneControls == EmptyView, VideoControls == EmptyView {
    public init(videos: [PromoVideoProject], style: PromoVideoStudioStyle = .standard) {
      self.init(
        videos: videos,
        style: style,
        sceneControls: { _ in EmptyView() },
        videoConfigurationControls: { _ in EmptyView() }
      )
    }

    public init(project: PromoVideoProject, style: PromoVideoStudioStyle = .standard) {
      self.init(videos: [project], style: style)
    }
  }

  extension PromoVideoStudio where VideoControls == EmptyView {
    public init(
      videos: [PromoVideoProject],
      style: PromoVideoStudioStyle = .standard,
      @ViewBuilder sceneControls: @escaping (PromoVideoStudioControlContext) -> SceneControls
    ) {
      self.init(
        videos: videos,
        style: style,
        sceneControls: sceneControls,
        videoConfigurationControls: { _ in EmptyView() }
      )
    }

    public init(
      project: PromoVideoProject,
      style: PromoVideoStudioStyle = .standard,
      @ViewBuilder sceneControls: @escaping (PromoVideoStudioControlContext) -> SceneControls
    ) {
      self.init(videos: [project], style: style, sceneControls: sceneControls)
    }
  }

  private struct PromoVideoStudioBackground: View {
    let style: PromoVideoStudioStyle

    var body: some View {
      ZStack {
        style.backgroundColor
        LinearGradient(
          colors: [style.gradientStartColor, style.gradientEndColor, .clear],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .blur(radius: 28)
        .scaleEffect(1.15)
        RadialGradient(
          colors: [style.accentColor.opacity(0.20), .clear],
          center: .topTrailing,
          startRadius: 8,
          endRadius: 520
        )
      }
      .ignoresSafeArea()
      .accessibilityHidden(true)
    }
  }

  @MainActor
  private struct PromoVideoMacFullPreview: View {
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
        .padding(28)
      }
      .frame(minWidth: 820, minHeight: 620)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .preferredColorScheme(.dark)
    }
  }
#endif
