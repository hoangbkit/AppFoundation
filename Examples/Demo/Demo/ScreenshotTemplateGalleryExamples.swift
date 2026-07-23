import AppFoundation
import SwiftUI

@MainActor
struct HeroTemplateDemo: View {
  let settings: ScreenshotTemplateDemoSettings

  var body: some View {
    HeroScreenshotTemplate {
      screenshotTemplateDemoBackground(settings)
    } brand: {
      screenshotTemplateDemoBrand(settings)
    } message: {
      screenshotTemplateDemoMessage(
        "One clear promise.\nOne focused visual.",
        subtitle: "HeroScreenshotTemplate gives the first screenshot a confident hierarchy."
      )
    } visual: {
      TemplateDashboardFixture(
        accent: settings.mood.accent,
        showsDetails: settings.showDetails
      )
    } footer: {
      screenshotTemplateDemoFooter(
        "HeroScreenshotTemplate",
        systemImage: "rectangle.portrait.fill",
        settings: settings
      )
    }
  }
}

@MainActor
struct LayeredCardsTemplateDemo: View {
  let settings: ScreenshotTemplateDemoSettings

  var body: some View {
    LayeredCardsScreenshotTemplate {
      screenshotTemplateDemoBackground(settings)
    } brand: {
      screenshotTemplateDemoBrand(settings)
    } message: {
      screenshotTemplateDemoMessage(
        "Show depth without\nplacing a single card.",
        subtitle: "The template owns overlap, rotation, shadows, and visual order."
      )
    } primary: {
      TemplateFeatureCardFixture(
        title: "Screenshot Studio",
        subtitle: settings.showDetails ? "Preview and export" : nil,
        value: "10 templates",
        systemImage: "photo.stack.fill",
        accent: settings.mood.accent
      )
    } secondary: {
      TemplateFeatureCardFixture(
        title: "Themes",
        subtitle: settings.showDetails ? "App-owned style" : nil,
        value: "Flexible",
        systemImage: "paintpalette.fill",
        accent: settings.mood.accent
      )
    } tertiary: {
      TemplateFeatureCardFixture(
        title: "Exact Output",
        subtitle: settings.showDetails ? "Opaque PNG" : nil,
        value: "1320 × 2868",
        systemImage: "checkmark.seal.fill",
        accent: settings.mood.accent
      )
    } footer: {
      screenshotTemplateDemoFooter(
        "LayeredCardsScreenshotTemplate",
        systemImage: "square.3.layers.3d",
        settings: settings
      )
    }
  }
}

@MainActor
struct SplitFeatureTemplateDemo: View {
  let settings: ScreenshotTemplateDemoSettings

  var body: some View {
    SplitFeatureScreenshotTemplate(side: settings.splitSide) {
      screenshotTemplateDemoBackground(settings)
    } brand: {
      screenshotTemplateDemoBrand(settings)
    } message: {
      screenshotTemplateDemoMessage(
        "Feature copy and UI,\nperfectly balanced.",
        subtitle: "Choose the semantic side. The template handles every measurement."
      )
    } visual: {
      TemplateEditorFixture(
        accent: settings.mood.accent,
        showsDetails: settings.showDetails
      )
    } footer: {
      screenshotTemplateDemoFooter(
        "SplitFeatureScreenshotTemplate",
        systemImage: "rectangle.split.2x1.fill",
        settings: settings
      )
    }
  }
}

@MainActor
struct FloatingCardsTemplateDemo: View {
  let settings: ScreenshotTemplateDemoSettings

  var body: some View {
    FloatingCardsScreenshotTemplate {
      screenshotTemplateDemoBackground(settings)
    } brand: {
      screenshotTemplateDemoBrand(settings)
    } message: {
      screenshotTemplateDemoMessage(
        "Keep the main feature\nin the spotlight.",
        subtitle: "Supporting cards add context while the template protects the hierarchy."
      )
    } primary: {
      TemplateDashboardFixture(
        accent: settings.mood.accent,
        showsDetails: settings.showDetails
      )
    } leadingSupporting: {
      TemplateMetricFixture(
        value: "4.9",
        label: "Average rating",
        systemImage: "star.fill",
        accent: settings.mood.accent
      )
    } trailingSupporting: {
      TemplateMetricFixture(
        value: "10×",
        label: "Faster setup",
        systemImage: "bolt.fill",
        accent: settings.mood.accent
      )
    } footer: {
      screenshotTemplateDemoFooter(
        "FloatingCardsScreenshotTemplate",
        systemImage: "square.on.square.badge.person.crop",
        settings: settings
      )
    }
  }
}

@MainActor
struct WidgetGalleryTemplateDemo: View {
  let settings: ScreenshotTemplateDemoSettings

  var body: some View {
    WidgetGalleryScreenshotTemplate {
      screenshotTemplateDemoBackground(settings)
    } brand: {
      screenshotTemplateDemoBrand(settings)
    } message: {
      screenshotTemplateDemoMessage(
        "Beautiful at\nevery widget size.",
        subtitle: "Register three widget views. The template understands their proportions."
      )
    } small: {
      TemplateWidgetFixture(
        family: .small,
        accent: settings.mood.accent,
        showsDetails: settings.showDetails
      )
    } medium: {
      TemplateWidgetFixture(
        family: .medium,
        accent: settings.mood.accent,
        showsDetails: settings.showDetails
      )
    } large: {
      TemplateWidgetFixture(
        family: .large,
        accent: settings.mood.accent,
        showsDetails: settings.showDetails
      )
    } footer: {
      screenshotTemplateDemoFooter(
        "WidgetGalleryScreenshotTemplate",
        systemImage: "square.grid.2x2.fill",
        settings: settings
      )
    }
  }
}

@MainActor
struct BeforeAfterTemplateDemo: View {
  let settings: ScreenshotTemplateDemoSettings

  var body: some View {
    BeforeAfterScreenshotTemplate(
      beforeLabel: "Before",
      afterLabel: "Organized",
      labelTint: settings.mood.accent
    ) {
      screenshotTemplateDemoBackground(settings)
    } brand: {
      screenshotTemplateDemoBrand(settings)
    } message: {
      screenshotTemplateDemoMessage(
        "Make the improvement\nimpossible to miss.",
        subtitle: "Two registered states become a clean, equally weighted comparison."
      )
    } before: {
      TemplateCleanupFixture(
        isOrganized: false,
        accent: settings.mood.accent,
        showsDetails: settings.showDetails
      )
    } after: {
      TemplateCleanupFixture(
        isOrganized: true,
        accent: settings.mood.accent,
        showsDetails: settings.showDetails
      )
    } footer: {
      screenshotTemplateDemoFooter(
        "BeforeAfterScreenshotTemplate",
        systemImage: "rectangle.split.2x1",
        settings: settings
      )
    }
  }
}

@MainActor
struct FeatureStepsTemplateDemo: View {
  let settings: ScreenshotTemplateDemoSettings

  var body: some View {
    FeatureStepsScreenshotTemplate(
      firstTitle: "Register",
      secondTitle: "Customize",
      thirdTitle: "Export",
      accent: settings.mood.accent
    ) {
      screenshotTemplateDemoBackground(settings)
    } brand: {
      screenshotTemplateDemoBrand(settings)
    } message: {
      screenshotTemplateDemoMessage(
        "Explain the workflow\nin three quick steps.",
        subtitle: "The app provides each step view. The template owns the sequence."
      )
    } first: {
      TemplateStepFixture(
        systemImage: "plus.rectangle.on.rectangle",
        title: settings.showDetails ? "Add SwiftUI views" : nil,
        accent: settings.mood.accent
      )
    } second: {
      TemplateStepFixture(
        systemImage: "slider.horizontal.3",
        title: settings.showDetails ? "Choose app style" : nil,
        accent: settings.mood.accent
      )
    } third: {
      TemplateStepFixture(
        systemImage: "square.and.arrow.up.fill",
        title: settings.showDetails ? "Render exact PNGs" : nil,
        accent: settings.mood.accent
      )
    } footer: {
      screenshotTemplateDemoFooter(
        "FeatureStepsScreenshotTemplate",
        systemImage: "list.number",
        settings: settings
      )
    }
  }
}

@MainActor
struct DeviceFocusTemplateDemo: View {
  let settings: ScreenshotTemplateDemoSettings

  var body: some View {
    DeviceFocusScreenshotTemplate {
      screenshotTemplateDemoBackground(settings)
    } brand: {
      screenshotTemplateDemoBrand(settings)
    } message: {
      screenshotTemplateDemoMessage(
        "Let the real interface\ndo the selling.",
        subtitle: "One complete screen receives maximum space and a controlled presentation."
      )
    } visual: {
      TemplatePhoneScreenFixture(
        accent: settings.mood.accent,
        showsDetails: settings.showDetails
      )
    } footer: {
      screenshotTemplateDemoFooter(
        "DeviceFocusScreenshotTemplate",
        systemImage: "iphone.gen3",
        settings: settings
      )
    }
  }
}

@MainActor
struct ComparisonGridTemplateDemo: View {
  let settings: ScreenshotTemplateDemoSettings

  var body: some View {
    ComparisonGridScreenshotTemplate(
      labels: ["Paper", "Midnight", "Aurora", "Minimal"],
      labelColor: .white
    ) {
      screenshotTemplateDemoBackground(settings)
    } brand: {
      screenshotTemplateDemoBrand(settings)
    } message: {
      screenshotTemplateDemoMessage(
        "Compare four styles\nat one glance.",
        subtitle: "A stable grid keeps every option clear and equally important."
      )
    } first: {
      TemplateThemeFixture(style: .paper, accent: settings.mood.accent)
    } second: {
      TemplateThemeFixture(style: .midnight, accent: settings.mood.accent)
    } third: {
      TemplateThemeFixture(style: .aurora, accent: settings.mood.accent)
    } fourth: {
      TemplateThemeFixture(style: .minimal, accent: settings.mood.accent)
    } footer: {
      screenshotTemplateDemoFooter(
        "ComparisonGridScreenshotTemplate",
        systemImage: "square.grid.2x2",
        settings: settings
      )
    }
  }
}

@MainActor
struct ContinuousCampaignTemplateDemo: View {
  let settings: ScreenshotTemplateDemoSettings

  var body: some View {
    ContinuousCampaignScreenshotTemplate(
      pageIndex: settings.continuousPage,
      pageCount: 5,
      accent: settings.mood.accent
    ) {
      screenshotTemplateDemoBackground(settings)
    } brand: {
      screenshotTemplateDemoBrand(settings)
    } message: {
      screenshotTemplateDemoMessage(
        "Build one connected\nApp Store campaign.",
        subtitle: "Page-aware movement and indicators keep the entire set consistent."
      )
    } visual: {
      TemplateCampaignFixture(
        pageIndex: settings.continuousPage,
        accent: settings.mood.accent,
        showsDetails: settings.showDetails
      )
    } footer: {
      screenshotTemplateDemoFooter(
        "ContinuousCampaignScreenshotTemplate",
        systemImage: "rectangle.stack.fill",
        settings: settings
      )
    }
  }
}
