import SwiftUI

@main
struct StellaraApp: App {
    @StateObject private var store = PredictionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
