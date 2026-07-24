#if os(macOS)
  import SwiftUI
  import Testing
  @testable import AppFoundationPromoVideoStudio

  @MainActor
  @Suite("Promo Video Studio on macOS")
  struct PromoVideoStudioMacTests {
    @Test("Mac exposes the same social presets")
    func socialPresets() {
      #expect(
        PromoVideoOutputPreset.verticalFullHD.pixelSize
          == PromoVideoPixelSize(width: 1080, height: 1920))
      #expect(
        PromoVideoOutputPreset.landscapeFullHD.pixelSize
          == PromoVideoPixelSize(width: 1920, height: 1080))
      #expect(PromoVideoOutputPreset.socialDefaults.count == 4)
    }

    @Test("Timeline overlaps transitions deterministically")
    func timelineOverlap() {
      let project = PromoVideoProject(name: "Test") {
        PromoVideoSceneDefinition(
          id: "one",
          title: "One",
          duration: 2,
          transition: .crossfade,
          transitionDuration: 0.5
        ) { _ in Color.red }

        PromoVideoSceneDefinition(
          id: "two",
          title: "Two",
          duration: 2,
          transition: .none
        ) { _ in Color.blue }
      }

      #expect(project.startTime(forSceneAt: 1) == 1.5)
      #expect(project.totalDuration == 3.5)

      let position = project.timelinePosition(at: 1.75)
      #expect(position?.fromSceneIndex == 0)
      #expect(position?.toSceneIndex == 1)
      #expect(position?.transition == .crossfade)
      #expect(position?.isTransitioning == true)
    }
  }
#endif
