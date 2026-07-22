#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import SwiftUI

@MainActor
public struct ScreenshotStudio: View {
    private let catalog: ScreenshotCatalog
    private let controls: AnyView?
    private let engine = ScreenshotStudioEngine()

    @State private var screenshotID: String
    @State private var presetID: String
    @State private var localeID: String
    @State private var appearance: ScreenshotStudioColorScheme = .light
    @State private var isExporting = false
    @State private var errorMessage: String?

    public init(catalog: ScreenshotCatalog) {
        self.catalog = catalog
        controls = nil
        _screenshotID = State(initialValue: catalog.defaultScreenshotID ?? catalog.screenshots.first?.id ?? "")
        _presetID = State(initialValue: catalog.defaultPresetID ?? catalog.presets.first?.id ?? "")
        _localeID = State(initialValue: catalog.defaultLocaleID ?? catalog.locales.first?.id ?? "")
    }

    public init<Controls: View>(
        catalog: ScreenshotCatalog,
        @ViewBuilder controls: () -> Controls
    ) {
        self.catalog = catalog
        self.controls = AnyView(controls())
        _screenshotID = State(initialValue: catalog.defaultScreenshotID ?? catalog.screenshots.first?.id ?? "")
        _presetID = State(initialValue: catalog.defaultPresetID ?? catalog.presets.first?.id ?? "")
        _localeID = State(initialValue: catalog.defaultLocaleID ?? catalog.locales.first?.id ?? "")
    }

    public var body: some View {
        NavigationSplitView {
            List(availableScreenshots) { screenshot in
                Button {
                    screenshotID = screenshot.id
                } label: {
                    HStack {
                        Label(screenshot.title, systemImage: "photo")
                        Spacer()
                        if screenshot.id == screenshotID {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Screenshots")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            VStack(spacing: 0) {
                preview
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                Form {
                    Picker("Output preset", selection: $presetID) {
                        ForEach(catalog.presets) { preset in
                            Text(preset.title).tag(preset.id)
                        }
                    }
                    Picker("Appearance", selection: $appearance) {
                        ForEach(ScreenshotStudioColorScheme.allCases) { scheme in
                            Text(scheme.title).tag(scheme)
                        }
                    }
                    Picker("Language", selection: $localeID) {
                        ForEach(catalog.locales) { locale in
                            Text(locale.title).tag(locale.id)
                        }
                    }
                    if let preset {
                        LabeledContent("Pixel size", value: "\(preset.pixelSize.width) × \(preset.pixelSize.height)")
                    }
                    if let controls {
                        Section("App Controls") { controls }
                    }
                }
                .formStyle(.grouped)
                .frame(maxHeight: controls == nil ? 190 : 300)

                Divider()

                HStack(spacing: 12) {
                    if isExporting {
                        ProgressView().controlSize(.small)
                        Text("Rendering at final pixel dimensions…").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Export Selected PNG", action: exportSelected)
                        .disabled(isExporting || screenshot == nil || preset == nil)
                    Button("Export All PNGs", action: exportAll)
                        .buttonStyle(.borderedProminent)
                        .disabled(isExporting || availableScreenshots.isEmpty || preset == nil)
                }
                .padding(16)
            }
            .navigationTitle(screenshot?.title ?? "Screenshot Studio")
        }
        .frame(minWidth: 900, minHeight: 650)
        .onChange(of: presetID) { repairScreenshotSelection() }
        .alert("Screenshot Studio", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let screenshot, let preset, let locale {
            GeometryReader { proxy in
                let pointSize = CGSize(width: preset.pointWidth, height: preset.pointHeight)
                let scale = min(proxy.size.width / pointSize.width, proxy.size.height / pointSize.height)
                screenshot.makeContent()
                    .environment(\.locale, Locale(identifier: locale.localeIdentifier))
                    .environment(\.colorScheme, appearance.swiftUIColorScheme)
                    .environment(\.displayScale, CGFloat(preset.scale))
                    .frame(width: pointSize.width, height: pointSize.height)
                    .clipped()
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: pointSize.width * scale, height: pointSize.height * scale, alignment: .topLeading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(preset.pixelSize.aspectRatio, contentMode: .fit)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.secondary.opacity(0.18)) }
        } else {
            ContentUnavailableView(
                "Nothing to Preview",
                systemImage: "photo.badge.exclamationmark",
                description: Text("Register at least one screenshot and output preset.")
            )
        }
    }

    private var screenshot: ScreenshotDefinition? {
        catalog.screenshots.first { $0.id == screenshotID }
    }

    private var preset: ScreenshotDevicePreset? {
        catalog.presets.first { $0.id == presetID }
    }

    private var locale: ScreenshotStudioLocale? {
        catalog.locales.first { $0.id == localeID }
    }

    private var availableScreenshots: [ScreenshotDefinition] {
        guard let preset else { return catalog.screenshots }
        return catalog.screenshots.filter { $0.supports(preset) }
    }

    private func repairScreenshotSelection() {
        guard let preset, screenshot?.supports(preset) != true else { return }
        screenshotID = catalog.screenshots.first { $0.supports(preset) }?.id ?? ""
    }

    private func exportSelected() {
        guard let screenshot, let preset, let locale, let directory = chooseDirectory() else { return }
        performExport {
            [try engine.render(
                definition: screenshot,
                preset: preset,
                locale: locale,
                colorScheme: appearance,
                outputDirectory: directory
            )]
        }
    }

    private func exportAll() {
        guard let preset, let locale, let directory = chooseDirectory() else { return }
        performExport {
            try engine.renderAll(
                catalog: catalog,
                preset: preset,
                locale: locale,
                colorScheme: appearance,
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
                if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
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

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
#endif
