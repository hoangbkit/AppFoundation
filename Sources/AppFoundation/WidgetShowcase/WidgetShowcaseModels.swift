import Foundation

public enum WidgetShowcaseFamily: String, CaseIterable, Identifiable, Sendable, Hashable {
    case small
    case medium
    case large

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    public var systemImage: String {
        switch self {
        case .small: "square"
        case .medium: "rectangle"
        case .large: "square.fill"
        }
    }

    public var aspectRatio: Double {
        switch self {
        case .small: 1
        case .medium: 2.08
        case .large: 0.95
        }
    }

    public var cornerRadius: Double {
        switch self {
        case .small: 23
        case .medium: 24
        case .large: 26
        }
    }

    public func previewSize(availableWidth: Double) -> WidgetShowcaseSize {
        let width: Double
        switch self {
        case .small:
            width = min(170, max(138, (availableWidth - 14) / 2))
        case .medium, .large:
            width = min(370, max(278, availableWidth))
        }

        return WidgetShowcaseSize(width: width, height: width / aspectRatio)
    }
}

public struct WidgetShowcaseSize: Equatable, Hashable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum WidgetShowcaseAccess: String, Sendable, Hashable {
    case free
    case pro
}

public struct WidgetShowcaseDescriptor: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let detail: String
    public let family: WidgetShowcaseFamily
    public let access: WidgetShowcaseAccess
    public let configurationName: String?
    public let tags: [String]

    public init(
        id: String,
        title: String,
        subtitle: String,
        detail: String,
        family: WidgetShowcaseFamily,
        access: WidgetShowcaseAccess = .free,
        configurationName: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.family = family
        self.access = access
        self.configurationName = configurationName
        self.tags = tags
    }
}

public struct WidgetInstallGoal: Identifiable, Equatable, Hashable, Sendable {
    public let widgetID: String?
    public let title: String?
    public let family: WidgetShowcaseFamily?
    public let configurationName: String?

    public static let general = WidgetInstallGoal()

    public init(
        widgetID: String? = nil,
        title: String? = nil,
        family: WidgetShowcaseFamily? = nil,
        configurationName: String? = nil
    ) {
        self.widgetID = widgetID
        self.title = title
        self.family = family
        self.configurationName = configurationName
    }

    public init(descriptor: WidgetShowcaseDescriptor) {
        self.init(
            widgetID: descriptor.id,
            title: descriptor.title,
            family: descriptor.family,
            configurationName: descriptor.configurationName
        )
    }

    public var id: String {
        [widgetID ?? "general", family?.rawValue ?? "any", configurationName ?? "default"]
            .joined(separator: "-")
    }

    public var isSpecific: Bool { widgetID != nil }
}

public struct WidgetInstallStep: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let systemImage: String
    public let title: String
    public let explanation: String

    public init(id: String, systemImage: String, title: String, explanation: String) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
        self.explanation = explanation
    }
}

public struct WidgetInstallGuideConfiguration: Equatable, Hashable, Sendable {
    public let appName: String
    public let widgetSearchName: String
    public let galleryTitle: String
    public let gallerySubtitle: String
    public let tip: String

    public init(
        appName: String,
        widgetSearchName: String? = nil,
        galleryTitle: String = "Widgets",
        gallerySubtitle: String = "Choose a design for every space",
        tip: String = "You can return to this gallery anytime to preview another size or design."
    ) {
        self.appName = appName
        self.widgetSearchName = widgetSearchName ?? appName
        self.galleryTitle = galleryTitle
        self.gallerySubtitle = gallerySubtitle
        self.tip = tip
    }

    public func steps(for goal: WidgetInstallGoal) -> [WidgetInstallStep] {
        var result = [
            WidgetInstallStep(
                id: "edit-home-screen",
                systemImage: "hand.tap.fill",
                title: "Edit your Home Screen",
                explanation: "Touch and hold an empty area until the app icons begin to move."
            ),
            WidgetInstallStep(
                id: "open-widget-gallery",
                systemImage: "plus",
                title: "Open the widget gallery",
                explanation: "Tap Edit in the top-left corner, then tap Add Widget."
            ),
            WidgetInstallStep(
                id: "find-app",
                systemImage: "magnifyingglass",
                title: "Find \(widgetSearchName)",
                explanation: "Search for \(widgetSearchName) and select it from the widget gallery."
            ),
            WidgetInstallStep(
                id: "choose-size",
                systemImage: "rectangle.3.group",
                title: chooseSizeTitle(for: goal),
                explanation: chooseSizeExplanation(for: goal)
            ),
        ]

        if let configurationName = goal.configurationName {
            result.append(
                WidgetInstallStep(
                    id: "configure-widget",
                    systemImage: "slider.horizontal.3",
                    title: "Choose \(configurationName)",
                    explanation: "Touch and hold the new widget, tap Edit Widget, then select \(configurationName)."
                )
            )
        }

        return result
    }

    private func chooseSizeTitle(for goal: WidgetInstallGoal) -> String {
        guard let family = goal.family else { return "Choose a size" }
        return "Add the \(family.title.lowercased()) widget"
    }

    private func chooseSizeExplanation(for goal: WidgetInstallGoal) -> String {
        guard let family = goal.family else {
            return "Swipe through the available sizes, tap Add Widget, place it where you want, then tap Done."
        }

        return "Swipe to the \(family.title.lowercased()) preview, tap Add Widget, place it where you want, then tap Done."
    }
}
