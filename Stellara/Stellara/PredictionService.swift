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

actor PredictionService {
    nonisolated static let shared = PredictionService()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        return URLSession(configuration: cfg)
    }()

    func predict(question: String, oracle: Oracle) async throws -> PredictionResponse {
        var req = URLRequest(url: Config.backendURL.appendingPathComponent("predict"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.deviceId, forHTTPHeaderField: "X-Device-Id")
        req.httpBody = try JSONEncoder().encode([
            "question": question,
            "persona": oracle.id,
        ])

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
