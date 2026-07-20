#if canImport(UIKit)
import UIKit

public enum ThemeAppIconError: LocalizedError, Sendable {
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
public enum ThemeAppIconManager {
    public static var currentIconName: String? {
        UIApplication.shared.alternateIconName
    }

    public static func apply(_ theme: AppTheme) async throws {
        guard UIApplication.shared.supportsAlternateIcons else {
            throw ThemeAppIconError.unsupported
        }

        let desiredName = theme.alternateIconName
        guard UIApplication.shared.alternateIconName != desiredName else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(desiredName) { error in
                if error == nil {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ThemeAppIconError.applicationRejectedChange)
                }
            }
        }
    }
}
#endif
