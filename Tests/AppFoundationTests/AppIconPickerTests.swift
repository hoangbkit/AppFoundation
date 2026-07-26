import Testing
@testable import AppFoundation

#if canImport(SwiftUI)
import SwiftUI

@Suite("App icon picker")
struct AppIconPickerTests {
    @Test("Primary icon receives a stable fallback identifier")
    func primaryIconIdentifier() {
        let icon = AppIconOption(
            title: "Default",
            alternateIconName: nil,
            previewImageName: "AppIconPreview",
            accentColor: .accentColor
        )

        #expect(icon.id == "primary")
        #expect(icon.alternateIconName == nil)
        #expect(icon.requiresUnlock == false)
    }

    @Test("Theme initializer maps icon metadata and access")
    func themeMapping() {
        let theme = FoundationThemes.rose
            .withAccess(.pro)
            .withAlternateIconName("RoseIcon")
            .withPreviewImageName("RoseIconPreview")

        let icon = AppIconOption(theme: theme)

        #expect(icon?.id == theme.id)
        #expect(icon?.title == theme.title)
        #expect(icon?.alternateIconName == "RoseIcon")
        #expect(icon?.previewImageName == "RoseIconPreview")
        #expect(icon?.requiresUnlock == true)
    }

    @Test("Theme initializer requires a preview asset")
    func missingThemePreview() {
        let theme = FoundationThemes.rose.withPreviewImageName(nil)

        #expect(AppIconOption(theme: theme) == nil)
    }
}
#endif
