import SwiftUI

struct OracleView: View {
    @EnvironmentObject private var store: PredictionStore
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var usage: UsageTracker
    @EnvironmentObject private var notifications: NotificationManager

    @State private var selectedOracle: Oracle = Oracle.all[0]
    @State private var showsLimitAlert: Bool = false
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var isLoading: Bool = false
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool

    @StateObject private var speech = SpeechRecognizer()

    /// Текст до начала записи — чтобы при стопе/ресете корректно собирать всё в textField.
    @State private var textBeforeRecording: String = ""

    /// Показывать ли шит «Три голоса».
    @State private var showsPersonasInfo: Bool = false

    /// Шит с полным ответом оракула. Открывается автоматически после успешного предсказания.
    @State private var showsAnswerSheet: Bool = false

    /// Последний заданный вопрос — нужно для отображения в шите.
    @State private var lastDeliveredQuestion: String = ""

    /// Оракул, который ответил на lastDelivered вопрос (может отличаться от выбранного).
    @State private var lastDeliveredOracle: Oracle = Oracle.all[0]

    /// Свежее предсказание для звезды-избранного в шите.
    @State private var lastDeliveredPrediction: Prediction? = nil

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

                usageIndicator

                inputArea
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
            // Плавная подстройка всего стека при росте текстового поля и появлении клавиатуры.
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: question)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: inputFocused)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: usage.usedToday)
        }
        // Кнопка «о персонах» — приклеена к правому верхнему углу экрана.
        .overlay(alignment: .topTrailing) {
            personasInfoButton
                .padding(.top, 6)
                .padding(.trailing, 16)
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
        .sheet(isPresented: $showsPersonasInfo) {
            PersonasInfoView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsAnswerSheet) {
            AnswerSheet(
                oracle: lastDeliveredOracle,
                question: lastDeliveredQuestion,
                answer: answer,
                prediction: lastDeliveredPrediction
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("usage.limit_reached.title", isPresented: $showsLimitAlert) {
            // Если разрешение ещё не запрошено — предложим включить.
            if notifications.authStatus == .notDetermined {
                Button("push.cta.enable") {
                    Task {
                        let granted = await notifications.requestAuthorization()
                        if granted {
                            notifications.scheduleLimitResetNotification()
                        }
                    }
                }
                Button("alert.cancel", role: .cancel) {}
            } else {
                Button("alert.ok", role: .cancel) {}
            }
        } message: {
            Text(String(format: NSLocalizedString("usage.limit_reached.subtitle",
                                                  comment: ""),
                        UsageTracker.dailyLimit))
        }
    }

    // MARK: - Subviews

    private var personaPicker: some View {
        // Только pill + подзаголовок — оба центрированы по умолчанию VStack.
        VStack(spacing: 6) {
            personaMenu

            Text(selectedOracle.localizedTitle)
                .font(.caption)
                .foregroundStyle(selectedOracle.accent.opacity(0.85))
                .id(selectedOracle.id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedOracle.id)
    }

    /// Кнопка-вопрос для верхнего правого угла экрана.
    private var personasInfoButton: some View {
        Button {
            showsPersonasInfo = true
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            Image(systemName: "questionmark.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("personas.info.a11y"))
    }

    /// Один pill с текущей персоной + chevron.down. Тап — системное меню.
    private var personaMenu: some View {
        Menu {
            ForEach(Oracle.all) { oracle in
                Button {
                    guard oracle.id != selectedOracle.id else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedOracle = oracle
                    }
                    #if canImport(UIKit)
                    UISelectionFeedbackGenerator().selectionChanged()
                    #endif
                } label: {
                    if oracle.id == selectedOracle.id {
                        Label(oracle.localizedName, systemImage: "checkmark")
                    } else {
                        Label(oracle.localizedName, systemImage: oracle.symbol)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedOracle.symbol)
                    .foregroundStyle(.white)
                Text(selectedOracle.localizedName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(
                Capsule().fill(selectedOracle.accent.opacity(0.35))
            )
            .overlay(
                Capsule().stroke(selectedOracle.accent, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .menuOrder(.fixed)
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
                Button {
                    showsAnswerSheet = true
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } label: {
                    VStack(spacing: 4) {
                        Text(answer)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                        Text("oracle.answer.tap_to_expand")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
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

    // MARK: - Usage indicator

    @ViewBuilder
    private var usageIndicator: some View {
        if usage.canAsk {
            // Спокойный индикатор "осталось 2 из 3" в полупрозрачном виде.
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.caption2)
                Text(String(format: NSLocalizedString("usage.remaining", comment: ""),
                            usage.remainingToday, UsageTracker.dailyLimit))
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 2)
        } else {
            // Лимит исчерпан — крупная подсказка.
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.subheadline)
                    Text("usage.limit_reached.title")
                        .font(.subheadline.weight(.semibold))
                }
                Text(String(format: NSLocalizedString("usage.limit_reached.subtitle", comment: ""),
                            UsageTracker.dailyLimit))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.vertical, 10).padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
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
        let blocked = isLoading || trimmedQuestion.count < 3 || !usage.canAsk
        return Button {
            Task { await ask() }
        } label: {
            Image(systemName: isLoading ? "hourglass" : (usage.canAsk ? "arrow.up" : "lock.fill"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Group {
                        if usage.canAsk {
                            Circle().fill(selectedOracle.accent.gradient)
                        } else {
                            Circle().fill(Color.white.opacity(0.18))
                        }
                    }
                )
                .shadow(color: usage.canAsk ? selectedOracle.accent.opacity(0.5) : .clear,
                        radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(blocked)
        .opacity(blocked ? 0.55 : 1.0)
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

        // Клиентский гард — не дёргаем сеть, если лимит уже исчерпан.
        guard usage.canAsk else {
            showsLimitAlert = true
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
            return
        }

        if speech.isRecording { speech.stop() }
        inputFocused = false
        errorText = nil
        isLoading = true
        // Optimistic-инкремент — кнопка сразу гаснет / индикатор обновляется.
        usage.registerAttempt()
        Analytics.track(.predictionRequested, ["persona": selectedOracle.id])
        defer { isLoading = false }

        do {
            let resp = try await PredictionService.shared.predict(
                question: q,
                oracle: selectedOracle,
                profile: profileStore.profile
            )
            // Сервер сказал, сколько уже потрачено — синхронизируемся точно.
            usage.syncFromServer(used: resp.usedToday)

            withAnimation(.easeOut(duration: 0.4)) { answer = resp.answer }
            let saved = Prediction(question: q, answer: resp.answer, oracleId: selectedOracle.id)
            store.add(saved)
            lastDeliveredPrediction = saved
            Analytics.track(.predictionDelivered, ["persona": selectedOracle.id,
                                                    "used_today": resp.usedToday])

            // Запомним контекст для шита (вопрос обнулится ниже, оракул может смениться).
            lastDeliveredQuestion = q
            lastDeliveredOracle   = selectedOracle
            // Чуть оттянем открытие шита, чтобы успели проиграться:
            // - анимация ответа на главном экране,
            // - тактильная feedback "успех".
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showsAnswerSheet = true
            }

            // Если только что потратил 3-е — планируем «сброс завтра» и поднимаем алерт.
            if !usage.canAsk {
                Analytics.track(.predictionLimitReached)
                notifications.scheduleLimitResetNotification()
                showsLimitAlert = true
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                question = ""
                textBeforeRecording = ""
            }
            speech.resetTranscript()

            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        } catch let err as PredictionError {
            switch err {
            case .rateLimited:
                // Бэк сказал «лимит» — фиксируем это локально.
                usage.markLimitReached()
                notifications.scheduleLimitResetNotification()
                showsLimitAlert = true
            case .badResponse, .server, .network:
                // Сервер ничего не списал — откатываем.
                usage.rollback()
            }
            Analytics.track(.predictionFailed, ["reason": String(describing: err)])
            errorText = err.localizedDescription
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        } catch {
            usage.rollback()
            Analytics.track(.predictionFailed, ["reason": "unknown"])
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
        .environmentObject(UsageTracker())
        .environmentObject(NotificationManager())
}
