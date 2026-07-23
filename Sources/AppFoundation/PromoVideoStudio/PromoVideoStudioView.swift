#if os(iOS) && canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI
  import UIKit

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
  public struct PromoVideoStudio<SceneControls: View, VideoControls: View>: View {
    private let project: PromoVideoProject
    private let sceneControls: (PromoVideoStudioControlContext) -> SceneControls
    private let videoControls: (PromoVideoStudioControlContext) -> VideoControls
    private let exporter = PromoVideoExporter()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
    @State private var isShowingShareSheet = false
    @State private var errorMessage: String?

    public init(
      project: PromoVideoProject,
      @ViewBuilder sceneControls: @escaping (PromoVideoStudioControlContext) -> SceneControls,
      @ViewBuilder videoConfigurationControls: @escaping (PromoVideoStudioControlContext) -> VideoControls
    ) {
      self.project = project
      self.sceneControls = sceneControls
      self.videoControls = videoConfigurationControls
      _selectedSceneID = State(initialValue: project.scenes.first?.id ?? "")
      _selectedPresetID = State(
        initialValue: project.defaultPresetID ?? project.presets.first?.id ?? ""
      )
      _frameRate = State(initialValue: project.defaultFrameRate)
      _motionIntensity = State(initialValue: project.defaultMotionIntensity)
    }

    public var body: some View {
      Group {
        if horizontalSizeClass == .regular {
          regularEditor
        } else {
          compactEditor
        }
      }
      .navigationTitle(project.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar(.hidden, for: .tabBar)
      .toolbarBackground(.hidden, for: .navigationBar)
      .toolbar { editorToolbar }
      .fullScreenCover(isPresented: $isShowingFullPreview) {
        if let selectedPreset {
          PromoVideoFullScreenPreview(
            project: project,
            preset: selectedPreset,
            frameRate: frameRate,
            motionIntensity: motionIntensity,
            initialPlayhead: playhead,
            showsSafeAreas: showsSafeAreas
          )
        }
      }
      .sheet(isPresented: $isShowingShareSheet) {
        if let exportedFile {
          PromoVideoShareSheet(url: exportedFile.url)
        }
      }
      .alert("Promo Video Studio", isPresented: errorBinding) {
        Button("OK", role: .cancel) {
          errorMessage = nil
        }
      } message: {
        Text(errorMessage ?? "Unknown error")
      }
      .onChange(of: project.sceneIDs) { _, _ in
        repairSceneSelection()
      }
      .onChange(of: project.presets.map(\.id)) { _, _ in
        repairPresetSelection()
      }
      .onChange(of: selectedSceneID) { _, newValue in
        jumpToScene(id: newValue)
      }
      .onAppear {
        repairSceneSelection()
        repairPresetSelection()
      }
    }

    private var compactEditor: some View {
      Form {
        Section {
          previewArea
            .frame(maxHeight: 520)
            .padding(.vertical, 4)
        }

        Section {
          scopePicker
        }

        editorSections
      }
    }

    private var regularEditor: some View {
      HStack(spacing: 0) {
        ScrollView {
          previewArea
            .padding(24)
        }
        .frame(maxWidth: .infinity)

        Divider()

        VStack(spacing: 0) {
          scopePicker
            .padding(18)

          Form {
            editorSections
          }
        }
        .frame(minWidth: 370, idealWidth: 430, maxWidth: 480)
      }
    }

    @ViewBuilder
    private var editorSections: some View {
      switch scope {
      case .scene:
        sceneStripSection
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

    @ViewBuilder
    private var previewArea: some View {
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
      } else {
        ContentUnavailableView(
          "No Output Preset",
          systemImage: "rectangle.slash",
          description: Text("Register at least one promo video output preset.")
        )
      }
    }

    private var scopePicker: some View {
      Picker("Editor Settings", selection: $scope) {
        ForEach(PromoVideoStudioControlScope.allCases) { scope in
          Text(scope.title).tag(scope)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .accessibilityLabel("Promo video editor settings")
    }

    private var sceneStripSection: some View {
      Section("Scenes") {
        if project.scenes.isEmpty {
          ContentUnavailableView(
            "No Registered Scenes",
            systemImage: "rectangle.stack.badge.exclamationmark",
            description: Text("Register SwiftUI scenes in the promo video project.")
          )
        } else {
          ScrollView(.horizontal) {
            HStack(spacing: 12) {
              ForEach(Array(project.scenes.enumerated()), id: \.element.id) { index, scene in
                Button {
                  selectedSceneID = scene.id
                } label: {
                  PromoVideoSceneThumbnail(
                    project: project,
                    sceneIndex: index,
                    preset: selectedPreset ?? .verticalFullHD,
                    frameRate: frameRate,
                    motionIntensity: motionIntensity,
                    isSelected: selectedSceneID == scene.id
                  )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select \(scene.title)")
              }
            }
            .padding(.vertical, 4)
          }
          .scrollIndicators(.hidden)
        }
      }
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
            isShowingShareSheet = true
          } label: {
            Label("Share Last Export", systemImage: "paperplane.fill")
          }
          .disabled(isExporting)

          LabeledContent("Last export", value: exportedFile.url.lastPathComponent)
        }
      }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button {
          isShowingFullPreview = true
        } label: {
          Image(systemName: "play.rectangle.fill")
        }
        .disabled(project.scenes.isEmpty || selectedPreset == nil)
        .accessibilityLabel("Preview full promo video")

        if isExporting {
          ProgressView()
            .controlSize(.small)
        } else {
          Button {
            exportVideo()
          } label: {
            Image(systemName: "square.and.arrow.up")
          }
          .disabled(project.scenes.isEmpty || selectedPreset == nil)
          .accessibilityLabel("Export promo video")
        }
      }
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
      guard let selectedSceneIndex,
            let selectedScene,
            let selectedPreset
      else { return nil }

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
      guard !isExporting, let selectedPreset else { return }
      isPlaying = false
      isExporting = true
      exportProgress = 0
      errorMessage = nil

      Task {
        do {
          let file = try await exporter.export(
            project: project,
            preset: selectedPreset,
            frameRate: frameRate,
            motionIntensity: motionIntensity
          ) { value in
            exportProgress = value
          }
          exportedFile = file
          isExporting = false
          isShowingShareSheet = true
        } catch is CancellationError {
          isExporting = false
        } catch {
          isExporting = false
          errorMessage = error.localizedDescription
        }
      }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
      String(format: "%.1f sec", duration)
    }

    private var errorBinding: Binding<Bool> {
      Binding(
        get: { errorMessage != nil },
        set: { isPresented in
          if !isPresented {
            errorMessage = nil
          }
        }
      )
    }
  }

  extension PromoVideoStudio where SceneControls == EmptyView, VideoControls == EmptyView {
    public init(project: PromoVideoProject) {
      self.init(
        project: project,
        sceneControls: { _ in EmptyView() },
        videoConfigurationControls: { _ in EmptyView() }
      )
    }
  }

  extension PromoVideoStudio where VideoControls == EmptyView {
    public init(
      project: PromoVideoProject,
      @ViewBuilder sceneControls: @escaping (PromoVideoStudioControlContext) -> SceneControls
    ) {
      self.init(
        project: project,
        sceneControls: sceneControls,
        videoConfigurationControls: { _ in EmptyView() }
      )
    }
  }

  @MainActor
  private struct PromoVideoSceneThumbnail: View {
    let project: PromoVideoProject
    let sceneIndex: Int
    let preset: PromoVideoOutputPreset
    let frameRate: PromoVideoFrameRate
    let motionIntensity: PromoVideoMotionIntensity
    let isSelected: Bool

    var body: some View {
      VStack(alignment: .leading, spacing: 7) {
        PromoVideoCompositionView(
          project: project,
          playhead: thumbnailPlayhead,
          preset: preset,
          frameRate: frameRate,
          motionIntensity: motionIntensity
        )
        .frame(width: 86, height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.10), lineWidth: isSelected ? 3 : 1)
        }

        Text(project.scenes[sceneIndex].title)
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
          .frame(width: 86, alignment: .leading)
      }
    }

    private var thumbnailPlayhead: TimeInterval {
      project.startTime(forSceneAt: sceneIndex) + project.scenes[sceneIndex].duration * 0.55
    }
  }

  private struct PromoVideoShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
      UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
  }
#endif
