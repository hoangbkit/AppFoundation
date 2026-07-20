#if canImport(SwiftUI)
import SwiftUI

public struct DefaultThemePreview: View {
    private let theme: AppTheme

    public init(theme: AppTheme) {
        self.theme = theme
    }

    public var body: some View {
        theme.gradient
            .overlay(alignment: .bottomLeading) {
                Image(systemName: theme.symbolName)
                    .font(.title2.bold())
                    .foregroundStyle(theme.primaryForegroundColor)
                    .padding(12)
            }
    }
}

public struct ThemePickerView<Preview: View>: View {
    private let manager: ThemeManager
    private let title: String?
    private let showsCountdown: Bool
    private let onRequestUpgrade: (() -> Void)?
    private let preview: (AppTheme) -> Preview

    public init(
        manager: ThemeManager,
        title: String? = "App theme",
        showsCountdown: Bool = true,
        onRequestUpgrade: (() -> Void)? = nil,
        @ViewBuilder preview: @escaping (AppTheme) -> Preview
    ) {
        self.manager = manager
        self.title = title
        self.showsCountdown = showsCountdown
        self.onRequestUpgrade = onRequestUpgrade
        self.preview = preview
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(manager.catalog.themes) { theme in
                        themeButton(theme)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)

            if showsCountdown, manager.isPreviewActive {
                previewCountdown
            }
        }
    }

    private func themeButton(_ theme: AppTheme) -> some View {
        Button {
            let result = manager.select(theme)
            if case .requiresPro = result {
                onRequestUpgrade?()
            }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    preview(theme)
                        .frame(width: 116, height: 78)

                    stateBadge(for: theme)
                        .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            manager.isEffective(theme) ? theme.accentColor : theme.borderColor,
                            lineWidth: manager.isEffective(theme) ? 2 : 1
                        )
                }

                HStack(spacing: 4) {
                    Text(theme.title)
                        .font(.caption.weight(.semibold))
                    if theme.isPro {
                        Text("PRO")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(theme.accentColor)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: theme))
    }

    @ViewBuilder
    private func stateBadge(for theme: AppTheme) -> some View {
        if manager.isEffective(theme) {
            Image(systemName: manager.isPreviewing(theme) ? "clock.fill" : "checkmark.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.48))
        } else if theme.isPro && !manager.hasPro {
            Image(systemName: manager.canPreview(theme) ? "timer" : "lock.fill")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(7)
                .background(.black.opacity(0.28), in: Circle())
        }
    }

    private var previewCountdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.headline)
                    .foregroundStyle(manager.effectiveTheme.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Previewing \(manager.effectiveTheme.title)")
                        .font(.subheadline.weight(.bold))
                    Text("Returns to \(manager.catalog.fallbackTheme.title) in \(countdown)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                if let onRequestUpgrade {
                    Button("Unlock", action: onRequestUpgrade)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }

                Button("End") {
                    manager.endPreview()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 3)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Previewing \(manager.effectiveTheme.title). Returns to \(manager.catalog.fallbackTheme.title) in \(countdown)."
            )
        }
    }

    private var countdown: String {
        let seconds = manager.previewRemainingSeconds
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func accessibilityLabel(for theme: AppTheme) -> String {
        var parts = [theme.title]
        if theme.isPro { parts.append("Pro") }
        if manager.isPreviewing(theme) {
            parts.append("Previewing")
        } else if manager.isEffective(theme) {
            parts.append("Selected")
        } else if theme.isPro && !manager.hasPro {
            parts.append(manager.canPreview(theme) ? "Preview available" : "Locked")
        }
        return parts.joined(separator: ", ")
    }
}

public extension ThemePickerView where Preview == DefaultThemePreview {
    init(
        manager: ThemeManager,
        title: String? = "App theme",
        showsCountdown: Bool = true,
        onRequestUpgrade: (() -> Void)? = nil
    ) {
        self.init(
            manager: manager,
            title: title,
            showsCountdown: showsCountdown,
            onRequestUpgrade: onRequestUpgrade
        ) { theme in
            DefaultThemePreview(theme: theme)
        }
    }
}
#endif
