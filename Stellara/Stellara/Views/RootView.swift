import SwiftUI
import StoreKit

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
    @EnvironmentObject private var profileStore: UserProfileStore
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            StarryBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    profileCard

                    actionButtons

                    Divider().background(.white.opacity(0.2))

                    Text("about.intro")
                        .foregroundStyle(.white.opacity(0.85))

                    Divider().background(.white.opacity(0.2))

                    Text("about.disclaimer.title")
                        .font(.headline).foregroundStyle(.white)
                    Text("about.disclaimer.body")
                        .foregroundStyle(.white.opacity(0.7))

                    Divider().background(.white.opacity(0.2))

                    Text("about.privacy.title")
                        .font(.headline).foregroundStyle(.white)
                    Text("about.privacy.body")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Profile card

    private var profileCard: some View {
        NavigationLink {
            ProfileView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: profileStore.profile.isFilled ? "person.crop.circle.fill" : "person.crop.circle.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text(profileStore.profile.isFilled ? "about.profile.title" : "about.profile.cta")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.4))
                }

                Text(profileStore.profile.isFilled
                     ? profileSummary
                     : NSLocalizedString("about.profile.subtitle", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Короткое описание заполненного профиля.
    private var profileSummary: String {
        let p = profileStore.profile
        var parts: [String] = []
        let trimmedName = p.name.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty { parts.append(trimmedName) }
        if let age = p.age { parts.append("\(age)") }
        if !p.countryCode.isEmpty,
           let country = Locale.current.localizedString(forRegionCode: p.countryCode) {
            parts.append(country)
        }
        return parts.isEmpty
            ? NSLocalizedString("about.profile.subtitle", comment: "")
            : parts.joined(separator: " · ")
    }

    // MARK: - Rate & Share

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                rateTapped()
            } label: {
                actionRow(icon: "star.fill", title: "about.actions.rate", tint: .yellow)
            }
            .buttonStyle(.plain)

            ShareLink(
                item: Config.appStoreURL,
                message: Text("share.app.message")
            ) {
                actionRow(icon: "square.and.arrow.up", title: "about.actions.share", tint: .cyan)
            }
        }
    }

    private func actionRow(icon: String, title: LocalizedStringKey, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.7), in: Circle())

            Text(title)
                .foregroundStyle(.white)

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func rateTapped() {
        // 1) Сначала пытаемся показать встроенный prompt (он капчёвый, до 3 раз/год).
        requestReview()
        // 2) В качестве fallback — если хочется явный переход в Store, раскомментируй:
        // openURL(Config.appStoreReviewURL)
    }
}

#Preview {
    RootView()
        .environmentObject(PredictionStore())
        .environmentObject(UserProfileStore())
}
