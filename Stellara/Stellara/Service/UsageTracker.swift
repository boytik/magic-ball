import Foundation
import Combine

/// Локальный счётчик предсказаний на сегодня.
/// Бэкенд — authoritative source (он тоже считает по KV), а этот трекер
/// — клиентский кэш + UX, чтобы не отправлять запрос, если лимит уже исчерпан.
///
/// Сбрасывается автоматически по локальной полуночи (через смену "year-month-day"-ключа).
@MainActor
final class UsageTracker: ObservableObject {

    /// Сколько раз в день можно спросить. Должно совпадать с `DAILY_LIMIT`
    /// в `backend/worker.ts`.
    static let dailyLimit: Int = 3

    @Published private(set) var usedToday: Int = 0

    private let countKey = "stellara.usage.count.v1"
    private let dateKey  = "stellara.usage.date.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rolloverIfNeeded()
        self.usedToday = defaults.integer(forKey: countKey)
    }

    // MARK: - Public API

    var remainingToday: Int {
        max(0, Self.dailyLimit - usedToday)
    }

    var canAsk: Bool { remainingToday > 0 }

    /// Optimistic increment — вызвать ПЕРЕД сетевым запросом.
    func registerAttempt() {
        rolloverIfNeeded()
        let next = defaults.integer(forKey: countKey) + 1
        defaults.set(next, forKey: countKey)
        defaults.set(currentDayKey(), forKey: dateKey)
        usedToday = next
    }

    /// Откат, если запрос упал и ничего на бэке не потратилось
    /// (сетевые ошибки, 5xx и т.д.).
    func rollback() {
        let prev = defaults.integer(forKey: countKey)
        let next = max(0, prev - 1)
        defaults.set(next, forKey: countKey)
        usedToday = next
    }

    /// Точная синхронизация с сервером (если бэк вернул свои числа).
    func syncFromServer(used: Int) {
        let clamped = max(0, min(used, Self.dailyLimit))
        defaults.set(clamped, forKey: countKey)
        defaults.set(currentDayKey(), forKey: dateKey)
        usedToday = clamped
    }

    /// Сервер вернул 429 — на бэке уже лимит, фиксируем это локально.
    func markLimitReached() {
        defaults.set(Self.dailyLimit, forKey: countKey)
        defaults.set(currentDayKey(), forKey: dateKey)
        usedToday = Self.dailyLimit
    }

    /// Время до сброса лимита (для UI-подсказок).
    var nextResetDate: Date {
        let cal = Calendar.current
        let startOfTomorrow = cal.date(byAdding: .day, value: 1,
                                       to: cal.startOfDay(for: Date()))
        return startOfTomorrow ?? Date()
    }

    // MARK: - Private

    private func rolloverIfNeeded() {
        let stored = defaults.string(forKey: dateKey)
        let today = currentDayKey()
        if stored != today {
            defaults.set(0, forKey: countKey)
            defaults.set(today, forKey: dateKey)
            usedToday = 0
        }
    }

    private func currentDayKey() -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }
}
