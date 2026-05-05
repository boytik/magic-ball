import Foundation

enum Config {
    /// URL твоего Cloudflare Worker'a, заменить после деплоя.
    /// Пример: "https://stellara-oracle.boytik.workers.dev"
    nonisolated static let backendURL = URL(string: "https://stellara-oracle.REPLACE_ME.workers.dev")!

    /// App Store ID. Заменить на реальный после публикации.
    /// Используется в ссылках Rate / Share.
    nonisolated static let appStoreId = "0000000000"

    nonisolated static var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreId)")!
    }

    nonisolated static var appStoreReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreId)?action=write-review")!
    }

    /// Device-id живёт в UserDefaults. Если хочешь крепче — переложи в Keychain.
    nonisolated static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: "stellara.deviceId") {
            return existing
        }
        let new = UUID().uuidString.lowercased()
        UserDefaults.standard.set(new, forKey: "stellara.deviceId")
        return new
    }
}
