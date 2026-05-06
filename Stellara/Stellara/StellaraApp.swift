import SwiftUI

@main
struct StellaraApp: App {
    @UIApplicationDelegateAdaptor(StellaraAppDelegate.self) private var appDelegate

    @StateObject private var store = PredictionStore()
    @StateObject private var profile = UserProfileStore()
    @StateObject private var usage = UsageTracker()
    @StateObject private var music = MusicPlayer()
    @StateObject private var notifications = NotificationManager()
    @ObservedObject private var localization = LocalizationManager.shared

    init() {
        _ = LocalizationManager.shared
        AdaptyBridge.activate()
        Analytics.track(.appOpen)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(profile)
                .environmentObject(usage)
                .environmentObject(music)
                .environmentObject(notifications)
                .environmentObject(localization)
                .environment(\.locale, localization.locale)
                .id(localization.current)
        }
    }
}
