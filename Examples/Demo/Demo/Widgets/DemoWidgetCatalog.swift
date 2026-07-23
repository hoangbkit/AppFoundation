import AppFoundation
import SwiftUI

struct DemoWidgetCatalog {
    static func make(theme: AppTheme) -> WidgetShowcaseCatalog {
        WidgetShowcaseCatalog(items: [
            WidgetShowcaseItem(
                id: "commerce-pulse-small",
                title: "Commerce Pulse",
                subtitle: "Entitlement and StoreKit status",
                detail: "A compact premium-state widget highlighting PurchaseManager, verified entitlement state, and Debug purchase simulation.",
                family: .small,
                configurationName: "Commerce Pulse",
                tags: ["StoreKit 2", "Entitlements"]
            ) {
                DemoCommercePulseSmall(theme: theme)
            },
            WidgetShowcaseItem(
                id: "theme-orbit-small",
                title: "Theme Orbit",
                subtitle: "Active theme and Pro previews",
                detail: "A visual theme selector summary showing the active AppTheme, catalog breadth, and timed Pro preview support.",
                family: .small,
                access: .pro,
                configurationName: "Theme Orbit",
                tags: ["Themes", "Pro preview"]
            ) {
                DemoThemeOrbitSmall(theme: theme)
            },
            WidgetShowcaseItem(
                id: "backup-health-small",
                title: "Backup Health",
                subtitle: "Recovery readiness at a glance",
                detail: "A compact backup status surface for BackupKit archives, validation, and restore confidence.",
                family: .small,
                configurationName: "Backup Health",
                tags: ["BackupKit", "Restore"]
            ) {
                DemoBackupHealthSmall(theme: theme)
            },
            WidgetShowcaseItem(
                id: "screenshot-studio-medium",
                title: "Screenshot Studio",
                subtitle: "Registered scenes and export coverage",
                detail: "A medium widget showing Screenshot Studio scene registration, responsive layouts, and App Store export readiness.",
                family: .medium,
                configurationName: "Screenshot Studio",
                tags: ["Scenes", "Export"]
            ) {
                DemoScreenshotStudioMedium(theme: theme)
            },
            WidgetShowcaseItem(
                id: "promo-studio-medium",
                title: "Promo Studio",
                subtitle: "Story beats across every format",
                detail: "A responsive promo-video status widget representing scene composition, aspect-ratio layouts, and native animations.",
                family: .medium,
                access: .pro,
                configurationName: "Promo Studio",
                tags: ["Video", "Responsive"]
            ) {
                DemoPromoStudioMedium(theme: theme)
            },
            WidgetShowcaseItem(
                id: "notification-center-medium",
                title: "Notification Center",
                subtitle: "Scheduled requests and permissions",
                detail: "A concise notification dashboard for authorization, scheduled reminders, and reusable request helpers.",
                family: .medium,
                configurationName: "Notification Center",
                tags: ["Alerts", "Scheduling"]
            ) {
                DemoNotificationCenterMedium(theme: theme)
            },
            WidgetShowcaseItem(
                id: "foundation-dashboard-large",
                title: "Foundation Dashboard",
                subtitle: "One view across shared infrastructure",
                detail: "A large operational dashboard combining purchases, themes, backup, notifications, exports, and widget snapshots.",
                family: .large,
                configurationName: "Foundation Dashboard",
                tags: ["Overview", "Health"]
            ) {
                DemoFoundationDashboardLarge(theme: theme)
            },
            WidgetShowcaseItem(
                id: "content-pipeline-large",
                title: "Content Pipeline",
                subtitle: "Screenshot and promo production flow",
                detail: "A large creative pipeline widget showing registered content moving through Screenshot Studio, Promo Studio, and export.",
                family: .large,
                access: .pro,
                configurationName: "Content Pipeline",
                tags: ["Studios", "Delivery"]
            ) {
                DemoContentPipelineLarge(theme: theme)
            },
            WidgetShowcaseItem(
                id: "release-readiness-large",
                title: "Release Readiness",
                subtitle: "Shared snapshots, tests, and recovery",
                detail: "A release-focused widget combining snapshot freshness, package tests, backup status, and production safeguards.",
                family: .large,
                configurationName: "Release Readiness",
                tags: ["Tests", "Snapshots"]
            ) {
                DemoReleaseReadinessLarge(theme: theme)
            },
        ])
    }
}
