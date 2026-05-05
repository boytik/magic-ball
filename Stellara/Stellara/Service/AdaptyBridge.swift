import Foundation
import SwiftUI

/// Фасад над Adapty + AdaptyUI. Пока SDK не подключён — все методы no-op.
///
/// Когда добавишь SPM-пакеты (см. README ниже), внутри этого файла раскомментируешь
/// `import Adapty`, `import AdaptyUI` и тело методов. Никакой другой код менять
/// не нужно — `RootView` уже вызывает `AdaptyBridge.tryFetchOnboarding(...)`.
///
/// ──────────────────────────────────────────────────────────────────────
/// УСТАНОВКА (один раз):
///   1. В Xcode → File → Add Package Dependencies:
///      • https://github.com/adaptyteam/AdaptySDK-iOS    (product: Adapty)
///      • https://github.com/adaptyteam/AdaptyUI-iOS     (product: AdaptyUI)
///   2. В Adapty dashboard:
///      • создать проект, получить Public SDK Key,
///      • в разделе "Onboardings" собрать flow с placement-id (мы используем "welcome_flow").
///   3. Положить ключ ниже в `apiKey` или брать из xcconfig / Secrets.
///   4. Раскомментировать `import` и тела методов.
/// ──────────────────────────────────────────────────────────────────────
enum AdaptyBridge {

    /// Public SDK Key из Adapty dashboard. ⚠️ Замени перед релизом.
    static let apiKey: String = "public_live_REPLACE_ME"

    /// Placement-id онбординга в Adapty.
    static let onboardingPlacementId: String = "welcome_flow"

    /// Тайм-аут на сетевой запрос конфига Adapty. Если медленный интернет —
    /// быстро откатимся на нативный онбординг.
    static let onboardingFetchTimeout: TimeInterval = 2.5

    /// Активация SDK при старте приложения. Зови из `StellaraApp.init()`.
    static func activate() {
        // import Adapty
        // Adapty.activate(apiKey)
        #if DEBUG
        print("AdaptyBridge.activate() — SDK not linked yet, skipping.")
        #endif
    }

    /// Установить кастом-атрибуты пользователя (имя/возраст/страна) после онбординга.
    static func updateProfile(name: String?, age: Int?, country: String?) {
        // import Adapty
        // var builder = AdaptyProfileParameters.Builder()
        //   .with(firstName: name)
        //   .with(birthday: ...)
        //   .with(customAttributes: ["country": country])
        // Adapty.updateProfile(params: builder.build()) { _ in }
        #if DEBUG
        print("AdaptyBridge.updateProfile name=\(name ?? "-") age=\(age.map(String.init) ?? "-") country=\(country ?? "-")")
        #endif
    }

    /// Логирует событие в Adapty (для сегментации в их дашборде).
    static func logEvent(_ name: String, params: [String: Any]) {
        // import Adapty
        // Adapty.logShowOnboarding(...) или похожее
    }

    /// Попытаться загрузить view-config для онбординга. Возвращает true, если
    /// удалось получить за `onboardingFetchTimeout`. Сам показ — задача `RootView`,
    /// который рисует `AdaptyOnboardingHost`.
    ///
    /// Сейчас всегда возвращает false → используется нативный OnboardingView.
    static func tryFetchOnboarding() async -> Bool {
        // С SDK будет так:
        //
        // import AdaptyUI
        // do {
        //     let placement = try await Adapty.getOnboarding(placementId: onboardingPlacementId)
        //     let viewConfig = try await AdaptyUI.getViewConfiguration(forOnboarding: placement)
        //     await MainActor.run { Self.cachedConfig = viewConfig }
        //     return true
        // } catch {
        //     return false
        // }
        return false
    }
}

/// Хост для Adapty-онбординга. Сейчас рисует пустой звёздный фон —
/// когда SDK подключён, покажет AdaptyUI-вью с правильным `viewConfiguration`.
struct AdaptyOnboardingHost: View {
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            StarryBackground()
            // import AdaptyUI
            // AdaptyOnboardingView(viewConfig: AdaptyBridge.cachedConfig!) { event in
            //     switch event {
            //     case .closed, .finished: onFinish()
            //     default: break
            //     }
            // }
            ProgressView().tint(.white)
        }
        .preferredColorScheme(.dark)
    }
}
