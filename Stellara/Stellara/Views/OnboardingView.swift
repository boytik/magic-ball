import SwiftUI

/// Один экран онбординга с обязательным дисклеймером для App Review.
/// На текущем этапе НЕ вызывается из RootView — возвращается, когда
/// подключим расширенный онбординг через Adapty.
struct OnboardingView: View {
    @Binding var didFinishOnboarding: Bool

    var body: some View {
        ZStack {
            StarryBackground()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .shadow(color: .purple.opacity(0.7), radius: 20)

                Text("Stellara")
                    .font(.system(size: 40, weight: .light, design: .serif))
                    .foregroundStyle(.white)

                Text("onboarding.subtitle")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                VStack(spacing: 14) {
                    Text("onboarding.disclaimer.title")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("onboarding.disclaimer.body")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                Button {
                    UserDefaults.standard.set(true, forKey: "stellara.didFinishOnboarding")
                    withAnimation { didFinishOnboarding = true }
                } label: {
                    Text("onboarding.cta")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32).padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.purple, .indigo],
                                           startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    OnboardingView(didFinishOnboarding: .constant(false))
}
