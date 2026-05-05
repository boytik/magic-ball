import SwiftUI

/// Звёздный фон. Лёгкий, без зависимостей.
struct StarryBackground: View {
    @State private var twinkle: Double = 0

    private let stars: [Star] = (0..<80).map { _ in Star.random() }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for star in stars {
                    let pulse = 0.5 + 0.5 * sin(t * star.speed + star.phase)
                    let radius = star.radius * (0.6 + 0.4 * pulse)
                    let x = star.x * size.width
                    let y = star.y * size.height
                    let rect = CGRect(x: x - radius, y: y - radius,
                                      width: radius * 2, height: radius * 2)
                    let path = Path(ellipseIn: rect)
                    ctx.fill(path, with: .color(.white.opacity(0.25 + 0.55 * pulse)))
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.05, blue: 0.18),
                    Color(red: 0.12, green: 0.08, blue: 0.28),
                    Color(red: 0.04, green: 0.03, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .ignoresSafeArea()
    }

    private struct Star {
        let x: Double
        let y: Double
        let radius: Double
        let speed: Double
        let phase: Double

        static func random() -> Star {
            Star(
                x: .random(in: 0...1),
                y: .random(in: 0...1),
                radius: .random(in: 0.5...1.8),
                speed: .random(in: 0.6...1.8),
                phase: .random(in: 0...(2 * .pi))
            )
        }
    }
}

#Preview {
    StarryBackground()
}
