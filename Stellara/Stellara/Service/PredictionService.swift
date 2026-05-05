import Foundation

enum PredictionError: LocalizedError {
    case badResponse
    case rateLimited(limit: Int)
    case server(String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return NSLocalizedString("error.bad_response", comment: "")
        case .rateLimited(let limit):
            return String(format: NSLocalizedString("error.rate_limited.format", comment: ""), limit)
        case .server(let msg):
            return String(format: NSLocalizedString("error.server.format", comment: ""), msg)
        case .network(let err):
            return String(format: NSLocalizedString("error.network.format", comment: ""), err.localizedDescription)
        }
    }
}

struct PredictionResponse: Decodable {
    let answer: String
    let persona: String
    let usedToday: Int
    let dailyLimit: Int
}

private struct ServerError: Decodable {
    let error: String
    let limit: Int?
}

/// Тело запроса в /predict. Профиль опционален — кладётся в `user`, если заполнен.
private struct PredictRequest: Encodable {
    let question: String
    let persona: String
    let user: UserPayload?

    struct UserPayload: Encodable {
        let name: String?
        let age: Int?
        let gender: String?
        let countryCode: String?
    }
}

actor PredictionService {
    nonisolated static let shared = PredictionService()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        return URLSession(configuration: cfg)
    }()

    func predict(question: String,
                 oracle: Oracle,
                 profile: UserProfile? = nil) async throws -> PredictionResponse {
        var req = URLRequest(url: Config.backendURL.appendingPathComponent("predict"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.deviceId, forHTTPHeaderField: "X-Device-Id")

        let userPayload: PredictRequest.UserPayload? = {
            guard let profile, profile.isFilled else { return nil }
            let trimmedName = profile.name.trimmingCharacters(in: .whitespaces)
            return PredictRequest.UserPayload(
                name: trimmedName.isEmpty ? nil : trimmedName,
                age: profile.age,
                gender: profile.gender == .unspecified ? nil : profile.gender.rawValue,
                countryCode: profile.countryCode.isEmpty ? nil : profile.countryCode
            )
        }()

        req.httpBody = try JSONEncoder().encode(PredictRequest(
            question: question,
            persona: oracle.id,
            user: userPayload
        ))

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw PredictionError.network(error)
        }

        guard let http = resp as? HTTPURLResponse else { throw PredictionError.badResponse }

        if http.statusCode == 429 {
            let body = try? JSONDecoder().decode(ServerError.self, from: data)
            throw PredictionError.rateLimited(limit: body?.limit ?? 30)
        }
        if !(200..<300).contains(http.statusCode) {
            let body = try? JSONDecoder().decode(ServerError.self, from: data)
            throw PredictionError.server(body?.error ?? "code \(http.statusCode)")
        }

        do {
            return try JSONDecoder().decode(PredictionResponse.self, from: data)
        } catch {
            throw PredictionError.badResponse
        }
    }
}
