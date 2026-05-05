import Foundation
import UserNotifications
import Combine
import SwiftUI

/// Локальные уведомления по категориям. Без серверного APNs — все пуши
/// планируются на устройстве через `UNCalendarNotificationTrigger`.
///
/// Категории:
/// - `.dailyReset`     — «3 предсказания снова доступны» (ставится при достижении лимита).
/// - `.cosmicEvents`   — мистические даты (полнолуния — рассчитываются от опорной даты,
///   на год вперёд). Каждая — отдельный pending-request.
/// - `.weeklyForecast` — еженедельный «голос оракула», понедельник 10:00, repeats: true.
///
/// Каждая категория независимо хранит свой `enabled`-флаг в UserDefaults.
@MainActor
final class NotificationManager: ObservableObject {

    // MARK: - Category

    enum Category: String, CaseIterable, Identifiable {
        case dailyReset      = "daily_reset"
        case cosmicEvents    = "cosmic_events"
        case weeklyForecast  = "weekly_forecast"

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            LocalizedStringKey("push.category.\(rawValue).title")
        }

        var subtitleKey: LocalizedStringKey {
            LocalizedStringKey("push.category.\(rawValue).subtitle")
        }

        var icon: String {
            switch self {
            case .dailyReset:     return "bell.fill"
            case .cosmicEvents:   return "moon.stars.fill"
            case .weeklyForecast: return "calendar.badge.clock"
            }
        }

        var tintColors: [Color] {
            switch self {
            case .dailyReset:
                return [Color(red: 0.40, green: 0.78, blue: 0.95),
                        Color(red: 0.30, green: 0.50, blue: 0.95)]
            case .cosmicEvents:
                return [Color(red: 0.55, green: 0.42, blue: 0.95),
                        Color(red: 0.85, green: 0.45, blue: 0.95)]
            case .weeklyForecast:
                return [Color(red: 0.95, green: 0.55, blue: 0.30),
                        Color(red: 0.95, green: 0.35, blue: 0.55)]
            }
        }
    }

    // MARK: - State

    @Published private(set) var authStatus: UNAuthorizationStatus = .notDetermined

    /// `[категория: вкл]`. Пишется только через `setEnabled(...)`,
    /// чтобы попутно (пере)планировать уведомления.
    @Published private(set) var enabled: [Category: Bool] = [:]

    // MARK: - Internals

    private let defaults: UserDefaults
    private func enabledKey(_ c: Category) -> String { "stellara.notif.\(c.rawValue).enabled.v1" }
    private func identifierPrefix(_ c: Category) -> String { "stellara.notif.\(c.rawValue)" }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for c in Category.allCases {
            let key = enabledKey(c)
            if defaults.object(forKey: key) == nil {
                defaults.set(true, forKey: key) // по умолчанию все вкл
            }
            enabled[c] = defaults.bool(forKey: key)
        }
        Task { await refreshStatus() }
    }

    // MARK: - Public API

    func isEnabled(_ c: Category) -> Bool { enabled[c] ?? true }

    func setEnabled(_ value: Bool, for c: Category) {
        enabled[c] = value
        defaults.set(value, forKey: enabledKey(c))
        if value {
            scheduleIfPossible(c)
        } else {
            cancel(c)
        }
    }

    /// Подсмотреть актуальный статус — система могла измениться вне приложения.
    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.authStatus = settings.authorizationStatus
            // Если разрешение появилось — переобновим расписание включённых категорий.
            if settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional {
                self.rescheduleAllEnabled()
            }
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            #if DEBUG
            print("requestAuthorization error:", error)
            #endif
            return false
        }
    }

    /// (Пере)планировать всё, что включено — вызвать при старте, после авторизации
    /// и после смены даты.
    func rescheduleAllEnabled() {
        for c in Category.allCases where isEnabled(c) {
            scheduleIfPossible(c)
        }
    }

    // MARK: - Scheduling per category

    private func scheduleIfPossible(_ c: Category) {
        guard authStatus == .authorized || authStatus == .provisional else { return }
        switch c {
        case .dailyReset:     scheduleDailyReset()
        case .cosmicEvents:   scheduleCosmicEvents()
        case .weeklyForecast: scheduleWeeklyForecast()
        }
    }

    private func cancel(_ c: Category) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let prefix = self.identifierPrefix(c)
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Daily reset

    /// Триггерится из OracleView, когда пользователь использовал 3-е предсказание.
    /// Идемпотентен — старый pending снимается.
    func scheduleLimitResetNotification() {
        guard isEnabled(.dailyReset) else { return }
        guard authStatus == .authorized || authStatus == .provisional else { return }
        scheduleDailyReset()
    }

    private func scheduleDailyReset() {
        let id = "\(identifierPrefix(.dailyReset)).next"

        let cal = Calendar.current
        guard
            let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())),
            let fireDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
        else { return }

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("push.daily_reset.title", comment: "")
        content.body  = NSLocalizedString("push.daily_reset.body",  comment: "")
        content.sound = .default

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: - Cosmic events (full moons)

    /// Опорная дата полнолуния и синодический период. Считаем 12 ближайших.
    private static let referenceFullMoon = DateComponents(
        timeZone: TimeZone(identifier: "UTC"),
        year: 2026, month: 5, day: 31, hour: 17, minute: 45
    )
    private static let synodicMonth: TimeInterval = 29.530589 * 86400

    private func scheduleCosmicEvents() {
        let cal = Calendar(identifier: .gregorian)
        guard let reference = cal.date(from: Self.referenceFullMoon) else { return }

        // Берём ближайшие 12 будущих полнолуний от сегодня.
        let now = Date()
        var dates: [Date] = []
        var idx: Int = 0
        // Найдём ближайшее будущее полнолуние, стартуя с reference и шагая на synodicMonth.
        // Если reference уже в прошлом — догоняем вперёд.
        var candidate = reference
        while candidate < now {
            candidate.addTimeInterval(Self.synodicMonth)
        }
        while dates.count < 12 {
            dates.append(candidate)
            candidate.addTimeInterval(Self.synodicMonth)
            idx += 1
        }

        // Постим уведомление в 21:00 локального в день полнолуния.
        let center = UNUserNotificationCenter.current()
        var added = 0
        for date in dates {
            let local = cal.date(bySettingHour: 21, minute: 0, second: 0, of: date) ?? date
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: local)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("push.cosmic.full_moon.title", comment: "")
            content.body  = NSLocalizedString("push.cosmic.full_moon.body",  comment: "")
            content.sound = .default

            let id = "\(identifierPrefix(.cosmicEvents)).fullmoon.\(Int(date.timeIntervalSince1970))"
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            added += 1
        }

        #if DEBUG
        print("Scheduled \(added) cosmic events.")
        #endif
    }

    // MARK: - Weekly forecast

    private func scheduleWeeklyForecast() {
        let id = "\(identifierPrefix(.weeklyForecast)).recurring"

        // Понедельник 10:00 локального, каждую неделю.
        var comps = DateComponents()
        comps.weekday = 2 // Monday (Gregorian: 1=Sun..7=Sat)
        comps.hour = 10
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("push.weekly.title", comment: "")
        content.body  = NSLocalizedString("push.weekly.body",  comment: "")
        content.sound = .default

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: - Backwards-compat shim

    /// Для существующих вызовов из OracleView/AboutView, которые знают только
    /// про «daily reminder». Со временем перепишем на API категорий.
    var dailyReminderEnabled: Bool {
        get { isEnabled(.dailyReset) }
        set { setEnabled(newValue, for: .dailyReset) }
    }

    func cancelLimitResetNotification() {
        cancel(.dailyReset)
    }
}
