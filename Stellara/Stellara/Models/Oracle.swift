import SwiftUI

/// Каталог персонажей — статика, в bundle.
/// Промпты живут на бэкенде, тут только UI-метаданные.
/// Имя и подзаголовок берутся из Localizable.xcstrings по ключам
/// `oracle.<id>.name` / `oracle.<id>.title`.
struct Oracle: Identifiable, Hashable {
    let id: String          // ключ для бэкенда: "zephyra" / "madame_lou" / "cosmo"
    let symbol: String      // SF Symbol для аватарки
    let accent: Color       // акцентный цвет персонажа

    var localizedName: String {
        NSLocalizedString("oracle.\(id).name", comment: "Oracle display name")
    }

    var localizedTitle: String {
        NSLocalizedString("oracle.\(id).title", comment: "Oracle short subtitle")
    }

    /// Подробное описание персоны для info-шита.
    var localizedDescription: String {
        NSLocalizedString("oracle.\(id).description", comment: "Oracle long description")
    }

    /// Описание тона речи (одна короткая фраза).
    var localizedTone: String {
        NSLocalizedString("oracle.\(id).tone", comment: "Oracle voice tone")
    }

    /// Список «специализаций» через запятую — превращается в чипы.
    var localizedSpecialties: [String] {
        let raw = NSLocalizedString("oracle.\(id).specialties", comment: "Comma-separated specialties")
        return raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Примеры вопросов, по одному на строку (через `\n` в локализации).
    var localizedSampleQuestions: [String] {
        let raw = NSLocalizedString("oracle.\(id).samples", comment: "Sample questions, one per line")
        return raw.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    nonisolated static let all: [Oracle] = [
        Oracle(
            id: "zephyra",
            symbol: "moon.stars.fill",
            accent: Color(red: 0.55, green: 0.42, blue: 0.85)
        ),
        Oracle(
            id: "madame_lou",
            symbol: "flame.fill",
            accent: Color(red: 0.85, green: 0.55, blue: 0.30)
        ),
        Oracle(
            id: "cosmo",
            symbol: "sparkles",
            accent: Color(red: 0.40, green: 0.75, blue: 0.85)
        ),
    ]

    nonisolated static func by(id: String) -> Oracle {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}
