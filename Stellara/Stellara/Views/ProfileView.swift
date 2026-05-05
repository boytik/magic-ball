import SwiftUI

/// Анкета профиля. Открывается с экрана настроек.
struct ProfileView: View {
    @EnvironmentObject private var store: UserProfileStore
    @Environment(\.dismiss) private var dismiss

    /// Локальная копия — сохраняем только по кнопке.
    @State private var draft = UserProfile()
    @State private var hasBirthDate: Bool = false
    @State private var birthDateValue: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()

    var body: some View {
        ZStack {
            StarryBackground()

            Form {
                Section {
                    Text("profile.intro")
                        .foregroundStyle(.white.opacity(0.85))
                        .listRowBackground(Color.white.opacity(0.04))
                }

                Section("profile.section.basic") {
                    TextField("profile.name.placeholder", text: $draft.name)
                        .textInputAutocapitalization(.words)

                    Toggle("profile.birthdate.toggle", isOn: $hasBirthDate)

                    if hasBirthDate {
                        DatePicker(
                            "profile.birthdate",
                            selection: $birthDateValue,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }

                    Picker("profile.gender", selection: $draft.gender) {
                        ForEach(UserProfile.Gender.allCases) { gender in
                            Text(LocalizedStringKey(gender.localizationKey)).tag(gender)
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section("profile.section.location") {
                    Picker(selection: $draft.countryCode) {
                        Text("profile.country.unspecified").tag("")
                        ForEach(Self.countries, id: \.code) { item in
                            Text(item.name).tag(item.code)
                        }
                    } label: {
                        Text("profile.country")
                    }
                    .pickerStyle(.navigationLink)
                }
                .listRowBackground(Color.white.opacity(0.06))
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(.white)
        }
        .preferredColorScheme(.dark)
        .navigationTitle("profile.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("profile.save") { save() }
                    .bold()
            }
        }
        .onAppear {
            draft = store.profile
            if let bd = store.profile.birthDate {
                hasBirthDate = true
                birthDateValue = bd
            }
        }
    }

    private func save() {
        draft.birthDate = hasBirthDate ? birthDateValue : nil
        store.profile = draft
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        dismiss()
    }

    // MARK: - Countries

    private struct CountryItem {
        let code: String
        let name: String
    }

    /// Список стран в локали пользователя, отсортирован по имени.
    private static let countries: [CountryItem] = {
        let locale = Locale.current
        let codes: [String]
        if #available(iOS 16.0, *) {
            codes = Locale.Region.isoRegions
                .map { $0.identifier }
                .filter { $0.count == 2 }
        } else {
            codes = Locale.isoRegionCodes
        }
        return codes
            .compactMap { code -> CountryItem? in
                guard let name = locale.localizedString(forRegionCode: code) else { return nil }
                return CountryItem(code: code, name: name)
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }()
}

#Preview {
    NavigationStack { ProfileView() }
        .environmentObject(UserProfileStore())
}
