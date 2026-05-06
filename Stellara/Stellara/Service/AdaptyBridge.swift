import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(Adapty)
import Adapty
#endif

#if canImport(AdaptyUI)
import AdaptyUI
#endif

/// Фасад над Adapty + AdaptyUI.
///
/// Когда SPM-пакеты НЕ подключены — все методы no-op, `tryFetchOnboarding`
/// возвращает false, и `RootView` идёт в нативный `OnboardingView`.
///
/// ──────────────────────────────────────────────────────────────────────
/// УСТАНОВКА (один раз):
///   1. Xcode → File → Add Package Dependencies →
///      https://github.com/adaptyteam/AdaptySDK-iOS  (продукты: Adapty, AdaptyUI)
///   2. В Adapty Dashboard:
///      • опубликовать онбординг (статус Published, не Draft);
///      • создать Onboarding placement c id `welcome_flow`;
///      • прицепить к плейсменту аудиторию (например `all`).
/// ──────────────────────────────────────────────────────────────────────
enum AdaptyBridge {

    /// Public SDK Key из Adapty dashboard. Это публичный клиентский ключ —
    /// embed-friendly, безопасно держать в коде.
    static let apiKey: String = "public_live_pd2LLtU5.NiC927AocqBx7gnIswdh"

    /// Placement-id онбординга, созданный в Adapty.
    static let onboardingPlacementId: String = "welcome_flow"

    /// Тайм-аут на сетевой запрос конфига Adapty. Если медленный интернет —
    /// быстро откатимся на нативный онбординг (см. `OnboardingRouter.decide`).
    static let onboardingFetchTimeout: TimeInterval = 2.5

    // MARK: - Cache

    #if canImport(Adapty)
    /// Загруженный онбординг — нужен и для `AdaptyOnboardingView`, и для
    /// чтения `remoteConfig` (там лежит `privacy_policy_url` и т.д.).
    @MainActor static var cachedOnboarding: AdaptyOnboarding?
    #endif

    // MARK: - Activation

    /// Активация SDK при старте приложения. Зови из `StellaraApp.init()`.
    ///
    /// Внутри активируем сначала ядро Adapty, затем — AdaptyUI отдельным шагом.
    /// Порядок важен: AdaptyUI бросает ошибку «SDK must be initialized», если
    /// его дёрнуть до завершения `Adapty.activate(...)`.
    static func activate() {
        #if canImport(Adapty)
        Task {
            do {
                let config = AdaptyConfiguration
                    .builder(withAPIKey: apiKey)
                    .build()
                try await Adapty.activate(with: config)

                #if canImport(AdaptyUI)
                try await AdaptyUI.activate()
                #endif

                #if DEBUG
                print("Adapty + AdaptyUI activated.")
                #endif
            } catch {
                #if DEBUG
                print("Adapty.activate error:", error)
                #endif
            }
        }
        #else
        #if DEBUG
        print("AdaptyBridge.activate(): SDK not linked yet, skipping.")
        #endif
        #endif
    }

    // MARK: - Profile

    /// Установить кастом-атрибуты пользователя (имя/возраст/страна) после онбординга.
    /// Сейчас прокидываем только `firstName`. Если позже понадобятся возраст/страна —
    /// добавим через `with(birthday:)` и кастомные атрибуты по актуальному API SDK.
    static func updateProfile(name: String?, age: Int?, country: String?) {
        #if canImport(Adapty)
        Task {
            do {
                let builder = AdaptyProfileParameters.Builder()
                if let name, !name.isEmpty {
                    _ = builder.with(firstName: name)
                }
                try await Adapty.updateProfile(params: builder.build())
            } catch {
                #if DEBUG
                print("Adapty.updateProfile error:", error)
                #endif
            }
        }
        #else
        #if DEBUG
        print("AdaptyBridge.updateProfile name=\(name ?? "-") age=\(age.map(String.init) ?? "-") country=\(country ?? "-")")
        #endif
        #endif
    }

    // MARK: - Analytics passthrough

    /// Логирует событие в Adapty (зарезервировано на потом).
    static func logEvent(_ name: String, params: [String: Any]) {
        // no-op
    }

    // MARK: - Onboarding fetch

    /// Префлайт: тянем онбординг и проверяем, что view-config доступен.
    /// Возвращает true → в RootView идём в Adapty-онбординг,
    /// false → fallback на нативный.
    static func tryFetchOnboarding() async -> Bool {
        #if canImport(Adapty) && canImport(AdaptyUI)
        do {
            let onboarding = try await Adapty.getOnboarding(placementId: onboardingPlacementId)
            // Конфиг в актуальном API синхронный — просто убеждаемся, что
            // он подгружается без ошибок, и кэшируем сам онбординг.
            _ = try AdaptyUI.getOnboardingConfiguration(forOnboarding: onboarding)
            await MainActor.run {
                Self.cachedOnboarding = onboarding
            }
            return true
        } catch {
            #if DEBUG
            print("Adapty.getOnboarding error:", error)
            #endif
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Remote config

    /// Прочитать строку из remote config привязанного онбординга.
    /// Использование: `AdaptyBridge.remoteString("privacy_policy_url")`.
    @MainActor
    static func remoteString(_ key: String) -> String? {
        #if canImport(Adapty)
        guard let dict = cachedOnboarding?.remoteConfig?.dictionary else { return nil }
        return dict[key] as? String
        #else
        return nil
        #endif
    }
}

// MARK: - Onboarding host view

/// Хост для Adapty-онбординга. Если SDK подключён и онбординг закэширован —
/// рендерит `AdaptyOnboardingView`; иначе — звёздный фон + ProgressView.
struct AdaptyOnboardingHost: View {
    let onFinish: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            StarryBackground()
            content
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        #if canImport(Adapty) && canImport(AdaptyUI)
        if let onboarding = AdaptyBridge.cachedOnboarding,
           let config = try? AdaptyUI.getOnboardingConfiguration(forOnboarding: onboarding) {
            AdaptyOnboardingView(
                configuration: config,
                placeholder: {
                    ProgressView().tint(.white)
                },
                onCloseAction: { _ in
                    onFinish()
                },
                onCustomAction: { action in
                    handleCustomAction(actionId: action.actionId)
                },
                onError: { error in
                    #if DEBUG
                    print("AdaptyOnboardingView error:", error)
                    #endif
                    onFinish()
                }
            )
        } else {
            ProgressView().tint(.white)
        }
        #else
        ProgressView().tint(.white)
        #endif
    }

    /// Все custom-actions, заведённые в Adapty Onboarding builder, прилетают сюда.
    /// Сейчас знаем один — `open_privacy`. Добавишь новые — заводи кейсы здесь.
    private func handleCustomAction(actionId: String) {
        switch actionId {
        case "open_privacy":
            openRemoteURL(forKey: "privacy_policy_url")
        default:
            #if DEBUG
            print("Unhandled Adapty custom action:", actionId)
            #endif
        }
    }

    /// Достаёт строку из remote config закэшированного онбординга и открывает её
    /// в браузере. Если ключа нет / не валидный URL — молча игнорируем.
    private func openRemoteURL(forKey key: String) {
        let str = MainActor.assumeIsolated { AdaptyBridge.remoteString(key) }
        guard let str, let url = URL(string: str) else {
            #if DEBUG
            print("openRemoteURL: missing or invalid URL for key", key)
            #endif
            return
        }
        openURL(url)
    }
}
