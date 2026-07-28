import AppFoundation

enum DemoPurchaseFeatureCatalog {
    static let features: [PurchaseFeature] = [
        PurchaseFeature(
            id: "components",
            systemImage: "square.stack.3d.up.fill",
            title: "Reusable components",
            message: "Explore the complete collection of production-ready AppFoundation components.",
            freeValue: "3 samples",
            proValue: "Full library"
        ),
        PurchaseFeature(
            id: "screenshot-exports",
            systemImage: "photo.stack.fill",
            title: "Screenshot exports",
            message: "Export polished App Store screenshots without weekly limits.",
            freeValue: "3 / week",
            proValue: "Unlimited"
        ),
        PurchaseFeature(
            id: "promo-video-exports",
            systemImage: "film.stack.fill",
            title: "Promo video exports",
            message: "Render every promo-video preset without Demo branding.",
            freeValue: "Watermarked",
            proValue: "Clean exports"
        ),
        PurchaseFeature(
            id: "themes",
            systemImage: "paintpalette.fill",
            title: "App themes",
            message: "Use every theme and entitlement-aware theme preview.",
            freeValue: "Default only",
            proValue: "All themes"
        ),
        PurchaseFeature(
            id: "widgets",
            systemImage: "square.grid.2x2.fill",
            title: "Widget catalog",
            message: "Browse and reuse the complete AppFoundation widget collection.",
            freeValue: "2 widgets",
            proValue: "Full catalog"
        ),
        PurchaseFeature(
            id: "backup-history",
            systemImage: "archivebox.fill",
            title: "Backup history",
            message: "Keep complete validated backup history instead of only the latest package.",
            freeValue: "Latest only",
            proValue: "Complete"
        ),
    ]
}
