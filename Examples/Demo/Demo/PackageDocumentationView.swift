import AppFoundation
import SwiftUI
import UIKit

struct PackageDocumentationView: View {
    private enum Scope: String, CaseIterable, Identifiable {
        case all = "All"
        case structure = "Structure"
        case api = "API"

        var id: Self { self }
    }

    @Environment(ThemeManager.self) private var themes

    @State private var searchText = ""
    @State private var scope: Scope = .all
    @State private var copiedID: String?

    private var theme: AppTheme { themes.effectiveTheme }
    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }

    private var filteredTree: [PackageDocumentationTreeItem] {
        guard !normalizedSearch.isEmpty else { return PackageDocumentationCatalog.sourceTree }
        return PackageDocumentationCatalog.sourceTree.filter {
            $0.path.localizedLowercase.contains(normalizedSearch)
        }
    }

    private var filteredAPIGroups: [PackageDocumentationAPIGroup] {
        guard !normalizedSearch.isEmpty else { return PackageDocumentationCatalog.apiGroups }
        return PackageDocumentationCatalog.apiGroups.compactMap { group in
            let items = group.items.filter { $0.searchableText.contains(normalizedSearch) }
            guard !items.isEmpty else { return nil }
            return PackageDocumentationAPIGroup(
                title: group.title,
                systemImage: group.systemImage,
                items: items
            )
        }
    }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            List {
                overviewSection

                if scope != .api {
                    sourceTreeSection
                }

                if scope != .structure {
                    publicAPISections
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle("Package Docs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search files, APIs, or descriptions")
        .searchScopes($scope) {
            ForEach(Scope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Copy package name", systemImage: "doc.on.doc") {
                        copy("AppFoundation", id: "package-name")
                    }

                    Button("Copy all public API names", systemImage: "list.bullet.clipboard") {
                        let names = PackageDocumentationCatalog.allAPIItems
                            .map(\.name)
                            .joined(separator: "\n")
                        copy(names, id: "all-api")
                    }
                } label: {
                    Image(systemName: copiedID == "all-api" ? "checkmark" : "ellipsis.circle")
                }
                .accessibilityLabel("Documentation actions")
            }
        }
        .tint(theme.accentColor)
    }

    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.accentColor)
                        .frame(width: 44, height: 44)
                        .background(
                            theme.elevatedSurfaceColor,
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("AppFoundation")
                            .font(.headline)
                        Text("Swift Package • iOS 26+ • macOS 15+")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryForegroundColor)
                    }

                    Spacer(minLength: 8)

                    copyButton(
                        text: "AppFoundation",
                        id: "package-name",
                        label: "Copy package name"
                    )
                }

                Text("Browse the package as a source tree or search the app-facing API catalog. Every row exposes copy actions for names, paths, summaries, and usage text.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(theme.surfaceColor)
    }

    @ViewBuilder
    private var sourceTreeSection: some View {
        Section {
            if filteredTree.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(theme.surfaceColor)
            } else {
                ForEach(filteredTree) { item in
                    sourceTreeRow(item)
                }
            }
        } header: {
            Label("Source tree", systemImage: "folder.fill")
        } footer: {
            Text("Indentation and guide lines show the folder hierarchy. Search matches the complete source path.")
        }
    }

    private func sourceTreeRow(_ item: PackageDocumentationTreeItem) -> some View {
        HStack(spacing: 10) {
            treeGuides(depth: item.depth)

            Image(systemName: item.kind == .folder ? "folder.fill" : "swift")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.kind == .folder ? theme.accentColor : theme.secondaryForegroundColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(item.kind == .folder ? .semibold : .regular))
                    .textSelection(.enabled)

                if item.kind == .file {
                    Text(item.path)
                        .font(.caption2.monospaced())
                        .foregroundStyle(theme.secondaryForegroundColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 8)

            copyButton(text: item.path, id: item.id, label: "Copy path")
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy name", systemImage: "doc.on.doc") {
                copy(item.name, id: item.id)
            }
            Button("Copy path", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath") {
                copy(item.path, id: item.id)
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private func treeGuides(depth: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<depth, id: \.self) { _ in
                Rectangle()
                    .fill(theme.borderColor)
                    .frame(width: 1, height: 34)
            }
        }
        .frame(width: CGFloat(depth) * 9, alignment: .leading)
    }

    @ViewBuilder
    private var publicAPISections: some View {
        if filteredAPIGroups.isEmpty {
            Section("Public API") {
                ContentUnavailableView.search(text: searchText)
            }
            .listRowBackground(theme.surfaceColor)
        } else {
            ForEach(filteredAPIGroups) { group in
                Section {
                    ForEach(group.items) { item in
                        publicAPIRow(item)
                    }
                } header: {
                    Label(group.title, systemImage: group.systemImage)
                }
            }
        }
    }

    private func publicAPIRow(_ item: PackageDocumentationAPIItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.name)
                    .font(.headline.monospaced())
                    .foregroundStyle(theme.primaryForegroundColor)
                    .textSelection(.enabled)

                Text(item.kind.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(theme.elevatedSurfaceColor, in: Capsule())

                Spacer(minLength: 8)

                copyButton(text: item.copyText, id: item.id, label: "Copy API documentation")
            }

            Text(item.summary)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryForegroundColor)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let usage = item.usage {
                HStack(alignment: .top, spacing: 8) {
                    Text(usage)
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.primaryForegroundColor)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    copyButton(text: usage, id: item.id + "#usage", label: "Copy usage")
                }
                .padding(10)
                .background(
                    theme.elevatedSurfaceColor,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }

            Label(item.sourcePath, systemImage: "doc.text")
                .font(.caption2.monospaced())
                .foregroundStyle(theme.secondaryForegroundColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy name", systemImage: "doc.on.doc") {
                copy(item.name, id: item.id)
            }
            Button("Copy description", systemImage: "text.quote") {
                copy(item.summary, id: item.id)
            }
            Button("Copy all", systemImage: "list.clipboard") {
                copy(item.copyText, id: item.id)
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private func copyButton(text: String, id: String, label: String) -> some View {
        Button {
            copy(text, id: id)
        } label: {
            Image(systemName: copiedID == id ? "checkmark.circle.fill" : "doc.on.doc")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(copiedID == id ? theme.accentColor : theme.secondaryForegroundColor)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func copy(_ text: String, id: String) {
        UIPasteboard.general.string = text
        copiedID = id
    }
}
