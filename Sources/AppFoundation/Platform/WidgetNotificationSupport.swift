import Foundation

public struct SharedSnapshot<Value: Codable & Sendable>: Codable, Sendable {
    public let value: Value
    public let updatedAt: Date
    public let schemaVersion: Int

    public init(value: Value, updatedAt: Date = .now, schemaVersion: Int = 1) {
        self.value = value
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }
}

public enum SharedStoreError: Error, Sendable, Equatable {
    case suiteUnavailable(String)
    case encodingFailed
    case decodingFailed
}

public actor AppGroupStore<Value: Codable & Sendable> {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(suiteName: String, key: String) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedStoreError.suiteUnavailable(suiteName)
        }
        self.defaults = defaults
        self.key = key
    }

    public func save(_ value: Value, schemaVersion: Int = 1) throws {
        do {
            defaults.set(try encoder.encode(SharedSnapshot(value: value, schemaVersion: schemaVersion)), forKey: key)
        } catch {
            throw SharedStoreError.encodingFailed
        }
    }

    public func load() throws -> SharedSnapshot<Value>? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do { return try decoder.decode(SharedSnapshot<Value>.self, from: data) }
        catch { throw SharedStoreError.decodingFailed }
    }

    public func remove() { defaults.removeObject(forKey: key) }
}

public struct SharedDeepLink: Sendable, Equatable {
    public let scheme: String
    public let host: String
    public let pathComponents: [String]
    public let queryItems: [URLQueryItem]

    public init(
        scheme: String,
        host: String,
        pathComponents: [String] = [],
        queryItems: [URLQueryItem] = []
    ) {
        self.scheme = scheme
        self.host = host
        self.pathComponents = pathComponents
        self.queryItems = queryItems
    }

    public var url: URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = pathComponents.map {
            "/" + ($0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0)
        }.joined()
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }
}

#if canImport(WidgetKit)
import WidgetKit

@MainActor
public final class WidgetReloadCoordinator {
    private var lastReload: [String: Date] = [:]
    private let minimumInterval: TimeInterval

    public init(minimumInterval: TimeInterval = 15) {
        self.minimumInterval = max(0, minimumInterval)
    }

    @discardableResult
    public func reload(kind: String, now: Date = .now) -> Bool {
        if let last = lastReload[kind], now.timeIntervalSince(last) < minimumInterval { return false }
        lastReload[kind] = now
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        return true
    }

    public func reloadAll() { WidgetCenter.shared.reloadAllTimelines() }
}
#endif

#if canImport(UserNotifications)
import UserNotifications

public struct LocalNotificationRequest: Sendable, Equatable {
    public let id: String
    public let title: String
    public let body: String
    public let date: Date
    public let userInfo: [String: String]
    public let soundEnabled: Bool

    public init(
        id: String,
        title: String,
        body: String,
        date: Date,
        userInfo: [String: String] = [:],
        soundEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.date = date
        self.userInfo = userInfo
        self.soundEnabled = soundEnabled
    }
}

public actor LocalNotificationManager {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    public init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    public func schedule(_ request: LocalNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.userInfo = request.userInfo
        if request.soundEnabled { content.sound = .default }
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: request.date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(
            UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)
        )
    }

    public func replace(_ request: LocalNotificationRequest) async throws {
        center.removePendingNotificationRequests(withIdentifiers: [request.id])
        try await schedule(request)
    }

    public func cancel(ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
#endif
