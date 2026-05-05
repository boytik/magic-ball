import SwiftUI

/// Решает, какой онбординг показывать: Adapty (если онлайн и SDK ответил)
/// или нативный fallback. Маркирует завершение через `@AppStorage`.
struct OnboardingRouter: View {
    @AppStorage("stellara.didFinishOnboarding") private var didFinishOnboarding = false

    @State private var phase: Phase = .deciding

    enum Phase: Equatable {
        case deciding   // решаем, использовать Adapty или нативный
        case adapty     // показываем AdaptyUI-онбординг
        case native     // показываем наш OnboardingView
    }

    var body: some View {
        ZStack {
            switch phase {
            case .deciding:
                StarryBackground()
                ProgressView().tint(.white)
                    .scaleEffect(1.2)
            case .adapty:
                AdaptyOnboardingHost {
                    finish()
                }
                .transition(.opacity)
            case .native:
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: phase)
        .task {
            await decide()
        }
    }

    private func decide() async {
        // Пробуем Adapty с тайм-аутом. Если не отвечает или нет интернета — fallback.
        let success = await withTimeout(seconds: AdaptyBridge.onboardingFetchTimeout) {
            await AdaptyBridge.tryFetchOnboarding()
        }
        await MainActor.run {
            phase = success ? .adapty : .native
        }
    }

    private func finish() {
        // Завершение от Adapty — поставим флаг (нативный сам ставит его).
        withAnimation(.easeInOut(duration: 0.4)) {
            didFinishOnboarding = true
        }
    }

    /// Обёртка над операцией с тайм-аутом: возвращает результат или false.
    private func withTimeout(seconds: TimeInterval,
                             _ op: @escaping () async -> Bool) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { await op() }
            group.addTask {
                let nanos = UInt64(seconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }
}
