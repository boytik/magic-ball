import SwiftUI

/// Корневой view. Flow:
///   OnboardingView (только при первом запуске) → LoadingView →
///   NotificationPermissionView (один раз) → MainTabs.
///
/// Когда подключим Adapty Onboardings, сюда добавится третья ветка:
/// сначала пробуем показать AdaptyOnboarding, если он недоступен —
/// fall back на нативный `OnboardingView`.
struct RootView: View {
    @AppStorage("stellara.didFinishOnboarding") private var didFinishOnboarding = false
    /// Уже показывали ли мы пост-лоадинговый запрос на пуши.
    /// Хранится в UserDefaults — спрашиваем строго один раз на установку.
    @AppStorage("stellara.didAskForNotifications") private var didAskForNotifications = false
    @State private var didFinishLoading = false

    var body: some View {
        ZStack {
            if !didFinishOnboarding {
                OnboardingRouter()
                    .transition(.opacity)
            } else if !didFinishLoading {
                LoadingView {
                    withAnimation(.easeInOut(duration: 0.4)) { didFinishLoading = true }
                }
                .transition(.opacity)
            } else if !didAskForNotifications {
                NotificationPermissionView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        didAskForNotifications = true
                    }
                }
                .transition(.opacity)
            } else {
                MainTabs()
                    .transition(.opacity)
            }
        }
    }
}

private struct MainTabs: View {
    @EnvironmentObject private var music: MusicPlayer
    @EnvironmentObject private var notifications: NotificationManager
    @Environment(\.scenePhase) private var scenePhase

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
        .onAppear {
            music.play()
            // Юзер мог в Settings вкл/выкл пуши — синхронизируемся при возврате.
            Task { await notifications.refreshStatus() }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                music.play()
                Task { await notifications.refreshStatus() }
            case .inactive, .background:
                music.stop()
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(PredictionStore())
        .environmentObject(UserProfileStore())
        .environmentObject(UsageTracker())
        .environmentObject(MusicPlayer())
        .environmentObject(NotificationManager())
}
