import Foundation
import Combine

/// Хранилище истории предсказаний. JSON-файл в Documents.
/// На iOS 17+ можно при желании мигрировать на SwiftData.
@MainActor
final class PredictionStore: ObservableObject {
    @Published private(set) var predictions: [Prediction] = []

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent("predictions.json")
        load()
    }

    func add(_ prediction: Prediction) {
        predictions.insert(prediction, at: 0)
        persist()
    }

    func delete(at offsets: IndexSet) {
        for i in offsets.sorted(by: >) where predictions.indices.contains(i) {
            predictions.remove(at: i)
        }
        persist()
    }

    func deleteAll() {
        predictions.removeAll()
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard
            let data = try? Data(contentsOf: fileURL),
            let list = try? JSONDecoder.predictionDecoder.decode([Prediction].self, from: data)
        else { return }
        self.predictions = list.sorted { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        do {
            let data = try JSONEncoder.predictionEncoder.encode(predictions)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("PredictionStore persist error:", error)
            #endif
        }
    }
}

private extension JSONDecoder {
    static let predictionDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

private extension JSONEncoder {
    static let predictionEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
