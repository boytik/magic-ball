import Foundation
import Combine

/// Стор для in-app браузера: финальная (приземляющая) ссылка и `pathid`.
///
/// Логика, которой пользуется `WebShellView` и `AdaptyOnboardingHost`:
///
///   • При первом успешном открытии страницы вызываем `captureFinal(_:)` —
///     сохраняем финальный URL после всех редиректов и подсматриваем `pathid`
///     в query (если он там есть).
///
///   • При следующем нажатии на «Privacy» в Adapty-онбординге берём
///     `bestURL(forBase: adaptyURL)` — он отдаст сохранённый финальный URL.
///     Если его нет — вернёт `adaptyURL` с приклеенным `pathid` (если был).
///
///   • Если по сохранённому URL страница не открылась, `WebShellView`
///     откатывается на `fallbackURL(forBase: adaptyURL)` — это
///     `adaptyURL?pathid=<saved>`.
///
/// Хранилище — обычный UserDefaults; синглтон, чтобы любой view мог его
/// дёрнуть без environmentObject.
@MainActor
final class WebRecoveryStore: ObservableObject {

    static let shared = WebRecoveryStore()

    private static let finalURLKey   = "stellara.web.finalURL"
    private static let pathIdKey     = "stellara.web.pathId"
    /// Имя query-параметра, в котором приходит/уходит pathId.
    /// Если у трекера/CRM другой ключ — поменять одной строкой.
    private static let pathIdQueryName = "pathid"

    @Published private(set) var finalURL: URL?
    @Published private(set) var pathId: String?

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.finalURLKey)
        self.finalURL = stored.flatMap(URL.init(string:))
        self.pathId   = UserDefaults.standard.string(forKey: Self.pathIdKey)
    }

    // MARK: - Reads

    /// Лучший URL для первичного открытия. Приоритет — сохранённая финальная
    /// ссылка; иначе база с приклеенным pathId; иначе сама база.
    func bestURL(forBase base: URL) -> URL {
        if let finalURL { return finalURL }
        return urlByAppendingPathId(to: base)
    }

    /// Резервный URL — база + pathId. Используется, если bestURL не открылся.
    func fallbackURL(forBase base: URL) -> URL {
        urlByAppendingPathId(to: base)
    }

    // MARK: - Writes

    /// Записать финальный URL после успешной загрузки. Заодно вытащим pathId
    /// из query, если он там есть.
    func captureFinal(_ url: URL) {
        if url.absoluteString != finalURL?.absoluteString {
            finalURL = url
            UserDefaults.standard.set(url.absoluteString, forKey: Self.finalURLKey)
        }
        if let extracted = extractPathId(from: url), extracted != pathId {
            pathId = extracted
            UserDefaults.standard.set(extracted, forKey: Self.pathIdKey)
        }
    }

    /// Сбросить сохранённую финальную ссылку, если по ней перестало открываться.
    /// pathId намеренно НЕ сбрасываем — он переживает смену финального URL.
    func resetFinalURL() {
        finalURL = nil
        UserDefaults.standard.removeObject(forKey: Self.finalURLKey)
    }

    // MARK: - Private

    private func urlByAppendingPathId(to base: URL) -> URL {
        guard let pathId, !pathId.isEmpty,
              var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        var items = comps.queryItems ?? []
        items.removeAll { $0.name.caseInsensitiveCompare(Self.pathIdQueryName) == .orderedSame }
        items.append(URLQueryItem(name: Self.pathIdQueryName, value: pathId))
        comps.queryItems = items
        return comps.url ?? base
    }

    private func extractPathId(from url: URL) -> String? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else { return nil }
        for item in items where item.name.caseInsensitiveCompare(Self.pathIdQueryName) == .orderedSame {
            if let value = item.value?.trimmingCharacters(in: .whitespaces), !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
