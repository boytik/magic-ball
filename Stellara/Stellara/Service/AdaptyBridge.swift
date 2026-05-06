import Foundation
import SwiftUI
import StoreKit

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
///
/// Custom-action `open_privacy` открывает in-app `WebShellView` (контент под
/// нотчем, навбар напротив выреза, сохраняет финальный URL и pathId).
struct AdaptyOnboardingHost: View {
    let onFinish: () -> Void

    @EnvironmentObject private var notifications: NotificationManager

    /// Тот же ключ, что использует RootView для пропуска NotificationPermissionView.
    /// Если запросили пуши тут — оно больше не показывается после loading.
    @AppStorage("stellara.didAskForNotifications") private var didAskForNotifications = false

    /// Открытый сейчас экран браузера (nil = ничего не показываем).
    @State private var webPresented: PresentedURL?

    var body: some View {
        ZStack {
            StarryBackground()
            content
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $webPresented) { wrapper in
            WebShellView(
                baseURL: wrapper.url,
                onDismiss: {
                    webPresented = nil
                },
                onUnopenable: {
                    // Первый вход и нечего показать — тихо закрываем браузер
                    // и считаем онбординг пройденным.
                    print("[Adapty] first entry & nothing opens → finishing onboarding")
                    webPresented = nil
                    onFinish()
                }
            )
        }
        .task {
            await requestNotificationsIfNeeded()
            scheduleReviewPrompt()
        }
    }

    // MARK: - Notifications & Review prompt

    /// Спрашиваем пуши сразу при появлении Adapty онбординга (одноразово).
    /// При успехе — включаем все категории. В любом случае ставим флаг,
    /// чтобы post-loading NotificationPermissionView больше не показывался.
    private func requestNotificationsIfNeeded() async {
        guard !didAskForNotifications else { return }
        let granted = await notifications.requestAuthorization()
        if granted {
            notifications.enableAllCategories()
        }
        Analytics.track(granted
                        ? .onboardingNotificationsAllowed
                        : .onboardingNotificationsDeclined)
        didAskForNotifications = true
    }

    /// Через 60 секунд после появления онбординга показываем системный rate-prompt.
    /// `DispatchQueue.main.asyncAfter` переживает уход с онбординга — таймер
    /// сработает даже если юзер уже на MainTabs (Apple сам ограничивает
    /// до 3 показов в год).
    private func scheduleReviewPrompt() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else { return }
            print("[Adapty] requesting App Store review after 60s")
            SKStoreReviewController.requestReview(in: scene)
        }
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
            presentRemoteURL(forKey: "privacy_policy_url")
        default:
            #if DEBUG
            print("Unhandled Adapty custom action:", actionId)
            #endif
        }
    }

    /// Достаёт строку из remote config закэшированного онбординга и открывает её
    /// в in-app браузере (`WebShellView`).
    ///
    /// Если URL отсутствует / битый И это первый вход (в сторе нет сохранённой
    /// финальной ссылки) — тихо завершаем онбординг (юзер не должен застрять).
    /// Если URL отсутствует, но есть saved → открыть сохранённое тоже не сможем
    /// (нужен base для fallback), поэтому тоже завершаем.
    private func presentRemoteURL(forKey key: String) {
        let str = MainActor.assumeIsolated { AdaptyBridge.remoteString(key) }
        guard let str, let url = URL(string: str) else {
            print("[Adapty] privacy click → no valid URL for key '\(key)' in remote config → finishing onboarding")
            onFinish()
            return
        }
        let savedFinal = WebRecoveryStore.shared.finalURL?.absoluteString ?? "nil"
        let savedPathId = WebRecoveryStore.shared.pathId ?? "nil"
        print("[Adapty] privacy click → adapty=\(url.absoluteString)")
        print("[Adapty]                 saved finalURL=\(savedFinal), pathId=\(savedPathId)")
        webPresented = PresentedURL(url: url)
    }
}

/// Identifiable-обёртка над URL, нужна для `.fullScreenCover(item:)`.
private struct PresentedURL: Identifiable {
    let id = UUID()
    let url: URL
}
