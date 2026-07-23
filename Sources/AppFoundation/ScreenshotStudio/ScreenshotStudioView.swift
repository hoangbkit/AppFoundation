#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

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
        surfaceColor: Color = Color(uiColor: .secondarySystemGroupedBackground),
        elevatedSurfaceColor: Color = Color(uiColor: .tertiarySystemGroupedBackground),
        borderColor: Color = Color.primary.opacity(0.10),
        backgroundColor: Color = Color(uiColor: .systemGroupedBackground),
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
    @State private var exportedFiles: [ScreenshotExportedFile] = []
    @State private var previewFiles: [ScreenshotExportedFile] = []
    @State private var isExporting = false
    @State private var isRenderingPreview = false
    @State private var errorMessage: String?
    @State private var isShowingShareSheet = false
    @State private var isShowingSetPreview = false

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

    /// Backward-compatible initializer. The supplied view appears in App Config.
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
        @ViewBuilder selectedScreenshotControls: @escaping (ScreenshotStudioControlContext) -> SelectedControls,
        @ViewBuilder appConfigurationControls: @escaping (ScreenshotStudioControlContext) -> AppControls
    ) {
        self.catalog = catalog
        self.style = style
        self.selectedScreenshotControls = { context in
            AnyView(selectedScreenshotControls(context))
        }
        self.appConfigurationControls = { context in
            AnyView(appConfigurationControls(context))
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

    public var body: some View {
        ZStack {
            ScreenshotStudioBackground(style: style)

            Form {
                previewSection
                controlModeSection

                switch controlMode {
                case .selectedScreenshot:
                    registrationSection
                    if let selectedScreenshotControls, let controlContext {
                        selectedScreenshotControls(controlContext)
                            .listRowBackground(style.surfaceColor)
                    }
                case .appConfiguration:
                    outputSection
                    if let appConfigurationControls, let controlContext {
                        appConfigurationControls(controlContext)
                            .listRowBackground(style.surfaceColor)
                    }
                }

                exportSection
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(style.primaryTextColor)
        }
        .navigationTitle("Screenshot Studio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(style.accentColor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isRenderingPreview {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        renderPreviewSet()
                    } label: {
                        Image(systemName: "rectangle.stack.fill")
                    }
                    .accessibilityLabel("Preview Screenshot Set")
                    .disabled(availableDefinitions.isEmpty || selectedPreset == nil)
                }
            }
        }
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
        .fullScreenCover(isPresented: $isShowingSetPreview) {
            ScreenshotStudioSetPreview(
                files: previewFiles,
                catalog: catalog,
                initialScreenshotID: selectedScreenshotID,
                style: style
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
                    colorScheme: colorScheme,
                    style: style
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
        .listRowBackground(style.surfaceColor)
    }

    private var controlModeSection: some View {
        Section {
            Picker("Controls", selection: $controlMode) {
                ForEach(ScreenshotStudioControlMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .listRowBackground(style.surfaceColor)
    }

    private var registrationSection: some View {
        Section("Selected Screenshot") {
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
        .listRowBackground(style.surfaceColor)
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
        .listRowBackground(style.surfaceColor)
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
                        .foregroundStyle(style.secondaryTextColor)
                }
            }
        } footer: {
            Text(
                "Exports are opaque PNG files rendered at the selected App Store dimensions. Apps may compose custom views or use AppFoundation screenshot templates."
            )
        }
        .listRowBackground(style.surfaceColor)
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

    private var controlContext: ScreenshotStudioControlContext? {
        guard let definition = selectedDefinition,
              let preset = selectedPreset,
              let locale = selectedLocale
        else {
            return nil
        }

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
        guard let preset = selectedPreset,
              let locale = selectedLocale
        else {
            return
        }

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
    let style: ScreenshotStudioStyle

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
private struct ScreenshotStudioSetPreview: View {
    @Environment(\.dismiss) private var dismiss

    let files: [ScreenshotExportedFile]
    let catalog: ScreenshotCatalog
    let style: ScreenshotStudioStyle
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
        NavigationStack {
            ZStack {
                ScreenshotStudioBackground(style: style)

                Group {
                    if files.isEmpty {
                        ContentUnavailableView(
                            "Nothing to Preview",
                            systemImage: "rectangle.stack.badge.exclamationmark"
                        )
                    } else {
                        TabView(selection: $selectedFileID) {
                            ForEach(files) { file in
                                VStack(spacing: 14) {
                                    if let image = UIImage(contentsOfFile: file.url.path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                                    } else {
                                        ContentUnavailableView(
                                            "Preview Unavailable",
                                            systemImage: "photo.badge.exclamationmark"
                                        )
                                    }

                                    Text(title(for: file))
                                        .font(.headline)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 18)
                                .padding(.top, 12)
                                .padding(.bottom, 42)
                                .tag(Optional(file.id))
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                    }
                }
            }
            .foregroundStyle(style.primaryTextColor)
            .navigationTitle("Preview Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(style.accentColor)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
