import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: PredictionStore

    var body: some View {
        ZStack {
            StarryBackground()

            if store.predictions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 56))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("history.empty.title")
                        .font(.title3).foregroundStyle(.white.opacity(0.7))
                    Text("history.empty.subtitle")
                        .font(.callout).foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(store.predictions) { p in
                        let oracle = Oracle.by(id: p.oracleId)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: oracle.symbol)
                                    .foregroundStyle(oracle.accent)
                                Text(oracle.localizedName).font(.caption).bold()
                                Spacer()
                                Text(p.createdAt, style: .date)
                                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
                            }
                            Text(p.question)
                                .font(.callout).foregroundStyle(.white.opacity(0.9))
                            Text(p.answer)
                                .font(.body).italic()
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .onDelete { offsets in store.delete(at: offsets) }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("tab.history")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .environmentObject(PredictionStore())
}
