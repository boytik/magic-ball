import SwiftUI

/// Звёздный фон. Без зависимостей, рисуется через Canvas + TimelineView.
///
/// Параметры:
/// - `density`        — относительная плотность звёзд (1.0 — стандарт).
/// - `sparkleIntensity` — насколько резко звёзды мерцают (1.0 — обычно, 1.5–2.0 — для сплеша).
/// - `showsShootingStars` — изредка пускать падающую звезду (для красоты на загрузке).
struct StarryBackground: View {
    var density: Double = 1.0
    var sparkleIntensity: Double = 1.0
    var showsShootingStars: Bool = false

    private let stars: [Star]
    private let shootingStars: [ShootingStar]

    init(density: Double = 1.0,
         sparkleIntensity: Double = 1.0,
         showsShootingStars: Bool = false) {
        self.density = density
        self.sparkleIntensity = sparkleIntensity
        self.showsShootingStars = showsShootingStars

        let count = max(20, Int(90.0 * density))
        self.stars = (0..<count).map { _ in Star.random() }
        self.shootingStars = showsShootingStars
            ? (0..<3).map { _ in ShootingStar.random() }
            : []
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                drawStars(ctx: &ctx, size: size, time: t)

                if showsShootingStars {
                    drawShootingStars(ctx: &ctx, size: size, time: t)
                }
            }
        }
        .background(skyGradient)
        .ignoresSafeArea()
    }

    // MARK: - Stars

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, time t: TimeInterval) {
        for star in stars {
            // Плавная пульсация (от обычного дыхания звезды).
            let basePulse = 0.5 + 0.5 * sin(t * star.speed + star.phase)

            // Короткая вспышка — каждая звезда "сверкает" редко и со своим оффсетом.
            let cycle = (t + star.sparkleOffset).truncatingRemainder(dividingBy: star.sparkleInterval)
            let sparkProgress = cycle / star.sparkleInterval
            let burstWindow = 0.08 // 8% времени цикла — окно вспышки
            var burst: Double = 0
            if sparkProgress < burstWindow {
                let p = sparkProgress / burstWindow
                burst = sin(p * .pi) // 0 -> 1 -> 0
            }

            let pulse = (basePulse * (1 - 0.55 * burst)) + burst
            let intensity = min(1.0, (0.25 + 0.55 * pulse) * (1 + 0.3 * (sparkleIntensity - 1)))
            let radius = star.radius * (0.55 + 0.6 * pulse * sparkleIntensity)

            let x = star.x * size.width
            let y = star.y * size.height

            // Halo для крупных звёзд во время пика.
            if star.radius > 1.2 && burst > 0.15 {
                let haloRadius = radius * 4
                let haloRect = CGRect(x: x - haloRadius, y: y - haloRadius,
                                      width: haloRadius * 2, height: haloRadius * 2)
                ctx.fill(
                    Path(ellipseIn: haloRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.35 * burst * sparkleIntensity),
                            .clear
                        ]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: haloRadius
                    )
                )
            }

            // Само ядро звезды.
            let rect = CGRect(x: x - radius, y: y - radius,
                              width: radius * 2, height: radius * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(intensity)))

            // Лучи в пик вспышки — только для самых ярких звёзд.
            if burst > 0.35 && star.radius > 1.3 {
                let rayLength = radius * 5 * burst * sparkleIntensity
                var rayPath = Path()
                rayPath.move(to: CGPoint(x: x - rayLength, y: y))
                rayPath.addLine(to: CGPoint(x: x + rayLength, y: y))
                rayPath.move(to: CGPoint(x: x, y: y - rayLength))
                rayPath.addLine(to: CGPoint(x: x, y: y + rayLength))
                ctx.stroke(
                    rayPath,
                    with: .color(.white.opacity(burst * 0.55 * sparkleIntensity)),
                    lineWidth: 0.5
                )
            }
        }
    }

    // MARK: - Shooting stars

    private func drawShootingStars(ctx: inout GraphicsContext, size: CGSize, time t: TimeInterval) {
        for shoot in shootingStars {
            let cycle = (t + shoot.offset).truncatingRemainder(dividingBy: shoot.interval)
            let visibleFor = 1.2 // секунды
            guard cycle < visibleFor else { continue }
            let progress = cycle / visibleFor

            let startX = shoot.startX * size.width
            let startY = shoot.startY * size.height
            let dx = cos(shoot.angle) * size.width * 0.5
            let dy = sin(shoot.angle) * size.height * 0.5

            let headX = startX + dx * progress
            let headY = startY + dy * progress

            let tailLen: Double = 80
            let tailX = headX - cos(shoot.angle) * tailLen
            let tailY = headY - sin(shoot.angle) * tailLen

            // Затухающий след.
            let alpha = sin(progress * .pi) // 0->1->0
            var trail = Path()
            trail.move(to: CGPoint(x: tailX, y: tailY))
            trail.addLine(to: CGPoint(x: headX, y: headY))
            ctx.stroke(trail, with: .linearGradient(
                Gradient(colors: [.clear, .white.opacity(0.9 * alpha)]),
                startPoint: CGPoint(x: tailX, y: tailY),
                endPoint: CGPoint(x: headX, y: headY)
            ), lineWidth: 1.4)

            // Голова.
            let headRadius: Double = 1.6
            let headRect = CGRect(x: headX - headRadius, y: headY - headRadius,
                                  width: headRadius * 2, height: headRadius * 2)
            ctx.fill(Path(ellipseIn: headRect), with: .color(.white.opacity(alpha)))
        }
    }

    // MARK: - Sky

    private var skyGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.05, blue: 0.18),
                Color(red: 0.12, green: 0.08, blue: 0.28),
                Color(red: 0.04, green: 0.03, blue: 0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Models

    private struct Star {
        let x: Double
        let y: Double
        let radius: Double
        let speed: Double
        let phase: Double
        /// Период между вспышками в секундах.
        let sparkleInterval: Double
        /// Смещение, чтобы все звёзды не вспыхивали синхронно.
        let sparkleOffset: Double

        static func random() -> Star {
            Star(
                x: .random(in: 0...1),
                y: .random(in: 0...1),
                radius: .random(in: 0.5...2.0),
                speed: .random(in: 0.6...1.8),
                phase: .random(in: 0...(2 * .pi)),
                sparkleInterval: .random(in: 4.0...12.0),
                sparkleOffset: .random(in: 0...12.0)
            )
        }
    }

    private struct ShootingStar {
        let startX: Double
        let startY: Double
        let angle: Double      // в радианах
        let interval: Double   // секунды между запусками
        let offset: Double

        static func random() -> ShootingStar {
            ShootingStar(
                startX: .random(in: 0.05...0.6),
                startY: .random(in: 0...0.4),
                angle: .random(in: (.pi / 6)...(.pi / 3)), // вниз-вправо
                interval: .random(in: 8...18),
                offset: .random(in: 0...18)
            )
        }
    }
}

#Preview {
    StarryBackground(density: 1.4, sparkleIntensity: 1.8, showsShootingStars: true)
}
