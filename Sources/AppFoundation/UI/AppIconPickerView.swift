#if canImport(SwiftUI)
import Foundation
import SwiftUI
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)
public struct AppIconOption: Identifiable {
    public let id: String
    public let title: String
    public let alternateIconName: String?
    public let previewImageName: String
    public let previewBundle: Bundle
    public let accentColor: Color
    public let requiresUnlock: Bool

    public init(
        id: String? = nil,
        title: String,
        alternateIconName: String?,
        previewImageName: String,
        previewBundle: Bundle = .main,
        accentColor: Color,
        requiresUnlock: Bool = false
    ) {
        precondition(!title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "App icon title cannot be empty")
        precondition(!previewImageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "App icon preview image name cannot be empty")

        self.id = id ?? alternateIconName ?? "primary"
        self.title = title
        self.alternateIconName = alternateIconName
        self.previewImageName = previewImageName
        self.previewBundle = previewBundle
        self.accentColor = accentColor
        self.requiresUnlock = requiresUnlock
    }
}

public extension AppIconOption {
    init?(
        theme: AppTheme,
        previewImageName: String? = nil,
        previewBundle: Bundle = .main
    ) {
        guard let resolvedPreviewImageName = previewImageName ?? theme.previewImageName else {
            return nil
        }

        self.init(
            id: theme.id,
            title: theme.title,
            alternateIconName: theme.alternateIconName,
            previewImageName: resolvedPreviewImageName,
            previewBundle: previewBundle,
            accentColor: theme.accentColor,
            requiresUnlock: theme.isPro
        )
    }
}
#endif

#if canImport(SwiftUI) && canImport(UIKit)
@MainActor
public struct AppIconPickerView: View {
    private let icons: [AppIconOption]
    private let isLocked: (AppIconOption) -> Bool
    private let onRequestUnlock: (AppIconOption) -> Void
    private let onSelectionChanged: ((AppIconOption) -> Void)?
    private let failureTitle: String
    private let failureFallbackMessage: String

    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedIconName: String?
    @State private var applyingIconID: String?
    @State private var errorMessage: String?

    public init(
        icons: [AppIconOption],
        isLocked: @escaping (AppIconOption) -> Bool = { $0.requiresUnlock },
        onRequestUnlock: @escaping (AppIconOption) -> Void = { _ in },
        onSelectionChanged: ((AppIconOption) -> Void)? = nil,
        failureTitle: String = "Couldn’t change app icon",
        failureFallbackMessage: String = "Please try again."
    ) {
        self.icons = icons
        self.isLocked = isLocked
        self.onRequestUnlock = onRequestUnlock
        self.onSelectionChanged = onSelectionChanged
        self.failureTitle = failureTitle
        self.failureFallbackMessage = failureFallbackMessage
    }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(icons) { icon in
                    iconButton(icon)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .task {
            refreshSelection()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshSelection()
            }
        }
        .alert(
            failureTitle,
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? failureFallbackMessage)
        }
    }

    private func iconButton(_ icon: AppIconOption) -> some View {
        let selected = selectedIconName == icon.alternateIconName
        let locked = isLocked(icon)
        let applying = applyingIconID == icon.id

        return Button {
            guard !locked else {
                onRequestUnlock(icon)
                return
            }

            apply(icon)
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(icon.previewImageName, bundle: icon.previewBundle)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(
                                    selected ? icon.accentColor : Color.primary.opacity(0.14),
                                    lineWidth: selected ? 2 : 1
                                )
                        }

                    statusBadge(selected: selected, applying: applying)
                        .offset(x: 5, y: -5)
                }

                HStack(spacing: 4) {
                    Text(icon.title)
                        .font(.caption2.weight(.bold))
                    if icon.requiresUnlock {
                        Text("PRO")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(icon.accentColor)
                    }
                }
                .foregroundStyle(.primary)
                .lineLimit(1)
            }
            .frame(width: 82)
        }
        .buttonStyle(.plain)
        .disabled(applyingIconID != nil)
        .accessibilityLabel("\(icon.title) app icon")
        .accessibilityValue(accessibilityValue(selected: selected, locked: locked, applying: applying))
        .accessibilityHint(locked ? "Opens upgrade options." : "Changes the app icon.")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func statusBadge(selected: Bool, applying: Bool) -> some View {
        if applying {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
                .padding(6)
                .background(.black.opacity(0.62), in: Circle())
        } else if selected {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.5))
        }
    }

    private func apply(_ icon: AppIconOption) {
        Task { @MainActor in
            applyingIconID = icon.id
            defer { applyingIconID = nil }

            do {
                try await AppIconManager.apply(iconName: icon.alternateIconName)
                refreshSelection()
                onSelectionChanged?(icon)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshSelection() {
        selectedIconName = AppIconManager.currentIconName
    }

    private func accessibilityValue(selected: Bool, locked: Bool, applying: Bool) -> String {
        if applying { return "Applying" }
        if selected { return "Selected" }
        if locked { return "Pro" }
        return "Available"
    }
}

@MainActor
public struct AppIconPickerSection: View {
    private let icons: [AppIconOption]
    private let title: String
    private let footer: String?
    private let isLocked: (AppIconOption) -> Bool
    private let onRequestUnlock: (AppIconOption) -> Void
    private let onSelectionChanged: ((AppIconOption) -> Void)?

    public init(
        icons: [AppIconOption],
        title: String = "App Icon",
        footer: String? = nil,
        isLocked: @escaping (AppIconOption) -> Bool = { $0.requiresUnlock },
        onRequestUnlock: @escaping (AppIconOption) -> Void = { _ in },
        onSelectionChanged: ((AppIconOption) -> Void)? = nil
    ) {
        self.icons = icons
        self.title = title
        self.footer = footer
        self.isLocked = isLocked
        self.onRequestUnlock = onRequestUnlock
        self.onSelectionChanged = onSelectionChanged
    }

    public var body: some View {
        Section {
            AppIconPickerView(
                icons: icons,
                isLocked: isLocked,
                onRequestUnlock: onRequestUnlock,
                onSelectionChanged: onSelectionChanged
            )
        } header: {
            Text(title)
        } footer: {
            if let footer {
                Text(footer)
            }
        }
    }
}

public typealias AppIconsPickerView = AppIconPickerView
public typealias AppIconsPickerSection = AppIconPickerSection
#endif
