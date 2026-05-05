import Foundation

/// Запись предсказания. На iOS 16 храним просто как Codable struct
/// в JSON-файле (см. PredictionStore). При желании на iOS 17+
/// можно мигрировать на @Model SwiftData.
struct Prediction: Identifiable, Codable, Hashable {
    let id: UUID
    let question: String
    let answer: String
    let oracleId: String
    let createdAt: Date
    var isFavorite: Bool

    init(question: String, answer: String, oracleId: String) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.oracleId = oracleId
        self.createdAt = Date()
        self.isFavorite = false
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, question, answer, oracleId, createdAt, isFavorite
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id         = try c.decode(UUID.self,   forKey: .id)
        self.question   = try c.decode(String.self, forKey: .question)
        self.answer     = try c.decode(String.self, forKey: .answer)
        self.oracleId   = try c.decode(String.self, forKey: .oracleId)
        self.createdAt  = try c.decode(Date.self,   forKey: .createdAt)
        // Старые записи без поля — считаем не-избранными.
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}
