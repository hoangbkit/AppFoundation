#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI

  @MainActor
  public struct ScreenshotStudio: View {
    private let catalog: ScreenshotCatalog
    private let controls: AnyView?
    private let engine = ScreenshotStudioEngine()

    @State private var selectedScreenshotID: String
    @State private var selectedPresetID: String
    @State private var selectedLocaleID: String
    @State private var colorScheme: ScreenshotStudioColorScheme = .light
    @State private var exportedFiles: [ScreenshotExportedFile] = []
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var isShowingShareSheet = false

    public init(catalog: ScreenshotCatalog) {
      self.catalog = catalog
      self.controls = nil
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
      @ViewBuilder controls: () -> Controls
    ) {
      self.catalog = catalog
      self.controls = AnyView(controls())
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
      NavigationStack {
        Form {
          previewSection
          registrationSection
          outputSection

          if let controls {
            Section("App Controls") {
              controls
            }
          }

          exportSection
        }
        .navigationTitle("Screenshot Studio")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPresetID) {
          repairSelectionForPreset()
        }
        .sheet(isPresented: $isShowingShareSheet) {
          ExportShareSheet(
            files: exportedFiles.map {
              ExportFile(
                url: $0.url,
                suggestedFilename: $0.url.lastPathComponent
              )
            }
          )
        }
        .alert("Screenshot Studio", isPresented: errorBinding) {
          Button("OK", role: .cancel) {
            errorMessage = nil
          }
        } message: {
          Text(errorMessage ?? "")
        }
      }
    }

    @ViewBuilder
    private var previewSection: some View {
      Section("Preview") {
        if let definition = selectedDefinition,
          let preset = selectedPreset,
          let locale = selectedLocale
        {
          ScreenshotStudioPreview(
            definition: definition,
            preset: preset,
            locale: locale,
            colorScheme: colorScheme
          )
          .frame(maxWidth: .infinity)
          .listRowInsets(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
        } else {
          ContentUnavailableView(
            "Nothing to Preview",
            systemImage: "photo.badge.exclamationmark",
            description: Text("Register at least one screenshot and output preset.")
          )
        }
      }
    }

    private var registrationSection: some View {
      Section("Registered Screenshots") {
        Picker("Screenshot", selection: $selectedScreenshotID) {
          ForEach(availableDefinitions) { definition in
            Text(definition.title).tag(definition.id)
          }
        }

        if let definition = selectedDefinition,
          let preset = selectedPreset,
          !definition.supports(preset)
        {
          Label(
            "This screenshot does not support the selected preset.",
            systemImage: "exclamationmark.triangle.fill"
          )
          .foregroundStyle(.orange)
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
          LabeledContent(
            "Render scale",
            value: formattedScale(preset.scale)
          )
        }
      }
    }

    private var exportSection: some View {
      Section {
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

        if isExporting {
          HStack(spacing: 12) {
            ProgressView()
            Text("Rendering at final pixel dimensions…")
              .foregroundStyle(.secondary)
          }
        }
      } footer: {
        Text(
          "Exports are opaque PNG files rendered directly from the app-owned SwiftUI views. The package does not add templates or visual styling."
        )
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
      guard let preset = selectedPreset else { return catalog.screenshots }
      return catalog.screenshots.filter { $0.supports(preset) }
    }

    private func repairSelectionForPreset() {
      guard let preset = selectedPreset else { return }
      if selectedDefinition?.supports(preset) != true {
        selectedScreenshotID = catalog.screenshots.first { $0.supports(preset) }?.id ?? ""
      }
    }

    private func exportSelected() {
      guard let definition = selectedDefinition,
        let preset = selectedPreset,
        let locale = selectedLocale
      else {
        return
      }

      performExport {
        [
          try engine.render(
            definition: definition,
            preset: preset,
            locale: locale,
            colorScheme: colorScheme
          )
        ]
      }
    }

    private func exportAll() {
      guard let preset = selectedPreset,
        let locale = selectedLocale
      else {
        return
      }

      performExport {
        try engine.renderAll(
          catalog: catalog,
          preset: preset,
          locale: locale,
          colorScheme: colorScheme
        )
      }
    }

    private func performExport(
      operation: @escaping @MainActor () throws -> [ScreenshotExportedFile]
    ) {
      isExporting = true

      Task { @MainActor in
        await Task.yield()
        defer { isExporting = false }

        do {
          exportedFiles = try operation()
          isShowingShareSheet = !exportedFiles.isEmpty
        } catch {
          errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
      }
    }

    private func formattedScale(_ scale: Double) -> String {
      scale.formatted(.number.precision(.fractionLength(0...2))) + "×"
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

  @MainActor
  private struct ScreenshotStudioPreview: View {
    let definition: ScreenshotDefinition
    let preset: ScreenshotDevicePreset
    let locale: ScreenshotStudioLocale
    let colorScheme: ScreenshotStudioColorScheme

    var body: some View {
      GeometryReader { proxy in
        let pointSize = CGSize(
          width: CGFloat(preset.pointWidth),
          height: CGFloat(preset.pointHeight)
        )
        let scale = min(
          proxy.size.width / pointSize.width,
          proxy.size.height / pointSize.height
        )
        let renderedSize = CGSize(
          width: pointSize.width * scale,
          height: pointSize.height * scale
        )

        definition.makeContent()
          .environment(\.locale, Locale(identifier: locale.localeIdentifier))
          .environment(\.colorScheme, colorScheme.swiftUIColorScheme)
          .environment(\.displayScale, CGFloat(preset.scale))
          .frame(width: pointSize.width, height: pointSize.height)
          .clipped()
          .scaleEffect(scale, anchor: .topLeading)
          .frame(
            width: renderedSize.width,
            height: renderedSize.height,
            alignment: .topLeading
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      }
      .aspectRatio(CGFloat(preset.pixelSize.aspectRatio), contentMode: .fit)
      .background(Color.secondary.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(Color.secondary.opacity(0.18))
      }
    }
  }

#endif
