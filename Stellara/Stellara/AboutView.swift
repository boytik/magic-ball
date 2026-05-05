import SwiftUI
import StoreKit

/// Экран "О приложении" / настройки.
///
/// Структура:
///  • Hero (бренд + слоган)
///  • Карточка профиля
///  • Группа Support: Rate / Share
///  • Группа Info: About / Disclaimer / Privacy — открываются шитами
///  • Версия снизу
struct AboutView: View {
    @EnvironmentObject private var profileStore: UserProfileStore
    @Environment(\.requestReview) private var requestReview

    @State private var activeSheet: InfoSheet?

    enum InfoSheet: Int, Identifiable {
        case about, disclaimer, privacy
        var id: Int { rawValue }
    }

    var body: some View {
        ZStack {
            StarryBackground()

            ScrollView {
                VStack(spacing: 28) {
                    hero
                        .padding(.top, 8)

                    profileCard

                    supportCard

                    infoCard

                    versionFooter
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
            InfoSheetView(kind: sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.45),
                                Color.purple.opacity(0.05),
                                .clear
                            ],
                            center: .center, startRadius: 4, endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: .purple.opacity(0.7), radius: 12)
            }

            Text("Stellara")
                .font(.system(size: 34, weight: .light, design: .serif))
                .foregroundStyle(.white)
                .tracking(2)

            Text("about.tagline")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Profile card

    private var profileCard: some View {
        NavigationLink {
            ProfileView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: profileStore.profile.isFilled
                                    ? [.purple.opacity(0.9), .indigo.opacity(0.7)]
                                    : [.white.opacity(0.15), .white.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: profileStore.profile.isFilled ? "person.fill" : "person.crop.circle.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(profileStore.profile.isFilled ? "about.profile.title" : "about.profile.cta")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(profileSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.4))
            )
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var profileSubtitle: String {
        let p = profileStore.profile
        guard p.isFilled else {
            return NSLocalizedString("about.profile.subtitle", comment: "")
        }
        var parts: [String] = []
        let trimmed = p.name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { parts.append(trimmed) }
        if let age = p.age { parts.append("\(age)") }
        if !p.countryCode.isEmpty,
           let country = Locale.current.localizedString(forRegionCode: p.countryCode) {
            parts.append(country)
        }
        return parts.isEmpty
            ? NSLocalizedString("about.profile.subtitle", comment: "")
            : parts.joined(separator: " · ")
    }

    // MARK: - Support card

    private var supportCard: some View {
        SettingsCard(title: "about.section.support") {
            SettingsRow(
                icon: "star.fill",
                tint: Color(red: 0.96, green: 0.78, blue: 0.30),
                title: "about.actions.rate"
            ) {
                requestReview()
            }

            Divider().background(.white.opacity(0.08))
                .padding(.leading, 60)

            ShareLink(item: Config.appStoreURL,
                      message: Text("share.app.message")) {
                SettingsRowContent(
                    icon: "square.and.arrow.up",
                    tint: Color(red: 0.40, green: 0.75, blue: 0.95),
                    title: "about.actions.share",
                    showsChevron: false,
                    trailing: AnyView(
                        Image(systemName: "arrow.up.forward.app")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Info card

    private var infoCard: some View {
        SettingsCard(title: "about.section.info") {
            SettingsRow(
                icon: "info.circle.fill",
                tint: Color(red: 0.55, green: 0.42, blue: 0.95),
                title: "about.row.about"
            ) {
                activeSheet = .about
            }

            Divider().background(.white.opacity(0.08)).padding(.leading, 60)

            SettingsRow(
                icon: "exclamationmark.shield.fill",
                tint: Color(red: 0.92, green: 0.55, blue: 0.30),
                title: "about.row.disclaimer"
            ) {
                activeSheet = .disclaimer
            }

            Divider().background(.white.opacity(0.08)).padding(.leading, 60)

            SettingsRow(
                icon: "lock.fill",
                tint: Color(red: 0.40, green: 0.78, blue: 0.55),
                title: "about.row.privacy"
            ) {
                activeSheet = .privacy
            }
        }
    }

    // MARK: - Version

    private var versionFooter: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return VStack(spacing: 4) {
            Text("Stellara")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
            Text("\(NSLocalizedString("about.version", comment: "")) \(version) (\(build))")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reusable card container

struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder var content: () -> Content

    init(title: LocalizedStringKey? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 6)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings row

/// Кнопка-строка в карточке. По нажатию вызывает action.
struct SettingsRow: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowContent(icon: icon, tint: tint, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}

/// Чисто визуальная начинка строки — используется и как label у ShareLink.
struct SettingsRowContent: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var showsChevron: Bool = true
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Spacer(minLength: 8)

            if let trailing {
                trailing
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Info sheet

private struct InfoSheetView: View {
    let kind: AboutView.InfoSheet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                StarryBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Иконка-герой
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [tint.opacity(0.9), tint.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .shadow(color: tint.opacity(0.6), radius: 16)
                            Image(systemName: iconName)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 8)

                        Text(titleKey)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(bodyKey)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                            .padding(.horizontal, 4)
                    }
                    .padding(20)
                }
                .scrollContentBackground(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private var iconName: String {
        switch kind {
        case .about:      return "info.circle.fill"
        case .disclaimer: return "exclamationmark.shield.fill"
        case .privacy:    return "lock.fill"
        }
    }

    private var tint: Color {
        switch kind {
        case .about:      return Color(red: 0.55, green: 0.42, blue: 0.95)
        case .disclaimer: return Color(red: 0.92, green: 0.55, blue: 0.30)
        case .privacy:    return Color(red: 0.40, green: 0.78, blue: 0.55)
        }
    }

    private var titleKey: LocalizedStringKey {
        switch kind {
        case .about:      return "about.row.about"
        case .disclaimer: return "about.disclaimer.title"
        case .privacy:    return "about.privacy.title"
        }
    }

    private var bodyKey: LocalizedStringKey {
        switch kind {
        case .about:      return "about.intro"
        case .disclaimer: return "about.disclaimer.body"
        case .privacy:    return "about.privacy.body"
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
        .environmentObject(UserProfileStore())
}
