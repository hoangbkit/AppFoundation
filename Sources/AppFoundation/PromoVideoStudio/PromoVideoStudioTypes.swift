#if os(iOS) && canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

public struct PromoVideoStudioStyle: Sendable {
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

    public static let standard = PromoVideoStudioStyle(accentColor: .accentColor)
}

public enum PromoVideoStudioControlScope: String, CaseIterable, Identifiable, Sendable {
    case scene
    case video

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .scene: "Scene"
        case .video: "Video"
        }
    }
}

public struct PromoVideoStudioControlContext: Sendable {
    public let selectedSceneID: String
    public let selectedSceneTitle: String
    public let selectedSceneIndex: Int
    public let sceneCount: Int
    public let preset: PromoVideoOutputPreset
    public let frameRate: PromoVideoFrameRate
    public let motionIntensity: PromoVideoMotionIntensity
    public let playhead: TimeInterval
    public let totalDuration: TimeInterval

    public init(
        selectedSceneID: String,
        selectedSceneTitle: String,
        selectedSceneIndex: Int,
        sceneCount: Int,
        preset: PromoVideoOutputPreset,
        frameRate: PromoVideoFrameRate,
        motionIntensity: PromoVideoMotionIntensity,
        playhead: TimeInterval,
        totalDuration: TimeInterval
    ) {
        self.selectedSceneID = selectedSceneID
        self.selectedSceneTitle = selectedSceneTitle
        self.selectedSceneIndex = selectedSceneIndex
        self.sceneCount = sceneCount
        self.preset = preset
        self.frameRate = frameRate
        self.motionIntensity = motionIntensity
        self.playhead = playhead
        self.totalDuration = totalDuration
    }
}

#endif
