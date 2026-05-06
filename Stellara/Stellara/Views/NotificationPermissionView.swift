import SwiftUI

/// Запрос разрешения на пуши после LoadingView.
///
/// Показывается ровно один раз: после первого появления MainTabs ставим
/// `stellara.didAskForNotifications = true` и больше не возвращаемся к этому
/// экрану — даже если пользователь нажал «Skip».
///
/// При нажатии «Allow» вызывается системный диалог. Если пользователь дал
/// разрешение — включаем все категории (`.dailyReset`, `.cosmicEvents`,
/// `.weeklyForecast`) через `NotificationManager.enableAllCategories()`,
/// чтобы дальнейшее планирование подхватилось автоматически.
struct NotificationPermissionView: View {
    @EnvironmentObject private var notifications: NotificationManager

    /// Колбэк, вызываемый когда экран нужно скрыть (после Allow или Skip).
    var onFinish: () -> Void

    @State private var isRequesting = false

    var body: some View {
        ZStack {
            StarryBackground(
                density: 1.2,
                sparkleIntensity: 1.4,
                showsShootingStars: true
            )

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.cyan.opacity(0.45), .cyan.opacity(0.05), .clear],
                                center: .center, startRadius: 6, endRadius: 130
                            )
                        )
                        .frame(width: 220, height: 220)

                    Circle()
                        .fill(Color.cyan.opacity(0.22))
                        .frame(width: 110, height: 110)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(.cyan)
                }

                Text("onboarding.notifications.title")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("onboarding.notifications.body")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 28)

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        Analytics.track(.onboardingNotificationsDeclined)
                        onFinish()
                    } label: {
                        Text("onboarding.cta.skip")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 18).padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequesting)

                    Button {
                        Task { await requestAndContinue() }
                    } label: {
                        ZStack {
                            Text("onboarding.notifications.allow")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .opacity(isRequesting ? 0 : 1)
                            if isRequesting {
                                ProgressView().tint(.white)
                            }
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [.purple, .indigo],
                                           startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequesting)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func requestAndContinue() async {
        guard !isRequesting else { return }
        isRequesting = true

        let granted = await notifications.requestAuthorization()

        // Включаем все категории (`all`). NotificationManager уже хранит флаг
        // и (пере)планирует уведомления внутри setEnabled.
        if granted {
            notifications.enableAllCategories()
        }

        Analytics.track(granted
                        ? .onboardingNotificationsAllowed
                        : .onboardingNotificationsDeclined)

        isRequesting = false
        onFinish()
    }
}

#Preview {
    NotificationPermissionView(onFinish: {})
        .environmentObject(NotificationManager())
}
