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

private struct AboutView: View {
    var body: some View {
        ZStack {
            StarryBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("about.title").font(.largeTitle).bold().foregroundStyle(.white)
                    Text("about.intro").foregroundStyle(.white.opacity(0.85))

                    Divider().background(.white.opacity(0.2))

                    Text("about.disclaimer.title").font(.headline).foregroundStyle(.white)
                    Text("about.disclaimer.body").foregroundStyle(.white.opacity(0.7))

                    Divider().background(.white.opacity(0.2))

                    Text("about.privacy.title").font(.headline).foregroundStyle(.white)
                    Text("about.privacy.body").foregroundStyle(.white.opacity(0.7))
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    RootView()
        .environmentObject(PredictionStore())
}
