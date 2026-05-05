import SwiftUI

/// Корневой view. Сейчас flow:
///   LoadingView (Lottie) → MainTabs.
/// OnboardingView сохранён в проекте, но временно не вызывается —
/// он вернётся, когда подключим Adapty paywall + расширенный онбординг.
struct RootView: View {
    @State private var stage: Stage = .loading

    enum Stage { case loading, main }

    var body: some View {
        ZStack {
            switch stage {
            case .loading:
                LoadingView { withAnimation(.easeInOut(duration: 0.4)) { stage = .main } }
                    .transition(.opacity)
            case .main:
                MainTabs()
                    .transition(.opacity)
            }
        }
    }
}

private struct MainTabs: View {
    var body: some View {
        TabView {
            OracleView()
                .tabItem { Label("tab.oracle", systemImage: "sparkles") }

            NavigationStack { HistoryView() }
                .tabItem { Label("tab.history", systemImage: "clock") }

            NavigationStack { AboutView() }
                .tabItem { Label("tab.about", systemImage: "info.circle") }
        }
        .tint(.purple)
    }
}

#Preview {
    RootView()
        .environmentObject(PredictionStore())
        .environmentObject(UserProfileStore())
}
