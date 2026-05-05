import SwiftUI
import Lottie

/// Сплеш с Lottie-анимацией кота. Показывается на старте,
/// onFinish вызывается когда анимация доиграла до конца.
struct LoadingView: View {
    var onFinish: () -> Void

    @State private var didFire = false

    var body: some View {
        ZStack {
            StarryBackground()

            VStack(spacing: 24) {
                LottieView(animation: .named("catloading"))
                    .playing(loopMode: .playOnce)
                    .animationDidFinish { _ in
                        guard !didFire else { return }
                        didFire = true
                        onFinish()
                    }
                    .frame(width: 240, height: 240)

                Text("loading.title")
                    .font(.system(size: 22, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        // Защита от случая, если onFinish не вызовется (отсутствие Lottie и т.п.)
        .task {
            try? await Task.sleep(for: .seconds(4))
            guard !didFire else { return }
            didFire = true
            onFinish()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    LoadingView(onFinish: {})
}
