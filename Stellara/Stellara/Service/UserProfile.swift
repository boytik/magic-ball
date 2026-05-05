import Foundation
import Combine

/// Профиль пользователя для персонализации предсказаний.
/// Хранится локально в UserDefaults (никуда не уходит, кроме как в predict-запрос).
struct UserProfile: Codable, Equatable {
    var name: String = ""
    var birthDate: Date? = nil
    var gender: Gender = .unspecified
    /// ISO-код страны, например "RU", "US", "FR".
    var countryCode: String = ""

    enum Gender: String, Codable, CaseIterable, Identifiable {
        case unspecified
        case female
        case male
        case other

        var id: String { rawValue }

        var localizationKey: String {
            switch self {
            case .unspecified: return "profile.gender.unspecified"
            case .female:      return "profile.gender.female"
            case .male:        return "profile.gender.male"
            case .other:       return "profile.gender.other"
            }
        }
    }

    /// Признак, что пользователь хоть что-то заполнил.
    var isFilled: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            || birthDate != nil
            || gender != .unspecified
            || !countryCode.isEmpty
    }

    /// Возраст в годах (если есть дата рождения).
    var age: Int? {
        guard let birthDate else { return nil }
        let comps = Calendar.current.dateComponents([.year], from: birthDate, to: Date())
        return comps.year
    }
}

@MainActor
final class UserProfileStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet { persist() }
    }

    private let key = "stellara.userProfile.v1"
    private let defaults = UserDefaults.standard

    init() {
        if let data = UserDefaults.standard.data(forKey: "stellara.userProfile.v1"),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = UserProfile()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: key)
        }
    }
}
