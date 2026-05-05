import Foundation

/// Тонкая фасадная обёртка над аналитикой.
///
/// На старте нет ни одного провайдера — все события улетают в `print` в DEBUG
/// и игнорируются в Release. Когда добавишь AppsFlyer / Amplitude / Adapty,
/// меняем тело методов в одном месте без правок в UI-коде.
enum Analytics {

    enum Event: String {
        // App lifecycle
        case appOpen                = "app_open"
        case onboardingStarted      = "onboarding_started"
        case onboardingFinished     = "onboarding_finished"
        case onboardingDisclaimerAccepted = "onboarding_disclaimer_accepted"
        case onboardingProfileFilled     = "onboarding_profile_filled"
        case onboardingProfileSkipped    = "onboarding_profile_skipped"
        case onboardingNotificationsAllowed  = "onboarding_notifications_allowed"
        case onboardingNotificationsDeclined = "onboarding_notifications_declined"

        // Oracle
        case predictionRequested    = "prediction_requested"
        case predictionDelivered    = "prediction_delivered"
        case predictionFailed       = "prediction_failed"
        case predictionLimitReached = "prediction_limit_reached"
        case personaChanged         = "persona_changed"
        case voiceInputUsed         = "voice_input_used"

        // Settings / engagement
        case profileEdited          = "profile_edited"
        case musicToggled           = "music_toggled"
        case dailyReminderToggled   = "daily_reminder_toggled"
        case shareTapped            = "share_tapped"
        case rateTapped             = "rate_tapped"
    }

    /// Универсальный track. Параметры — primitive types only.
    static func track(_ event: Event, _ parameters: [String: Any] = [:]) {
        #if DEBUG
        if parameters.isEmpty {
            print("📊 \(event.rawValue)")
        } else {
            print("📊 \(event.rawValue) \(parameters)")
        }
        #endif

        // Когда подключишь SDK — раскомментируй нужные строчки.
        // Adapty (через наш фасад):
        AdaptyBridge.logEvent(event.rawValue, params: parameters)
        //
        // Amplitude (если решишь добавить):
        // Amplitude.instance.track(eventType: event.rawValue, eventProperties: parameters)
        //
        // PostHog:
        // PostHogSDK.shared.capture(event.rawValue, properties: parameters)
    }

    /// Установить user-property (имя, возраст, страна и т.п.).
    /// Используется после онбординга и при правке профиля.
    static func setUserProperty(_ key: String, value: Any?) {
        #if DEBUG
        print("📊 user[\(key)] = \(String(describing: value))")
        #endif

        // Amplitude.instance.identify(...).set(...)
        // PostHogSDK.shared.identify(distinctId: ..., userProperties: ...)
    }
}
