import SwiftUI

/// Шит «Три голоса» — объясняет, чем отличаются Зефира, Мадам Лу и Космо.
struct PersonasInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                StarryBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        header
                            .padding(.top, 4)

                        ForEach(Oracle.all) { oracle in
                            PersonaCard(oracle: oracle)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("personas.title")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text("personas.intro")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }
}

// MARK: - Persona card

private struct PersonaCard: View {
    let oracle: Oracle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Text(oracle.localizedDescription)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            specialtiesSection
            samplesSection
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(oracle.accent.opacity(0.35), lineWidth: 1)
        )
    }

    // Шапка: аватар + имя + tone-line
    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [oracle.accent.opacity(0.95), oracle.accent.opacity(0.35), .clear],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 4, endRadius: 36
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: oracle.accent.opacity(0.55), radius: 10)

                Image(systemName: oracle.symbol)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(oracle.localizedName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(oracle.localizedTitle)
                    .font(.subheadline)
                    .foregroundStyle(oracle.accent)
            }

            Spacer(minLength: 0)
        }
    }

    // Чипы со специализациями + tone-фраза.
    private var specialtiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(text: NSLocalizedString("personas.section.specialties", comment: ""))
            FlowLayout(spacing: 6) {
                ForEach(oracle.localizedSpecialties, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(oracle.accent.opacity(0.22))
                        )
                        .overlay(
                            Capsule()
                                .stroke(oracle.accent.opacity(0.45), lineWidth: 0.8)
                        )
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(oracle.accent)
                Text(oracle.localizedTone)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 2)
        }
    }

    // Примеры вопросов.
    private var samplesSection: some View {
        let samples = oracle.localizedSampleQuestions
        return Group {
            if !samples.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(text: NSLocalizedString("personas.section.samples", comment: ""))
                    ForEach(samples, id: \.self) { sample in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "quote.opening")
                                .font(.caption2)
                                .foregroundStyle(oracle.accent.opacity(0.7))
                                .padding(.top, 3)
                            Text(sample)
                                .font(.callout.italic())
                                .foregroundStyle(.white.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func sectionLabel(text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(.white.opacity(0.45))
    }
}

// MARK: - Wrapping layout for chips

/// Простой flow-layout для чипов: переносит элементы на следующую строку.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    PersonasInfoView()
}
