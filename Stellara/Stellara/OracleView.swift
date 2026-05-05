import SwiftUI

struct OracleView: View {
    @EnvironmentObject private var store: PredictionStore

    @State private var selectedOracle: Oracle = Oracle.all[0]
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var isLoading: Bool = false
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            StarryBackground()

            VStack(spacing: 24) {
                personaPicker
                    .padding(.top, 8)

                Spacer(minLength: 0)

                ball

                answerArea
                    .frame(minHeight: 100)

                Spacer(minLength: 0)

                inputArea
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var personaPicker: some View {
        HStack(spacing: 10) {
            ForEach(Oracle.all) { oracle in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedOracle = oracle
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: oracle.symbol)
                        Text(oracle.localizedName).font(.callout)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(selectedOracle.id == oracle.id ? oracle.accent.opacity(0.35) : .white.opacity(0.06))
                    }
                    .overlay(
                        Capsule().stroke(
                            selectedOracle.id == oracle.id ? oracle.accent : .white.opacity(0.15),
                            lineWidth: 1
                        )
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ball: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [selectedOracle.accent.opacity(isLoading ? 0.6 : 0.35), .clear],
                        center: .center, startRadius: 60, endRadius: 200
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 20)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            selectedOracle.accent.opacity(0.9),
                            Color.black.opacity(0.95),
                        ],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 10, endRadius: 200
                    )
                )
                .frame(width: 220, height: 220)
                .overlay(
                    Circle().stroke(
                        LinearGradient(colors: [.white.opacity(0.3), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.2
                    )
                )
                .shadow(color: selectedOracle.accent.opacity(0.6), radius: 30)

            Image(systemName: selectedOracle.symbol)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .white.opacity(0.6), radius: 8)
        }
        .scaleEffect(isLoading ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isLoading)
        .onTapGesture { Task { await ask() } }
    }

    private var answerArea: some View {
        Group {
            if let errorText {
                Text(errorText)
                    .foregroundStyle(.orange.opacity(0.9))
                    .multilineTextAlignment(.center)
            } else if !answer.isEmpty {
                Text(answer)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text(emptyHint)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 4)
        .animation(.easeInOut(duration: 0.4), value: answer)
    }

    /// Локализованная подсказка с подстановкой имени оракула.
    private var emptyHint: String {
        String(format: NSLocalizedString("oracle.empty_hint", comment: ""),
               selectedOracle.localizedName)
    }

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("oracle.input.placeholder", text: $question, axis: .vertical)
                .lineLimit(1...3)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .foregroundStyle(.white)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { Task { await ask() } }

            Button {
                Task { await ask() }
            } label: {
                Image(systemName: isLoading ? "hourglass" : "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(selectedOracle.accent.gradient, in: Circle())
            }
            .disabled(isLoading || question.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
        }
    }

    // MARK: - Actions

    private func ask() async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 3, !isLoading else { return }
        inputFocused = false
        errorText = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await PredictionService.shared.predict(question: q, oracle: selectedOracle)
            withAnimation(.easeOut(duration: 0.4)) { answer = resp.answer }

            store.add(Prediction(question: q, answer: resp.answer, oracleId: selectedOracle.id))

            question = ""

            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        } catch {
            errorText = error.localizedDescription
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        }
    }
}

#Preview {
    OracleView()
        .environmentObject(PredictionStore())
}
