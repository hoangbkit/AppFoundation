import Foundation
#if canImport(UIKit)
import UIKit
#endif

public enum AppAnalyticsPlatform: String, Codable, Sendable {
    case iOS = "ios"
    case macOS = "macos"
}

public struct AppAnalyticsEventCounter: Codable, Sendable, Equatable {
    public let name: String
    public let count: Int
    public let dimension: String?

    public init(name: String, count: Int, dimension: String? = nil) {
        self.name = name
        self.count = count
        self.dimension = dimension
    }
}

public struct AppAnalyticsDaySnapshot: Codable, Sendable, Equatable {
    public let day: String
    public let platform: AppAnalyticsPlatform
    public let appVersion: String?
    public let sessions: Int
    public let sessionSeconds: Int
    public let events: [AppAnalyticsEventCounter]
}

public struct AppAnalyticsBatch: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let requestId: String
    public let days: [AppAnalyticsDaySnapshot]

    public init(requestId: String, days: [AppAnalyticsDaySnapshot]) {
        self.schemaVersion = 1
        self.requestId = requestId
        self.days = days
    }
}

public struct AppAnalyticsSubmissionResponse: Codable, Sendable, Equatable {
    public let ok: Bool
    public let requestId: String
    public let acceptedDays: [String]
}

public protocol AppAnalyticsStorage: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
}

public struct AppAnalyticsUserDefaultsStorage: AppAnalyticsStorage, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func set(_ data: Data, forKey key: String) {
        defaults.set(data, forKey: key)
    }
}

public actor AppAnalytics {
    private struct DayState: Codable, Sendable {
        var sessions: Int = 0
        var sessionSeconds: Double = 0
        var events: [String: Int] = [:]
    }

    private struct SessionState: Codable, Sendable {
        var lastActivityAt: Date
        var activeSince: Date?
    }

    private struct State: Codable, Sendable {
        var days: [String: DayState] = [:]
        var session: SessionState?
        var lastAttemptAt: Date = .distantPast
        var lastSuccessfulFlushAt: Date = .distantPast
    }

    private enum Limits {
        static let sessionTimeout: TimeInterval = 30 * 60
        static let flushInterval: TimeInterval = 60
        static let retryInterval: TimeInterval = 60
        static let maxDays = 7
        static let maxEventsPerDay = 50
        static let maxEventCountersPerBatch = 100
        static let maxEventCount = 100_000
        static let maxSessions = 1_000
        static let maxSessionSeconds: Double = 86_400
    }

    private let client: AppAIClient
    private let platform: AppAnalyticsPlatform
    private let configuredAppVersion: String?
    private let storage: any AppAnalyticsStorage
    private let storageKey: String
    private var state: State
    private var revision = 0
    private var flushedRevision = 0
    private var started = false
    private var observerTokens: [NSObjectProtocol] = []
    private var flushTask: Task<Void, Never>?

    public init(
        configuration: AppAIClientConfiguration,
        platform: AppAnalyticsPlatform = .iOS,
        appVersion: String? = nil,
        storage: any AppAnalyticsStorage = AppAnalyticsUserDefaultsStorage(),
        storageKey: String? = nil,
        transport: any AppAITransport = URLSessionAppAITransport(),
        attestationProvider: (any AppAIAttestationProviding)? = nil
    ) {
        self.client = AppAIClient(
            configuration: configuration,
            transport: transport,
            attestationProvider: attestationProvider
        )
        self.platform = platform
        self.configuredAppVersion = Self.normalizedAppVersion(appVersion)
        self.storage = storage
        self.storageKey = storageKey ?? "app-foundation.analytics.\(configuration.appID).v1"
        self.state = Self.loadState(storage: storage, key: self.storageKey)
        Self.pruneDays(&self.state, now: Date())
        if !self.state.days.isEmpty {
            self.revision = 1
        }
    }

    public func start() {
        guard !started else { return }
        started = true
        markActivity(at: Date(), active: true)
        markDirty()
        persist()

        #if canImport(UIKit)
        let center = NotificationCenter.default
        observerTokens.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.becameActive() }
        })
        observerTokens.append(center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.becameInactive() }
        })
        observerTokens.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.becameInactive() }
        })
        #endif

        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await self?.flush()
            }
        }
    }

    public func stop() async {
        guard started else { return }
        started = false
        flushTask?.cancel()
        flushTask = nil
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        observerTokens.removeAll()
        settleActiveSegment(at: Date())
        if state.session != nil {
            state.session?.activeSince = nil
        }
        markDirty()
        persist()
        await flush(force: true)
    }

    public func track(_ name: String, dimension: String? = nil) {
        track(name, dimension: dimension, at: Date())
    }

    public func flush(force: Bool = false) async {
        guard revision > flushedRevision else { return }
        let now = Date()
        guard now.timeIntervalSince(state.lastAttemptAt) >= Limits.retryInterval else { return }
        if !force && now.timeIntervalSince(state.lastSuccessfulFlushAt) < Limits.flushInterval {
            return
        }
        guard let batch = buildBatch(now: now) else { return }
        let sentRevision = revision
        state.lastAttemptAt = now
        persist()
        do {
            _ = try await client.submitAnalyticsBatch(batch)
            state.lastSuccessfulFlushAt = now
            flushedRevision = max(flushedRevision, sentRevision)
            persist()
        } catch {
            // Analytics is best effort. Cumulative snapshots remain local for retry.
        }
    }

    public func buildBatch(now: Date = Date()) -> AppAnalyticsBatch? {
        settleActiveSegment(at: now)
        Self.pruneDays(&state, now: now)
        let version = Self.normalizedAppVersion(configuredAppVersion ?? Self.bundleVersion())
        let snapshots = state.days.keys.sorted().compactMap { day -> AppAnalyticsDaySnapshot? in
            guard let bucket = state.days[day] else { return nil }
            let events = bucket.events.keys.sorted().compactMap { key -> AppAnalyticsEventCounter? in
                let event = Self.parseEventKey(key)
                guard Self.validEventName(event.name) else { return nil }
                return AppAnalyticsEventCounter(
                    name: event.name,
                    count: min(Limits.maxEventCount, max(0, bucket.events[key] ?? 0)),
                    dimension: event.dimension
                )
            }
            return AppAnalyticsDaySnapshot(
                day: day,
                platform: platform,
                appVersion: version,
                sessions: min(Limits.maxSessions, max(0, bucket.sessions)),
                sessionSeconds: min(
                    Int(Limits.maxSessionSeconds),
                    max(0, Int(bucket.sessionSeconds.rounded(.down)))
                ),
                events: events
            )
        }
        guard !snapshots.isEmpty else { return nil }
        return AppAnalyticsBatch(
            requestId: "native-\(UUID().uuidString.lowercased())",
            days: snapshots
        )
    }

    func track(_ name: String, dimension: String?, at now: Date) {
        guard Self.validEventName(name) else { return }
        Self.pruneDays(&state, now: now)
        markActivity(at: now, active: true)
        let day = Self.utcDay(now)
        var bucket = state.days[day] ?? DayState()
        let normalizedDimension = Self.normalizedDimension(dimension)
        let key = Self.eventKey(name: name, dimension: normalizedDimension)
        let isNew = bucket.events[key] == nil
        if isNew && bucket.events.count >= Limits.maxEventsPerDay { return }
        if isNew && totalEventCounters() >= Limits.maxEventCountersPerBatch { return }
        bucket.events[key] = min(Limits.maxEventCount, (bucket.events[key] ?? 0) + 1)
        state.days[day] = bucket
        markDirty()
        persist()
    }

    func becameActive(at now: Date = Date()) {
        markActivity(at: now, active: true)
        markDirty()
        persist()
    }

    func becameInactive(at now: Date = Date()) async {
        settleActiveSegment(at: now)
        state.session?.activeSince = nil
        markDirty()
        persist()
        await flush(force: true)
    }

    private func markActivity(at now: Date, active: Bool) {
        if state.session == nil || now.timeIntervalSince(state.session!.lastActivityAt) >= Limits.sessionTimeout {
            settleActiveSegment(at: now)
            let day = Self.utcDay(now)
            var bucket = state.days[day] ?? DayState()
            bucket.sessions = min(Limits.maxSessions, bucket.sessions + 1)
            state.days[day] = bucket
            state.session = SessionState(lastActivityAt: now, activeSince: active ? now : nil)
            return
        }

        settleActiveSegment(at: now)
        state.session?.lastActivityAt = now
        if active {
            state.session?.activeSince = now
        }
    }

    private func settleActiveSegment(at now: Date) {
        guard let session = state.session, let activeSince = session.activeSince else { return }
        let timeoutEnd = session.lastActivityAt.addingTimeInterval(Limits.sessionTimeout)
        let end = min(now, timeoutEnd)
        if end > activeSince {
            addActiveDuration(from: activeSince, to: end)
        }
        state.session?.activeSince = end >= now ? now : nil
    }

    private func addActiveDuration(from start: Date, to end: Date) {
        var cursor = start
        let calendar = Self.utcCalendar
        while cursor < end {
            let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: cursor)
            ) ?? end
            let segmentEnd = min(end, nextDay)
            let day = Self.utcDay(cursor)
            var bucket = state.days[day] ?? DayState()
            bucket.sessionSeconds = min(
                Limits.maxSessionSeconds,
                bucket.sessionSeconds + max(0, segmentEnd.timeIntervalSince(cursor))
            )
            state.days[day] = bucket
            cursor = segmentEnd
        }
    }

    private func totalEventCounters() -> Int {
        state.days.values.reduce(0) { $0 + $1.events.count }
    }

    private func markDirty() {
        revision += 1
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        storage.set(data, forKey: storageKey)
    }

    private static func loadState(storage: any AppAnalyticsStorage, key: String) -> State {
        guard let data = storage.data(forKey: key),
              var decoded = try? JSONDecoder().decode(State.self, from: data) else {
            return State()
        }

        var totalCounters = 0
        for day in decoded.days.keys.sorted() {
            guard validDayKey(day), var bucket = decoded.days[day] else {
                decoded.days.removeValue(forKey: day)
                continue
            }
            bucket.sessions = min(Limits.maxSessions, max(0, bucket.sessions))
            bucket.sessionSeconds = min(Limits.maxSessionSeconds, max(0, bucket.sessionSeconds))

            var events: [String: Int] = [:]
            for key in bucket.events.keys.sorted() {
                guard events.count < Limits.maxEventsPerDay,
                      totalCounters < Limits.maxEventCountersPerBatch,
                      let count = bucket.events[key],
                      count >= 0 else { continue }
                let event = parseEventKey(key)
                guard validEventName(event.name) else { continue }
                if let dimension = event.dimension, normalizedDimension(dimension) != dimension {
                    continue
                }
                events[key] = min(Limits.maxEventCount, count)
                totalCounters += 1
            }
            bucket.events = events
            decoded.days[day] = bucket
        }
        return decoded
    }

    private static func validDayKey(_ day: String) -> Bool {
        let parts = day.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let dayValue = Int(parts[2]) else {
            return false
        }
        var components = DateComponents()
        components.calendar = utcCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = dayValue
        guard let date = utcCalendar.date(from: components) else { return false }
        return utcDay(date) == day
    }

    private static func pruneDays(_ state: inout State, now: Date) {
        let calendar = utcCalendar
        let start = calendar.startOfDay(for: now)
        let minimumDate = calendar.date(byAdding: .day, value: -(Limits.maxDays - 1), to: start) ?? start
        let minimum = utcDay(minimumDate)
        let today = utcDay(now)
        state.days = state.days.filter { day, _ in day >= minimum && day <= today }
    }

    private static func utcDay(_ date: Date) -> String {
        let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func eventKey(name: String, dimension: String?) -> String {
        "\(name)\u{0}\(dimension ?? "")"
    }

    private static func parseEventKey(_ key: String) -> (name: String, dimension: String?) {
        guard let separator = key.firstIndex(of: "\u{0}") else { return (key, nil) }
        let name = String(key[..<separator])
        let next = key.index(after: separator)
        let dimension = String(key[next...])
        return (name, dimension.isEmpty ? nil : dimension)
    }

    private static func validEventName(_ value: String) -> Bool {
        let scalars = Array(value.unicodeScalars)
        guard !scalars.isEmpty, scalars.count <= 48, isLowercaseASCII(scalars[0]) else { return false }
        return scalars.dropFirst().allSatisfy { scalar in
            isLowercaseASCII(scalar) || isDigitASCII(scalar) || scalar == "_"
        }
    }

    private static func normalizedDimension(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        let scalars = Array(trimmed.unicodeScalars.prefix(64))
        guard let first = scalars.first, isAlphanumericASCII(first) else { return nil }
        let allowed = scalars.allSatisfy { scalar in
            isAlphanumericASCII(scalar) || "._:/+-".unicodeScalars.contains(scalar)
        }
        return allowed ? String(String.UnicodeScalarView(scalars)) : nil
    }

    private static func normalizedAppVersion(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let scalars = Array(value.unicodeScalars)
        guard scalars.count <= 64, let first = scalars.first, isAlphanumericASCII(first) else { return nil }
        let allowed = scalars.allSatisfy { scalar in
            isAlphanumericASCII(scalar) || "._+()-".unicodeScalars.contains(scalar)
        }
        return allowed ? value : nil
    }

    private static func bundleVersion() -> String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private static func isLowercaseASCII(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 97 && scalar.value <= 122
    }

    private static func isDigitASCII(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 48 && scalar.value <= 57
    }

    private static func isAlphanumericASCII(_ scalar: Unicode.Scalar) -> Bool {
        isLowercaseASCII(scalar)
            || (scalar.value >= 65 && scalar.value <= 90)
            || isDigitASCII(scalar)
    }
}
