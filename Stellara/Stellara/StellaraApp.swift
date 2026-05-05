import SwiftUI

@main
struct StellaraApp: App {
    @StateObject private var store = PredictionStore()
    @StateObject private var profile = UserProfileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(profile)
        }
    }
}
