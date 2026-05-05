import SwiftUI

/// Полноэкранный (medium/large) шит с ответом оракула.
/// Открывается автоматически после успешного предсказания, и его же
/// можно открыть снова тапом по обрезанному ответу на главном экране.
struct AnswerSheet: View {
    let oracle: Oracle
    let question: String
    let answer: String
    /// Если задано — рядом с заголовком появится кнопка-звезда «избранное».
    /// Передаётся из HistoryView. На главном экране (свежий ответ) пока не передаём.
    var prediction: Prediction? = nil

    @EnvironmentObject private var store: PredictionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            StarryBackground()

            ScrollView {
                VStack(spacing: 22) {
                    avatar
                        .padding(.top, 16)

                    nameBlock

                    if !question.isEmpty {
                        questionBlock
                    }

                    answerBlock

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .topLeading) {
            if let p = currentPrediction {
                Button {
                    store.toggleFavorite(p)
                } label: {
                    Image(systemName: p.isFavorite ? "star.fill" : "star")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(p.isFavorite ? Color.yellow : .white.opacity(0.65))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.leading, 14)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 14)
        }
    }

    /// Свежее значение из стора (чтобы звезда мгновенно перерисовывалась после toggle).
    private var currentPrediction: Prediction? {
        guard let p = prediction else { return nil }
        return store.predictions.first(where: { $0.id == p.id }) ?? p
    }

    // MARK: - Avatar

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [oracle.accent.opacity(0.55), oracle.accent.opacity(0.05), .clear],
                        center: .center, startRadius: 6, endRadius: 110
                    )
                )
                .frame(width: 200, height: 200)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            oracle.accent.opacity(0.9),
                            Color.black.opacity(0.95),
                        ],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 6, endRadius: 110
                    )
                )
                .frame(width: 130, height: 130)
                .overlay(
                    Circle().stroke(
                        LinearGradient(colors: [.white.opacity(0.3), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
                )
                .shadow(color: oracle.accent.opacity(0.55), radius: 24)

            Image(systemName: oracle.symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .white.opacity(0.4), radius: 6)
        }
    }

    // MARK: - Name + title

    private var nameBlock: some View {
        VStack(spacing: 4) {
            Text(oracle.localizedName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text(oracle.localizedTitle)
                .font(.subheadline)
                .foregroundStyle(oracle.accent)
        }
    }

    // MARK: - Question

    private var questionBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("oracle.answer.your_question")
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
            Text(question)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Answer

    private var answerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.subheadline)
                    .foregroundStyle(oracle.accent.opacity(0.7))
                Text("oracle.answer.label")
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
            }

            Text(answer)
                .font(.title3.weight(.regular))
                .italic()
                .foregroundStyle(.white)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(oracle.accent.opacity(0.35), lineWidth: 1)
        )
    }
}

#Preview {
    AnswerSheet(
        oracle: Oracle.all[0],
        question: "Что меня ждёт впереди в этой непростой ситуации с работой и переездом?",
        answer: "Ветры перемен дуют в твою сторону, Евгений, и звёзды светят ярко на твоём пути, но нить судьбы, сотканная ткачами, ещё не раскрыла всех тайн. Река времени плавно течёт, и ты сам выбираешь поворот."
    )
    .environmentObject(PredictionStore())
}
