import Foundation
import SwiftUI
import Combine
import ObjectiveC.runtime

/// Управление языком интерфейса.
///
/// Поведение:
///  • По умолчанию **английский** — даже если системный язык устройства русский
///    или итальянский. Это требование продукта: первый запуск всегда на en.
///  • Пользователь может в Settings выбрать любой из поддерживаемых языков.
///  • Смена языка применяется **на лету**, без перезапуска приложения, за счёт
///    подмены `Bundle.main` через `object_setClass(...)` (см. `LocalizedBundle`).
///  • Выбранный язык хранится в UserDefaults под ключом `stellara.language`.
///
/// Использование в SwiftUI:
///   ```
///   @ObservedObject private var localization = LocalizationManager.shared
///   ...
///   RootView()
///     .environmentObject(localization)
///     .environment(\.locale, localization.locale)
///     .id(localization.current) // полный пересбор дерева при смене
///   ```
@MainActor
final class LocalizationManager: ObservableObject {

    // MARK: - Supported languages

    enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
        case english  = "en"
        case french   = "fr"
        case russian  = "ru"
        case italian  = "it"

        var id: String { rawValue }

        /// Локальное имя языка («English», «Français», «Русский», «Italiano»).
        var nativeName: String {
            switch self {
            case .english:  return "English"
            case .french:   return "Français"
            case .russian:  return "Русский"
            case .italian:  return "Italiano"
            }
        }

        /// Эмодзи-флажок для UI-пикера.
        var flag: String {
            switch self {
            case .english: return "🇬🇧"
            case .french:  return "🇫🇷"
            case .russian: return "🇷🇺"
            case .italian: return "🇮🇹"
            }
        }
    }

    // MARK: - Storage

    static let shared = LocalizationManager()

    private static let storageKey = "stellara.language"

    /// Текущий выбранный язык. По дефолту `.english`.
    @Published private(set) var current: AppLanguage

    /// `Locale`, который удобно прокинуть в `.environment(\.locale, ...)`.
    var locale: Locale { Locale(identifier: current.rawValue) }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        let initial = stored.flatMap(AppLanguage.init(rawValue:)) ?? .english
        self.current = initial
        // Сразу подменяем bundle, чтобы NSLocalizedString и Text("key")
        // отдавали выбранный язык.
        Bundle.setLanguage(initial.rawValue)
    }

    // MARK: - Public API

    func set(_ language: AppLanguage) {
        guard language != current else { return }
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        Bundle.setLanguage(language.rawValue)
        current = language
    }
}

// MARK: - Bundle swizzle: live language switch

/// Bundle, у которого `localizedString(forKey:value:table:)` смотрит сначала
/// в "перегруженный" .lproj по выбранному языку. Используется через
/// `object_setClass(Bundle.main, LocalizedBundle.self)` — то есть мы меняем
/// поведение конкретного экземпляра `Bundle.main`, не трогая другие bundles.
private final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String,
                                  value: String?,
                                  table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &Bundle.bundleAssociationKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    fileprivate static var bundleAssociationKey: UInt8 = 0

    /// Однократно подменяем класс у `Bundle.main`. Вызывается лениво из
    /// `setLanguage(_:)`. Глобальные значения (let на static) гарантируют,
    /// что подмена случится ровно один раз даже при гонках.
    private static let installSwizzleOnce: Void = {
        object_setClass(Bundle.main, LocalizedBundle.self)
    }()

    /// Установить язык для последующих обращений к локализованным строкам.
    /// Передача `nil` сбрасывает к дефолтному поведению (системный язык).
    static func setLanguage(_ code: String?) {
        _ = installSwizzleOnce
        let bundle: Bundle?
        if let code,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let resolved = Bundle(path: path) {
            bundle = resolved
        } else {
            bundle = nil
        }
        objc_setAssociatedObject(Bundle.main,
                                 &bundleAssociationKey,
                                 bundle,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
