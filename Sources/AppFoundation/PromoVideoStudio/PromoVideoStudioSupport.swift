#if os(iOS) && canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit


public extension PromoVideoStudio where SceneControls == EmptyView, VideoControls == EmptyView {
    init(
        videos: [PromoVideoProject],
        style: PromoVideoStudioStyle = .standard
    ) {
        self.init(
            videos: videos,
            style: style,
            sceneControls: { _ in EmptyView() },
            videoConfigurationControls: { _ in EmptyView() }
        )
    }

    init(
        project: PromoVideoProject,
        style: PromoVideoStudioStyle = .standard
    ) {
        self.init(videos: [project], style: style)
    }
}

public extension PromoVideoStudio where VideoControls == EmptyView {
    init(
        videos: [PromoVideoProject],
        style: PromoVideoStudioStyle = .standard,
        @ViewBuilder sceneControls: @escaping (PromoVideoStudioControlContext) -> SceneControls
    ) {
        self.init(
            videos: videos,
            style: style,
            sceneControls: sceneControls,
            videoConfigurationControls: { _ in EmptyView() }
        )
    }

    init(
        project: PromoVideoProject,
        style: PromoVideoStudioStyle = .standard,
        @ViewBuilder sceneControls: @escaping (PromoVideoStudioControlContext) -> SceneControls
    ) {
        self.init(videos: [project], style: style, sceneControls: sceneControls)
    }
}

@MainActor
struct PromoVideoSceneThumbnail: View {
    let project: PromoVideoProject
    let sceneIndex: Int
    let preset: PromoVideoOutputPreset
    let frameRate: PromoVideoFrameRate
    let motionIntensity: PromoVideoMotionIntensity
    let isSelected: Bool
    let style: PromoVideoStudioStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            PromoVideoCompositionView(
                project: project,
                playhead: thumbnailPlayhead,
                preset: preset,
                frameRate: frameRate,
                motionIntensity: motionIntensity
            )
            .frame(width: 86, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        isSelected ? style.accentColor : style.borderColor,
                        lineWidth: isSelected ? 3 : 1
                    )
            }

            Text(project.scenes[sceneIndex].title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(style.primaryTextColor)
                .lineLimit(1)
                .frame(width: 86, alignment: .leading)
        }
    }

    private var thumbnailPlayhead: TimeInterval {
        project.startTime(forSceneAt: sceneIndex) + project.scenes[sceneIndex].duration * 0.55
    }
}

struct PromoVideoStudioBackground: View {
    let style: PromoVideoStudioStyle

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

struct PromoVideoShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
