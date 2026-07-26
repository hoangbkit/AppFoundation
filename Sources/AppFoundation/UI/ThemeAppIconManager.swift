#if canImport(UIKit)
import UIKit

public enum AppIconError: LocalizedError, Sendable {
    case unsupported
    case applicationRejectedChange

    public var errorDescription: String? {
        switch self {
        case .unsupported:
            "Alternate app icons are not supported on this device."
        case .applicationRejectedChange:
            "The app icon could not be changed."
        }
    }
}

@MainActor
public enum AppIconManager {
    public static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    public static var currentIconName: String? {
        UIApplication.shared.alternateIconName
    }

    public static func apply(iconName: String?) async throws {
        guard supportsAlternateIcons else {
            throw AppIconError.unsupported
        }

        guard currentIconName != iconName else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if error == nil {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AppIconError.applicationRejectedChange)
                }
            }
        }
    }
}

public typealias ThemeAppIconError = AppIconError

@MainActor
public enum ThemeAppIconManager {
    public static var currentIconName: String? {
        AppIconManager.currentIconName
    }

    public static func apply(_ theme: AppTheme) async throws {
        try await AppIconManager.apply(iconName: theme.alternateIconName)
    }
}
#endif
