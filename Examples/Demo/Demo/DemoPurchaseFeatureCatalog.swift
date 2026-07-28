import AppFoundation

enum DemoPurchaseFeatureCatalog {
    static let features: [PurchaseFeature] = [
        PurchaseFeature(
            id: "components",
            systemImage: "square.stack.3d.up.fill",
            title: "Reusable components",
            message: "Unlock the complete component library.",
            freeValue: "3 samples",
            proValue: "Full library"
        ),
        PurchaseFeature(
            id: "screenshot-exports",
            systemImage: "photo.stack.fill",
            title: "Screenshot exports",
            message: "Export unlimited App Store screenshots.",
            freeValue: "3 / week",
            proValue: "Unlimited"
        ),
        PurchaseFeature(
            id: "promo-video-exports",
            systemImage: "film.stack.fill",
            title: "Promo video exports",
            message: "Render clean, unbranded promo videos.",
            freeValue: "Watermarked",
            proValue: "Clean exports"
        ),
        PurchaseFeature(
            id: "themes",
            systemImage: "paintpalette.fill",
            title: "App themes",
            message: "Use every theme and Pro preview.",
            freeValue: "Default only",
            proValue: "All themes"
        ),
        PurchaseFeature(
            id: "widgets",
            systemImage: "square.grid.2x2.fill",
            title: "Widget catalog",
            message: "Access the full widget catalog.",
            freeValue: "2 widgets",
            proValue: "Full catalog"
        ),
        PurchaseFeature(
            id: "backup-history",
            systemImage: "archivebox.fill",
            title: "Backup history",
            message: "Keep your complete backup history.",
            freeValue: "Latest only",
            proValue: "Complete"
        ),
    ]
}
