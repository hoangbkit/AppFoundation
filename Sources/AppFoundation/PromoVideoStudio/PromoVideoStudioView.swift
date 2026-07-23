#if os(iOS) && canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

@MainActor
public struct PromoVideoStudio<SceneControls: View, VideoControls: View>: View {
    private let videos: [PromoVideoProject]
    private let style: PromoVideoStudioStyle
    private let sceneControls: (PromoVideoStudioControlContext) -> SceneControls
    private let videoControls: (PromoVideoStudioControlContext) -> VideoControls
    private let exporter = PromoVideoExporter()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
    @State private var isShowingShareSheet = false
    @State private var errorMessage: String?

    public init(
        videos: [PromoVideoProject],
        style: PromoVideoStudioStyle = .standard,
        @ViewBuilder sceneControls: @escaping (PromoVideoStudioControlContext) -> SceneControls,
        @ViewBuilder videoConfigurationControls: @escaping (PromoVideoStudioControlContext) -> VideoControls
    ) {
        precondition(!videos.isEmpty, "Promo Video Studio requires at least one video.")
        let firstVideo = videos[0]

        self.videos = videos
        self.style = style
        self.sceneControls = sceneControls
        videoControls = videoConfigurationControls
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
        @ViewBuilder videoConfigurationControls: @escaping (PromoVideoStudioControlContext) -> VideoControls
    ) {
        self.init(
            videos: [project],
            style: style,
            sceneControls: sceneControls,
            videoConfigurationControls: videoConfigurationControls
        )
    }

    public var body: some View {
        ZStack {
            PromoVideoStudioBackground(style: style)

            Group {
                if horizontalSizeClass == .regular {
                    regularEditor
                } else {
                    compactEditor
                }
            }
        }
        .foregroundStyle(style.primaryTextColor)
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(style.accentColor)
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
        .onChange(of: selectedVideoIndex) { _, _ in
            resetForSelectedVideo()
        }
        .onChange(of: videos.count) { _, _ in
            repairVideoSelection()
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
            repairVideoSelection()
            repairSceneSelection()
            repairPresetSelection()
        }
    }

    private var compactEditor: some View {
        Form {
            Section("Preview") {
                previewArea
                    .frame(maxHeight: 520)
                    .padding(.vertical, 4)
            }
            .listRowBackground(style.surfaceColor)

            Section {
                scopePicker
            }
            .listRowBackground(style.surfaceColor)

            editorSections
        }
        .scrollContentBackground(.hidden)
    }

    private var regularEditor: some View {
        HStack(spacing: 0) {
            ScrollView {
                previewArea
                    .padding(24)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(style.borderColor)
                .frame(width: 1)

            VStack(spacing: 0) {
                scopePicker
                    .padding(18)
                    .background(style.surfaceColor)

                Form {
                    editorSections
                }
                .scrollContentBackground(.hidden)
            }
            .background(style.backgroundColor.opacity(0.72))
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
                    .listRowBackground(style.surfaceColor)
            }
        case .video:
            outputSection
            if let controlContext {
                videoControls(controlContext)
                    .listRowBackground(style.surfaceColor)
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
            .padding(12)
            .background(
                style.surfaceColor,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(style.borderColor)
            }
            .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
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
                                    isSelected: selectedSceneID == scene.id,
                                    style: style
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
        .listRowBackground(style.surfaceColor)
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
            .listRowBackground(style.surfaceColor)
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
        .listRowBackground(style.surfaceColor)
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
        .listRowBackground(style.surfaceColor)
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
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
                .accessibilityLabel("Select promo video")
            }

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

    private var project: PromoVideoProject {
        let safeIndex = min(max(selectedVideoIndex, 0), videos.count - 1)
        return videos[safeIndex]
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
        isShowingShareSheet = false
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
        guard !isExporting, let selectedPreset else { return }
        let exportingVideoIndex = selectedVideoIndex
        let exportingProject = project

        isPlaying = false
        isExporting = true
        exportProgress = 0
        errorMessage = nil

        Task {
            do {
                let file = try await exporter.export(
                    project: exportingProject,
                    preset: selectedPreset,
                    frameRate: frameRate,
                    motionIntensity: motionIntensity
                ) { value in
                    exportProgress = value
                }
                guard selectedVideoIndex == exportingVideoIndex else {
                    isExporting = false
                    return
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
#endif
