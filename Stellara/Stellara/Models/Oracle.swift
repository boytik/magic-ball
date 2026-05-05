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
