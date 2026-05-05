import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: PredictionStore

    @State private var mode: Mode = .calendar
    @State private var visibleMonth: Date = Date()
    @State private var selectedDate: Date? = nil

    /// Поисковый запрос в режиме «Все».
    @State private var searchText: String = ""

    /// Запись, по которой пользователь тапнул — открывает AnswerSheet.
    @State private var openedPrediction: Prediction? = nil

    /// Подтверждение удаления.
    @State private var pendingDelete: Prediction? = nil

    private let calendar = Calendar.current

    enum Mode: String, CaseIterable, Identifiable {
        case calendar
        case list
        case favorites
        var id: String { rawValue }
    }

    /// Группировка предсказаний по началу дня — для маркеров в календаре и фильтра.
    private var predictionsByDay: [Date: [Prediction]] {
        Dictionary(grouping: store.predictions) { p in
            calendar.startOfDay(for: p.createdAt)
        }
    }

    private var filteredPredictions: [Prediction] {
        guard let selectedDate else { return store.predictions }
        let day = calendar.startOfDay(for: selectedDate)
        return predictionsByDay[day] ?? []
    }

    /// Список для режима «Все»: фильтруем по поиску по вопросу и ответу.
    private var searchedPredictions: [Prediction] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.predictions }
        return store.predictions.filter {
            $0.question.lowercased().contains(q) ||
            $0.answer.lowercased().contains(q)
        }
    }

    /// Только избранное + поиск (если в режиме favorites используется тот же search field).
    private var favoritePredictions: [Prediction] {
        let favs = store.predictions.filter { $0.isFavorite }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return favs }
        return favs.filter {
            $0.question.lowercased().contains(q) ||
            $0.answer.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            StarryBackground()

            if store.predictions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    modePicker
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                    switch mode {
                    case .calendar:  calendarMode
                    case .list:      listMode
                    case .favorites: favoritesMode
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("tab.history")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $openedPrediction) { p in
            AnswerSheet(
                oracle: Oracle.by(id: p.oracleId),
                question: p.question,
                answer: p.answer,
                prediction: p
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "history.delete.confirm",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { p in
            Button("history.delete.action", role: .destructive) {
                deletePrediction(p)
            }
            Button("alert.cancel", role: .cancel) { }
        } message: { p in
            Text(p.question)
        }
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        Picker("", selection: $mode) {
            Text("history.mode.calendar").tag(Mode.calendar)
            Text("history.mode.list").tag(Mode.list)
            Image(systemName: "star.fill").tag(Mode.favorites)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Calendar mode

    @ViewBuilder
    private var calendarMode: some View {
        HistoryCalendar(
            visibleMonth: $visibleMonth,
            selectedDate: $selectedDate,
            predictionsByDay: predictionsByDay
        )
        .padding(.horizontal, 16)

        selectedDayHeader

        list(for: filteredPredictions, emptyKey: "history.empty.day")
    }

    // MARK: - List mode

    @ViewBuilder
    private var listMode: some View {
        list(for: searchedPredictions, emptyKey: "history.empty.search")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("history.search.placeholder")
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }

    // MARK: - Favorites mode

    @ViewBuilder
    private var favoritesMode: some View {
        list(for: favoritePredictions, emptyKey: "history.empty.favorites")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: Text("history.search.placeholder")
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }

    // MARK: - Sub-views

    private var emptyState: some View {
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
    }

    @ViewBuilder
    private var selectedDayHeader: some View {
        if let selectedDate {
            HStack {
                Text(selectedDate, format: .dateTime.day().month(.wide).year())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        self.selectedDate = nil
                    }
                } label: {
                    Label("history.show_all", systemImage: "xmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private func list(for items: [Prediction], emptyKey: LocalizedStringKey) -> some View {
        if items.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.35))
                Text(emptyKey)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        } else {
            List {
                ForEach(items) { p in
                    predictionRow(p)
                }
                .onDelete { offsets in
                    deleteFromList(items: items, offsets: offsets)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
        }
    }

    private func predictionRow(_ p: Prediction) -> some View {
        let oracle = Oracle.by(id: p.oracleId)
        return Button {
            openedPrediction = p
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            HStack(spacing: 12) {
                // Маленький круглый аватар оракула.
                ZStack {
                    Circle()
                        .fill(oracle.accent.opacity(0.22))
                        .frame(width: 34, height: 34)
                    Image(systemName: oracle.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(oracle.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(oracle.localizedName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        if p.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                        Spacer(minLength: 4)
                        Text(p.createdAt, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Text(p.question)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.white.opacity(0.05))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                store.toggleFavorite(p)
            } label: {
                Label(
                    p.isFavorite ? "history.unfavorite" : "history.favorite",
                    systemImage: p.isFavorite ? "star.slash.fill" : "star.fill"
                )
            }
            .tint(.yellow)
        }
        .contextMenu {
            Button {
                store.toggleFavorite(p)
            } label: {
                Label(
                    p.isFavorite ? "history.unfavorite" : "history.favorite",
                    systemImage: p.isFavorite ? "star.slash" : "star"
                )
            }
            Button(role: .destructive) {
                pendingDelete = p
            } label: {
                Label("history.delete.action", systemImage: "trash")
            }
        }
    }

    // MARK: - Delete helpers

    /// Удаление через свайп или onDelete. Мапим индексы обратно в реальный массив.
    private func deleteFromList(items: [Prediction], offsets: IndexSet) {
        let idsToDelete = offsets.map { items[$0].id }
        let realOffsets = IndexSet(idsToDelete.compactMap { id in
            store.predictions.firstIndex(where: { $0.id == id })
        })
        store.delete(at: realOffsets)
    }

    private func deletePrediction(_ p: Prediction) {
        guard let idx = store.predictions.firstIndex(where: { $0.id == p.id }) else { return }
        store.delete(at: IndexSet(integer: idx))
    }
}

// MARK: - Calendar

struct HistoryCalendar: View {
    @Binding var visibleMonth: Date
    @Binding var selectedDate: Date?
    let predictionsByDay: [Date: [Prediction]]

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayRow
            daysGrid
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    // Шапка: месяц + стрелки.
    private var header: some View {
        HStack {
            chevronButton(direction: -1, system: "chevron.left", a11y: "history.calendar.prev")
            Spacer()
            Text(monthLabel)
                .font(.headline)
                .foregroundStyle(.white)
                .id(monthLabel)
                .transition(.opacity)
            Spacer()
            chevronButton(direction: 1, system: "chevron.right", a11y: "history.calendar.next")
        }
    }

    private func chevronButton(direction: Int, system: String, a11y: LocalizedStringKey) -> some View {
        Button {
            if let new = calendar.date(byAdding: .month, value: direction, to: visibleMonth) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    visibleMonth = new
                }
            }
        } label: {
            Image(systemName: system)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(a11y))
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return f.string(from: visibleMonth).capitalized(with: Locale.current)
    }

    // Заголовок: Пн Вт Ср ...
    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols.indices, id: \.self) { i in
                Text(weekdaySymbols[i])
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        // Сдвигаем так, чтобы первый день недели был в начале (например Пн в России).
        let firstIndex = calendar.firstWeekday - 1
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    // Сетка дней.
    private var daysGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                switch cell {
                case .empty:
                    Color.clear.frame(height: 38)
                case .day(let date):
                    dayCell(date)
                }
            }
        }
    }

    /// Ячейки месяца + ведущие пустые до первого дня недели.
    private var cells: [Cell] {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let firstOfMonth = interval.start
        let daysInMonth = calendar.range(of: .day, in: .month, for: visibleMonth)?.count ?? 30

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth) // 1...7
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var result: [Cell] = []
        result.append(contentsOf: Array(repeating: Cell.empty, count: leading))
        for i in 0..<daysInMonth {
            if let d = calendar.date(byAdding: .day, value: i, to: firstOfMonth) {
                result.append(.day(d))
            }
        }
        return result
    }

    enum Cell { case empty, day(Date) }

    private func dayCell(_ date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)
        let preds = predictionsByDay[day] ?? []
        let hasPreds = !preds.isEmpty
        let dotColor = preds.first.map { Oracle.by(id: $0.oracleId).accent } ?? .purple

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                if isSelected {
                    selectedDate = nil
                } else if hasPreds {
                    selectedDate = day
                }
            }
            #if canImport(UIKit)
            if hasPreds {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            #endif
        } label: {
            ZStack {
                // Фон выбранного дня.
                Circle()
                    .fill(isSelected ? Color.purple.opacity(0.85) : .clear)
                    .frame(width: 32, height: 32)

                // Кольцо для "сегодня", если не выбран.
                if isToday && !isSelected {
                    Circle()
                        .stroke(.white.opacity(0.5), lineWidth: 1)
                        .frame(width: 32, height: 32)
                }

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.callout.weight(isToday ? .bold : .regular))
                        .foregroundStyle(textColor(isSelected: isSelected, hasPreds: hasPreds))

                    Circle()
                        .fill(hasPreds ? dotColor : .clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasPreds && !isSelected)
        .opacity(hasPreds || isToday ? 1.0 : 0.45)
    }

    private func textColor(isSelected: Bool, hasPreds: Bool) -> Color {
        if isSelected { return .white }
        if hasPreds   { return .white }
        return .white.opacity(0.55)
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .environmentObject(PredictionStore())
}
