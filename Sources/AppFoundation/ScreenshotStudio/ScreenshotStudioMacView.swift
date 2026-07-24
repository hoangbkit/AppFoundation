#if canImport(SwiftUI) && canImport(AppKit)
  import AppKit
  import SwiftUI

  public struct ScreenshotStudioStyle: Sendable {
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

    public static let standard = ScreenshotStudioStyle(accentColor: .accentColor)
  }

  public enum ScreenshotStudioControlMode: String, CaseIterable, Identifiable, Sendable {
    case selectedScreenshot
    case appConfiguration

    public var id: String { rawValue }

    public var title: String {
      switch self {
      case .selectedScreenshot: "Screenshot"
      case .appConfiguration: "App Config"
      }
    }
  }

  public struct ScreenshotStudioControlContext {
    public let selectedScreenshotID: String
    public let selectedScreenshotTitle: String
    public let preset: ScreenshotDevicePreset
    public let locale: ScreenshotStudioLocale
    public let colorScheme: ScreenshotStudioColorScheme

    public init(
      selectedScreenshotID: String,
      selectedScreenshotTitle: String,
      preset: ScreenshotDevicePreset,
      locale: ScreenshotStudioLocale,
      colorScheme: ScreenshotStudioColorScheme
    ) {
      self.selectedScreenshotID = selectedScreenshotID
      self.selectedScreenshotTitle = selectedScreenshotTitle
      self.preset = preset
      self.locale = locale
      self.colorScheme = colorScheme
    }
  }

  @MainActor
  public struct ScreenshotStudio: View {
    private let catalog: ScreenshotCatalog
    private let style: ScreenshotStudioStyle
    private let selectedScreenshotControls: ((ScreenshotStudioControlContext) -> AnyView)?
    private let appConfigurationControls: ((ScreenshotStudioControlContext) -> AnyView)?
    private let engine = ScreenshotStudioEngine()

    @State private var selectedScreenshotID: String
    @State private var selectedPresetID: String
    @State private var selectedLocaleID: String
    @State private var colorScheme: ScreenshotStudioColorScheme = .light
    @State private var controlMode: ScreenshotStudioControlMode = .selectedScreenshot
    @State private var previewFiles: [ScreenshotExportedFile] = []
    @State private var isExporting = false
    @State private var isRenderingPreview = false
    @State private var isShowingSetPreview = false
    @State private var errorMessage: String?

    public init(
      catalog: ScreenshotCatalog,
      style: ScreenshotStudioStyle = .standard
    ) {
      self.catalog = catalog
      self.style = style
      selectedScreenshotControls = nil
      appConfigurationControls = nil
      _selectedScreenshotID = State(
        initialValue: catalog.defaultScreenshotID ?? catalog.screenshots.first?.id ?? ""
      )
      _selectedPresetID = State(
        initialValue: catalog.defaultPresetID ?? catalog.presets.first?.id ?? ""
      )
      _selectedLocaleID = State(
        initialValue: catalog.defaultLocaleID ?? catalog.locales.first?.id ?? ""
      )
    }

    public init<Controls: View>(
      catalog: ScreenshotCatalog,
      style: ScreenshotStudioStyle = .standard,
      @ViewBuilder controls: @escaping () -> Controls
    ) {
      self.catalog = catalog
      self.style = style
      selectedScreenshotControls = nil
      appConfigurationControls = { _ in
        AnyView(
          Section("App Configuration") {
            controls()
          }
        )
      }
      _selectedScreenshotID = State(
        initialValue: catalog.defaultScreenshotID ?? catalog.screenshots.first?.id ?? ""
      )
      _selectedPresetID = State(
        initialValue: catalog.defaultPresetID ?? catalog.presets.first?.id ?? ""
      )
      _selectedLocaleID = State(
        initialValue: catalog.defaultLocaleID ?? catalog.locales.first?.id ?? ""
      )
    }

    public init<SelectedControls: View, AppControls: View>(
      catalog: ScreenshotCatalog,
      style: ScreenshotStudioStyle = .standard,
      @ViewBuilder selectedScreenshotControls:
        @escaping (ScreenshotStudioControlContext) -> SelectedControls,
      @ViewBuilder appConfigurationControls:
        @escaping (ScreenshotStudioControlContext) -> AppControls
    ) {
      self.catalog = catalog
      self.style = style
      self.selectedScreenshotControls = { context in AnyView(selectedScreenshotControls(context)) }
      self.appConfigurationControls = { context in AnyView(appConfigurationControls(context)) }
      _selectedScreenshotID = State(
        initialValue: catalog.defaultScreenshotID ?? catalog.screenshots.first?.id ?? ""
      )
      _selectedPresetID = State(
        initialValue: catalog.defaultPresetID ?? catalog.presets.first?.id ?? ""
      )
      _selectedLocaleID = State(
        initialValue: catalog.defaultLocaleID ?? catalog.locales.first?.id ?? ""
      )
    }

    public var body: some View {
      NavigationSplitView {
        sidebar
          .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 330)
      } content: {
        previewWorkspace
          .navigationSplitViewColumnWidth(min: 500, ideal: 700)
      } detail: {
        inspector
          .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
      }
      .frame(minWidth: 1120, minHeight: 720)
      .background(ScreenshotStudioBackground(style: style))
      .foregroundStyle(style.primaryTextColor)
      .tint(style.accentColor)
      .toolbar { studioToolbar }
      .onChange(of: selectedPresetID) { _, _ in repairSelectionForPreset() }
      .sheet(isPresented: $isShowingSetPreview) {
        ScreenshotStudioMacSetPreview(
          files: previewFiles,
          catalog: catalog,
          initialScreenshotID: selectedScreenshotID,
          style: style
        )
      }
      .alert("Screenshot Studio", isPresented: errorBinding) {
        Button("OK", role: .cancel) { errorMessage = nil }
      } message: {
        Text(errorMessage ?? "")
      }
    }

    private var sidebar: some View {
      List(
        selection: Binding<String?>(
          get: { selectedScreenshotID.isEmpty ? nil : selectedScreenshotID },
          set: { newValue in
            if let newValue { selectedScreenshotID = newValue }
          }
        )
      ) {
        Section("Registered Screenshots") {
          if availableDefinitions.isEmpty {
            ContentUnavailableView(
              "No Screenshots",
              systemImage: "photo.badge.exclamationmark",
              description: Text("No registered screenshot supports the selected output preset.")
            )
          } else {
            ForEach(availableDefinitions) { definition in
              Label(definition.title, systemImage: "photo")
                .tag(definition.id)
            }
          }
        }
      }
      .navigationTitle("Screenshots")
    }

    private var previewWorkspace: some View {
      ZStack {
        ScreenshotStudioBackground(style: style)
        if let definition = selectedDefinition,
          let preset = selectedPreset,
          let locale = selectedLocale
        {
          ScreenshotStudioMacPreview(
            definition: definition,
            preset: preset,
            locale: locale,
            colorScheme: colorScheme,
            style: style
          )
          .padding(28)
        } else {
          ContentUnavailableView(
            "Nothing to Preview",
            systemImage: "photo.badge.exclamationmark",
            description: Text("Register at least one screenshot and output preset.")
          )
        }
      }
      .navigationTitle(selectedDefinition?.title ?? "Screenshot Studio")
    }

    private var inspector: some View {
      VStack(spacing: 0) {
        Picker("Controls", selection: $controlMode) {
          ForEach(ScreenshotStudioControlMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(16)
        .background(style.surfaceColor)

        Form {
          switch controlMode {
          case .selectedScreenshot:
            selectedScreenshotSection
            if let selectedScreenshotControls, let controlContext {
              selectedScreenshotControls(controlContext)
            }
          case .appConfiguration:
            outputSection
            if let appConfigurationControls, let controlContext {
              appConfigurationControls(controlContext)
            }
          }
          exportSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(style.backgroundColor.opacity(0.76))
      }
      .navigationTitle(controlMode.title)
    }

    private var selectedScreenshotSection: some View {
      Section("Selected Screenshot") {
        Picker("Screenshot", selection: $selectedScreenshotID) {
          ForEach(availableDefinitions) { definition in
            Text(definition.title).tag(definition.id)
          }
        }
        LabeledContent("Registered", value: "\(catalog.screenshots.count)")
      }
    }

    private var outputSection: some View {
      Section("Output") {
        Picker("Device preset", selection: $selectedPresetID) {
          ForEach(catalog.presets) { preset in
            Text(preset.title).tag(preset.id)
          }
        }
        Picker("Appearance", selection: $colorScheme) {
          ForEach(ScreenshotStudioColorScheme.allCases) { scheme in
            Text(scheme.title).tag(scheme)
          }
        }
        Picker("Language", selection: $selectedLocaleID) {
          ForEach(catalog.locales) { locale in
            Text(locale.title).tag(locale.id)
          }
        }
        if let preset = selectedPreset {
          LabeledContent(
            "Pixel size",
            value: "\(preset.pixelSize.width) × \(preset.pixelSize.height)"
          )
          LabeledContent("Render scale", value: formattedScale(preset.scale))
        }
      }
    }

    private var exportSection: some View {
      Section("Export") {
        if isExporting || isRenderingPreview {
          HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(isRenderingPreview ? "Rendering preview set…" : "Rendering final PNG files…")
              .foregroundStyle(style.secondaryTextColor)
          }
        }

        Button {
          exportSelected()
        } label: {
          Label("Export Selected PNG", systemImage: "square.and.arrow.up")
        }
        .disabled(isExporting || selectedDefinition == nil || selectedPreset == nil)

        Button {
          exportAll()
        } label: {
          Label("Export All Registered PNGs", systemImage: "square.and.arrow.up.on.square")
        }
        .disabled(isExporting || availableDefinitions.isEmpty || selectedPreset == nil)
      } footer: {
        Text(
          "Exports are opaque PNG files rendered at exact App Store dimensions. Batch preview uses the same final renderer."
        )
      }
    }

    @ToolbarContentBuilder
    private var studioToolbar: some ToolbarContent {
      ToolbarItemGroup(placement: .primaryAction) {
        if isRenderingPreview {
          ProgressView().controlSize(.small)
        } else {
          Button {
            renderPreviewSet()
          } label: {
            Image(systemName: "rectangle.stack.fill")
          }
          .disabled(availableDefinitions.isEmpty || selectedPreset == nil)
          .help("Preview screenshot set")
        }

        Button {
          exportSelected()
        } label: {
          Image(systemName: "square.and.arrow.up")
        }
        .disabled(isExporting || selectedDefinition == nil || selectedPreset == nil)
        .help("Export selected PNG")
      }
    }

    private var selectedDefinition: ScreenshotDefinition? {
      catalog.screenshots.first { $0.id == selectedScreenshotID }
    }

    private var selectedPreset: ScreenshotDevicePreset? {
      catalog.presets.first { $0.id == selectedPresetID }
    }

    private var selectedLocale: ScreenshotStudioLocale? {
      catalog.locales.first { $0.id == selectedLocaleID }
    }

    private var availableDefinitions: [ScreenshotDefinition] {
      guard let selectedPreset else { return catalog.screenshots }
      return catalog.screenshots.filter { $0.supports(selectedPreset) }
    }

    private var controlContext: ScreenshotStudioControlContext? {
      guard let definition = selectedDefinition,
        let preset = selectedPreset,
        let locale = selectedLocale
      else { return nil }

      return ScreenshotStudioControlContext(
        selectedScreenshotID: definition.id,
        selectedScreenshotTitle: definition.title,
        preset: preset,
        locale: locale,
        colorScheme: colorScheme
      )
    }

    private func repairSelectionForPreset() {
      guard let preset = selectedPreset else { return }
      if selectedDefinition?.supports(preset) != true {
        selectedScreenshotID = catalog.screenshots.first { $0.supports(preset) }?.id ?? ""
      }
    }

    private func renderPreviewSet() {
      guard let preset = selectedPreset, let locale = selectedLocale else { return }
      isRenderingPreview = true
      Task { @MainActor in
        await Task.yield()
        defer { isRenderingPreview = false }
        do {
          previewFiles = try engine.renderAll(
            catalog: catalog,
            preset: preset,
            locale: locale,
            colorScheme: colorScheme
          )
          isShowingSetPreview = !previewFiles.isEmpty
        } catch {
          errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
      }
    }

    private func exportSelected() {
      guard let definition = selectedDefinition,
        let preset = selectedPreset,
        let locale = selectedLocale,
        let directory = chooseDirectory()
      else { return }

      performExport {
        [
          try engine.render(
            definition: definition,
            preset: preset,
            locale: locale,
            colorScheme: colorScheme,
            outputDirectory: directory
          )
        ]
      }
    }

    private func exportAll() {
      guard let preset = selectedPreset,
        let locale = selectedLocale,
        let directory = chooseDirectory()
      else { return }

      performExport {
        try engine.renderAll(
          catalog: catalog,
          preset: preset,
          locale: locale,
          colorScheme: colorScheme,
          outputDirectory: directory
        )
      }
    }

    private func performExport(
      _ operation: @escaping @MainActor () throws -> [ScreenshotExportedFile]
    ) {
      isExporting = true
      Task { @MainActor in
        await Task.yield()
        defer { isExporting = false }
        do {
          let urls = try operation().map(\.url)
          if !urls.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
          }
        } catch {
          errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
      }
    }

    private func chooseDirectory() -> URL? {
      let panel = NSOpenPanel()
      panel.title = "Export App Store Screenshots"
      panel.message = "Choose a folder for the rendered PNG files."
      panel.prompt = "Export"
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.canCreateDirectories = true
      panel.allowsMultipleSelection = false
      return panel.runModal() == .OK ? panel.url : nil
    }

    private func formattedScale(_ scale: Double) -> String {
      scale.formatted(.number.precision(.fractionLength(0...2))) + "×"
    }

    private var errorBinding: Binding<Bool> {
      Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    }
  }

  @MainActor
  private struct ScreenshotStudioMacPreview: View {
    let definition: ScreenshotDefinition
    let preset: ScreenshotDevicePreset
    let locale: ScreenshotStudioLocale
    let colorScheme: ScreenshotStudioColorScheme
    let style: ScreenshotStudioStyle

    var body: some View {
      GeometryReader { proxy in
        let pointSize = CGSize(width: preset.pointWidth, height: preset.pointHeight)
        let scale = min(
          proxy.size.width / max(pointSize.width, 1),
          proxy.size.height / max(pointSize.height, 1)
        )
        let renderedSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)

        definition.makeContent()
          .environment(\.locale, Locale(identifier: locale.localeIdentifier))
          .environment(\.colorScheme, colorScheme.swiftUIColorScheme)
          .environment(\.displayScale, CGFloat(preset.scale))
          .frame(width: pointSize.width, height: pointSize.height)
          .clipped()
          .scaleEffect(scale, anchor: .topLeading)
          .frame(width: renderedSize.width, height: renderedSize.height, alignment: .topLeading)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .aspectRatio(preset.pixelSize.aspectRatio, contentMode: .fit)
      .background(style.elevatedSurfaceColor)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(style.borderColor)
      }
      .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
    }
  }

  @MainActor
  private struct ScreenshotStudioMacSetPreview: View {
    let files: [ScreenshotExportedFile]
    let catalog: ScreenshotCatalog
    let style: ScreenshotStudioStyle

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFileID: ScreenshotExportedFile.ID?

    init(
      files: [ScreenshotExportedFile],
      catalog: ScreenshotCatalog,
      initialScreenshotID: String,
      style: ScreenshotStudioStyle
    ) {
      self.files = files
      self.catalog = catalog
      self.style = style
      _selectedFileID = State(
        initialValue: files.first { $0.screenshotID == initialScreenshotID }?.id ?? files.first?.id
      )
    }

    var body: some View {
      NavigationSplitView {
        List(files, selection: $selectedFileID) { file in
          Text(title(for: file))
            .tag(file.id)
        }
        .navigationTitle("Preview Set")
        .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 320)
      } detail: {
        ZStack {
          ScreenshotStudioBackground(style: style)
          if let file = selectedFile,
            let image = NSImage(contentsOf: file.url)
          {
            Image(nsImage: image)
              .resizable()
              .scaledToFit()
              .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
              .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
              .padding(28)
          } else {
            ContentUnavailableView(
              "Preview Unavailable",
              systemImage: "photo.badge.exclamationmark"
            )
          }
        }
        .navigationTitle(selectedFile.map(title(for:)) ?? "Preview")
      }
      .frame(minWidth: 920, minHeight: 650)
      .tint(style.accentColor)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }

    private var selectedFile: ScreenshotExportedFile? {
      guard let selectedFileID else { return files.first }
      return files.first { $0.id == selectedFileID }
    }

    private func title(for file: ScreenshotExportedFile) -> String {
      catalog.screenshots.first { $0.id == file.screenshotID }?.title
        ?? file.url.deletingPathExtension().lastPathComponent
    }
  }

  private struct ScreenshotStudioBackground: View {
    let style: ScreenshotStudioStyle

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
#endif
