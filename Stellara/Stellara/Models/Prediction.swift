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

    init(question: String, answer: String, oracleId: String) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.oracleId = oracleId
        self.createdAt = Date()
    }
}
