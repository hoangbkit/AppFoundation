import AppFoundation
import Observation
import SwiftUI

@MainActor
@Observable
final class DemoPromoVideoSettings {
    var mood: DemoPromoVideoMood = .indigo
    var backgroundStyle: ScreenshotBackgroundStyle = .aurora
    var showDetails = true
    var emphasizeExport = true
}

enum DemoPromoVideoMood: String, CaseIterable, Identifiable {
    case indigo
    case rose
    case ocean

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var accent: Color {
        switch self {
        case .indigo: .indigo
        case .rose: .pink
        case .ocean: .cyan
        }
    }

    var colors: [Color] {
        switch self {
        case .indigo:
            [
                Color(red: 0.05, green: 0.04, blue: 0.15),
                Color(red: 0.18, green: 0.11, blue: 0.42),
                Color(red: 0.43, green: 0.21, blue: 0.82),
                Color(red: 0.18, green: 0.46, blue: 0.92),
            ]
        case .rose:
            [
                Color(red: 0.22, green: 0.04, blue: 0.11),
                Color(red: 0.57, green: 0.10, blue: 0.28),
                Color(red: 0.96, green: 0.31, blue: 0.56),
                Color(red: 0.96, green: 0.56, blue: 0.33),
            ]
        case .ocean:
            [
                Color(red: 0.02, green: 0.07, blue: 0.12),
                Color(red: 0.03, green: 0.23, blue: 0.30),
                Color(red: 0.05, green: 0.56, blue: 0.64),
                Color(red: 0.18, green: 0.34, blue: 0.76),
            ]
        }
    }
}

@MainActor
struct PromoVideoStudioDemoView: View {
    @State private var settings = DemoPromoVideoSettings()

    var body: some View {
        PromoVideoStudio(
            videos: DemoPromoVideoProject.makeAll(settings: settings)
        ) { context in
            DemoPromoVideoSceneControls(settings: settings, context: context)
        } videoConfigurationControls: { _ in
            DemoPromoVideoConfigurationControls(settings: settings)
        }
    }
}
