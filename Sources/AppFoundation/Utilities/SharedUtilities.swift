import Foundation

public struct UserFacingError: Error, Sendable, Equatable {
    public let title: String
    public let message: String
    public let recoverySuggestion: String?

    public init(title: String, message: String, recoverySuggestion: String? = nil) {
        self.title = title
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }
}

public struct AppInfo: Sendable, Equatable {
    public let displayName: String
    public let bundleIdentifier: String
    public let version: String
    public let build: String
    public let appStoreID: String?

    public init(
        displayName: String,
        bundleIdentifier: String,
        version: String,
        build: String,
        appStoreID: String? = nil
    ) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.build = build
        self.appStoreID = appStoreID
    }

    public static func current(bundle: Bundle = .main, appStoreID: String? = nil) -> AppInfo {
        AppInfo(
            displayName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? "App",
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown.bundle",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            appStoreID: appStoreID
        )
    }

    public var versionAndBuild: String { "\(version) (\(build))" }
}

public actor SafeFileWriter {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func replace(data: Data, at destination: URL) throws {
        let directory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporary, options: .atomic)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try fileManager.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }
}

public actor AsyncDebouncer {
    private var task: Task<Void, Never>?

    public init() {}

    public func schedule(after delay: Duration, operation: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}

public struct ReviewRequestPolicy: Sendable, Equatable {
    public var minimumMeaningfulActions: Int
    public var minimumDaysBetweenRequests: Int

    public init(minimumMeaningfulActions: Int = 3, minimumDaysBetweenRequests: Int = 120) {
        self.minimumMeaningfulActions = max(1, minimumMeaningfulActions)
        self.minimumDaysBetweenRequests = max(1, minimumDaysBetweenRequests)
    }

    public func shouldRequest(
        meaningfulActionCount: Int,
        lastRequestDate: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard meaningfulActionCount >= minimumMeaningfulActions else { return false }
        guard let lastRequestDate else { return true }
        let days = calendar.dateComponents([.day], from: lastRequestDate, to: now).day ?? 0
        return days >= minimumDaysBetweenRequests
    }
}

#if canImport(os)
import os

public enum AppLogger {
    public static func logger(category: String, bundle: Bundle = .main) -> Logger {
        Logger(subsystem: bundle.bundleIdentifier ?? "AppFoundation.Consumer", category: category)
    }
}
#endif

#if canImport(UIKit)
import UIKit

@MainActor
public enum HapticService {
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    public static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
#endif

#if canImport(SwiftUI)
import SwiftUI

public struct AsyncButton<Label: View>: View {
    private let action: @Sendable () async throws -> Void
    private let label: Label
    @State private var isRunning = false
    @State private var error: UserFacingError?

    public init(
        action: @escaping @Sendable () async throws -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Button {
            guard !isRunning else { return }
            isRunning = true
            Task {
                defer { isRunning = false }
                do {
                    try await action()
                } catch let userError as UserFacingError {
                    error = userError
                } catch let caughtError {
                    self.error = UserFacingError(
                        title: "Something went wrong",
                        message: caughtError.localizedDescription
                    )
                }
            }
        } label: {
            HStack {
                if isRunning { ProgressView() }
                label
            }
        }
        .disabled(isRunning)
        .alert(error?.title ?? "Error", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) { error = nil }
        } message: {
            if let error {
                Text(
                    [error.message, error.recoverySuggestion]
                        .compactMap { $0 }
                        .joined(separator: "\n\n")
                )
            }
        }
    }
}
#endif
