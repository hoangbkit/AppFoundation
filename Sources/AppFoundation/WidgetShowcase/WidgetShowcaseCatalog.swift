#if canImport(SwiftUI)
import SwiftUI

public struct WidgetShowcaseItem: Identifiable {
    public let descriptor: WidgetShowcaseDescriptor
    private let makePreview: () -> AnyView

    public var id: String { descriptor.id }
    public var title: String { descriptor.title }
    public var subtitle: String { descriptor.subtitle }
    public var detail: String { descriptor.detail }
    public var family: WidgetShowcaseFamily { descriptor.family }
    public var access: WidgetShowcaseAccess { descriptor.access }
    public var configurationName: String? { descriptor.configurationName }
    public var tags: [String] { descriptor.tags }

    public init<Preview: View>(
        descriptor: WidgetShowcaseDescriptor,
        @ViewBuilder preview: @escaping () -> Preview
    ) {
        self.descriptor = descriptor
        self.makePreview = { AnyView(preview()) }
    }

    public init<Preview: View>(
        id: String,
        title: String,
        subtitle: String,
        detail: String,
        family: WidgetShowcaseFamily,
        access: WidgetShowcaseAccess = .free,
        configurationName: String? = nil,
        tags: [String] = [],
        @ViewBuilder preview: @escaping () -> Preview
    ) {
        self.init(
            descriptor: WidgetShowcaseDescriptor(
                id: id,
                title: title,
                subtitle: subtitle,
                detail: detail,
                family: family,
                access: access,
                configurationName: configurationName,
                tags: tags
            ),
            preview: preview
        )
    }

    @MainActor
    public func preview() -> AnyView {
        makePreview()
    }
}

public struct WidgetShowcaseCatalog {
    public let items: [WidgetShowcaseItem]

    public init(items: [WidgetShowcaseItem]) {
        var unique: [WidgetShowcaseItem] = []
        var indices: [String: Int] = [:]

        for item in items {
            if let index = indices[item.id] {
                unique[index] = item
            } else {
                indices[item.id] = unique.count
                unique.append(item)
            }
        }

        self.items = unique
    }

    public func items(for family: WidgetShowcaseFamily) -> [WidgetShowcaseItem] {
        items.filter { $0.family == family }
    }

    public func item(id: String) -> WidgetShowcaseItem? {
        items.first { $0.id == id }
    }

    public var families: [WidgetShowcaseFamily] {
        WidgetShowcaseFamily.allCases.filter { !items(for: $0).isEmpty }
    }

    public var freeItemCount: Int {
        items.count { $0.access == .free }
    }

    public var proItemCount: Int {
        items.count { $0.access == .pro }
    }
}
#endif
