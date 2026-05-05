import SwiftUI

struct OracleView: View {
    @EnvironmentObject private var store: PredictionStore
    @EnvironmentObject private var profileStore: UserProfileStore

    @State private var selectedOracle: Oracle = Oracle.all[0]
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var isLoading: Bool = false
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool

    @StateObject private var speech = SpeechRecognizer()

    /// Текст до начала записи — чтобы при стопе/ресете корректно собирать всё в textField.
    @State private var textBeforeRecording: String = ""

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasText: Bool { !trimmedQuestion.isEmpty }

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
            // Плавная подстройка всего стека при росте текстового поля и появлении клавиатуры.
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: question)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: inputFocused)
        }
        .preferredColorScheme(.dark)
        // Подкладываем partial-распознавание прямо в текстовое поле.
        .onChange(of: speech.transcript) { newValue in
            guard speech.isRecording else { return }
            let prefix = textBeforeRecording.isEmpty
                ? ""
                : textBeforeRecording + (textBeforeRecording.hasSuffix(" ") ? "" : " ")
            withAnimation(.easeOut(duration: 0.18)) {
                question = prefix + newValue
            }
        }
        .onChange(of: speech.errorMessage) { msg in
            if let msg, !msg.isEmpty { errorText = msg }
        }
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

    // MARK: - Input area (как в ChatGPT)

    private var inputArea: some View {
        // ZStack даёт TextField возможность свободно расти вверх,
        // а кнопка остаётся "приклеена" к нижнему правому углу.
        ZStack(alignment: .bottomTrailing) {
            TextField("oracle.input.placeholder", text: $question, axis: .vertical)
                .lineLimit(1...6)                  // авто-рост, как в ChatGPT
                .textInputAutocapitalization(.sentences)
                .font(.body)
                .foregroundStyle(.white)
                .tint(selectedOracle.accent)
                .padding(.leading, 16)
                .padding(.trailing, 52)            // оставляем место под кнопку
                .padding(.vertical, 12)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { Task { await ask() } }

            trailingButton
                .padding(.trailing, 6)
                .padding(.bottom, 6)
        }
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(inputFocused ? selectedOracle.accent.opacity(0.6) : .white.opacity(0.15), lineWidth: 1)
        )
        // Лёгкий рост при фокусе.
        .scaleEffect(inputFocused ? 1.0 : 0.995)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: inputFocused)
    }

    @ViewBuilder
    private var trailingButton: some View {
        // Свопаемся между микрофоном и кнопкой отправки с плавной кросс-фейд анимацией.
        ZStack {
            if hasText {
                sendButton
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.6).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            } else {
                micButton
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.6).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hasText)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: speech.isRecording)
    }

    private var sendButton: some View {
        Button {
            Task { await ask() }
        } label: {
            Image(systemName: isLoading ? "hourglass" : "arrow.up")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(selectedOracle.accent.gradient, in: Circle())
                .shadow(color: selectedOracle.accent.opacity(0.5), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isLoading || trimmedQuestion.count < 3)
        .opacity(trimmedQuestion.count < 3 ? 0.55 : 1.0)
    }

    private var micButton: some View {
        Button {
            toggleRecording()
        } label: {
            Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(speech.isRecording
                              ? AnyShapeStyle(Color.red.gradient)
                              : AnyShapeStyle(Color.white.opacity(0.18)))
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(speech.isRecording ? 0.0 : 0.25), lineWidth: 1)
                )
                .scaleEffect(speech.isRecording ? 1.08 : 1.0)
                .shadow(color: speech.isRecording ? .red.opacity(0.55) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("oracle.mic.a11y"))
    }

    // MARK: - Actions

    private func toggleRecording() {
        if speech.isRecording {
            speech.stop()
        } else {
            // Запоминаем то, что пользователь уже напечатал — допишем к этому partial-результат.
            textBeforeRecording = question
            inputFocused = false
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            speech.start()
        }
    }

    private func ask() async {
        let q = trimmedQuestion
        guard q.count >= 3, !isLoading else { return }
        if speech.isRecording { speech.stop() }
        inputFocused = false
        errorText = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await PredictionService.shared.predict(
                question: q,
                oracle: selectedOracle,
                profile: profileStore.profile
            )
            withAnimation(.easeOut(duration: 0.4)) { answer = resp.answer }

            store.add(Prediction(question: q, answer: resp.answer, oracleId: selectedOracle.id))

            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                question = ""
                textBeforeRecording = ""
            }
            speech.resetTranscript()

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
        .environmentObject(UserProfileStore())
}
