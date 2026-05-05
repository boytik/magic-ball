import SwiftUI

@main
struct StellaraApp: App {
    @StateObject private var store = PredictionStore()
    @StateObject private var profile = UserProfileStore()
    @StateObject private var usage = UsageTracker()
    @StateObject private var music = MusicPlayer()
    @StateObject private var notifications = NotificationManager()

    init() {
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
        }
    }
}
