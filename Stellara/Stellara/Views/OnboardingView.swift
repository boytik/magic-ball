import SwiftUI

/// Многошаговый онбординг. Используется как fallback, если Adapty
/// Onboardings недоступны (нет интернета / SDK не отвечает).
///
/// Сценарий:
///   1. Welcome
///   2. Disclaimer (обязательное согласие) — нужен для App Review.
///   3. Profile (имя + дата рождения, можно пропустить)
///   4. Notifications (разрешение на пуши)
///
/// По завершении ставит `stellara.didFinishOnboarding = true` через @AppStorage,
/// после чего `RootView` показывает LoadingView и далее MainTabs.
struct OnboardingView: View {
    @AppStorage("stellara.didFinishOnboarding") private var didFinishOnboarding = false

    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var notifications: NotificationManager

    @State private var step: Int = 0

    // Disclaimer
    @State private var didAcceptDisclaimer: Bool = false

    // Profile
    @State private var name: String = ""
    @State private var hasBirthDate: Bool = false
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year,
                                                               value: -25,
                                                               to: Date()) ?? Date()

    private let totalSteps = 4

    var body: some View {
        ZStack {
            StarryBackground(density: 1.2, sparkleIntensity: 1.4, showsShootingStars: true)

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                // Контент шага. Используем switch вместо TabView, чтобы
                // самим контролировать, можно ли вернуться назад.
                ZStack {
                    switch step {
                    case 0: welcomeStep
                    case 1: disclaimerStep
                    case 2: profileStep
                    default: notificationsStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)

                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
        .onAppear {
            Analytics.track(.onboardingStarted)
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.purple : Color.white.opacity(0.15))
                    .frame(height: 4)
                    .overlay(
                        Capsule().stroke(.white.opacity(0.05), lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.55), .purple.opacity(0.05), .clear],
                            center: .center, startRadius: 6, endRadius: 130
                        )
                    )
                    .frame(width: 240, height: 240)
                Image(systemName: "sparkles")
                    .font(.system(size: 70, weight: .light))
                    .foregroundStyle(.white)
                    .shadow(color: .purple.opacity(0.7), radius: 16)
            }

            Text("Stellara")
                .font(.system(size: 44, weight: .light, design: .serif))
                .foregroundStyle(.white)
                .tracking(3)

            Text("onboarding.welcome.body")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()
        }
    }

    // MARK: - Step 2: Disclaimer

    private var disclaimerStep: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 110, height: 110)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(.orange)
            }

            Text("onboarding.disclaimer.title")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("onboarding.disclaimer.body")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 24)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    didAcceptDisclaimer.toggle()
                }
                #if canImport(UIKit)
                UISelectionFeedbackGenerator().selectionChanged()
                #endif
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: didAcceptDisclaimer ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(didAcceptDisclaimer ? Color.purple : .white.opacity(0.5))
                    Text("onboarding.disclaimer.accept")
                        .font(.callout)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(didAcceptDisclaimer ? Color.purple.opacity(0.15) : .white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(didAcceptDisclaimer ? Color.purple.opacity(0.6) : .white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)

            Spacer()
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Step 3: Profile

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 16)

            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.25))
                    .frame(width: 92, height: 92)
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                Text("onboarding.profile.title")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("onboarding.profile.subtitle")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                TextField("profile.name.placeholder", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                    .foregroundStyle(.white)

                Toggle("profile.birthdate.toggle", isOn: $hasBirthDate)
                    .tint(.purple)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))

                if hasBirthDate {
                    DatePicker("profile.birthdate", selection: $birthDate,
                               in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(.purple)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 4)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Step 4: Notifications

    private var notificationsStep: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
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

            Text("onboarding.notifications.body")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        switch step {
        case 0:
            primaryButton(title: "onboarding.cta.continue", enabled: true) {
                advance()
            }
        case 1:
            primaryButton(title: "onboarding.cta.continue", enabled: didAcceptDisclaimer) {
                Analytics.track(.onboardingDisclaimerAccepted)
                advance()
            }
        case 2:
            HStack(spacing: 10) {
                Button {
                    Analytics.track(.onboardingProfileSkipped)
                    advance()
                } label: {
                    Text("onboarding.cta.skip")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)

                primaryButton(title: "onboarding.cta.continue", enabled: true) {
                    saveProfileFromForm()
                    Analytics.track(.onboardingProfileFilled, [
                        "has_name": !name.isEmpty,
                        "has_birthdate": hasBirthDate
                    ])
                    advance()
                }
            }
        default:
            HStack(spacing: 10) {
                Button {
                    Analytics.track(.onboardingNotificationsDeclined)
                    finish()
                } label: {
                    Text("onboarding.cta.skip")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)

                primaryButton(title: "onboarding.notifications.allow", enabled: true) {
                    Task {
                        let granted = await notifications.requestAuthorization()
                        Analytics.track(granted
                            ? .onboardingNotificationsAllowed
                            : .onboardingNotificationsDeclined)
                        finish()
                    }
                }
            }
        }
    }

    private func primaryButton(title: LocalizedStringKey,
                               enabled: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [.purple, .indigo],
                                   startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.4)
    }

    // MARK: - Actions

    private func advance() {
        if step < totalSteps - 1 {
            step += 1
        } else {
            finish()
        }
    }

    private func saveProfileFromForm() {
        var p = profileStore.profile
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { p.name = trimmed }
        if hasBirthDate { p.birthDate = birthDate }
        profileStore.profile = p

        if !trimmed.isEmpty {
            Analytics.setUserProperty("name", value: trimmed)
        }
        if hasBirthDate, let age = p.age {
            Analytics.setUserProperty("age", value: age)
        }

        // Тот же профиль уходит в Adapty для сегментации.
        AdaptyBridge.updateProfile(
            name: trimmed.isEmpty ? nil : trimmed,
            age: p.age,
            country: p.countryCode.isEmpty ? nil : p.countryCode
        )
    }

    private func finish() {
        Analytics.track(.onboardingFinished)
        withAnimation(.easeInOut(duration: 0.4)) {
            didFinishOnboarding = true
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(UserProfileStore())
        .environmentObject(NotificationManager())
}
