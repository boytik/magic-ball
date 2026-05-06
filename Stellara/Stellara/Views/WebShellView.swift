import SwiftUI
import Combine
import WebKit
import UIKit

/// In-app браузер для Privacy Policy / Terms из Adapty онбординга.
///
/// Архитектурно скопирован с Second/WebShellView, упрощён под наш кейс.
///
/// Что важно:
///  • `geo.safeAreaInsets` после `.ignoresSafeArea()` отдаёт мусор. Поэтому
///    реальные safe-area-insets читаем напрямую из `UIWindow` через
///    `WindowInsetVault` + `InsetWatcher` (UIView-backed).
///  • На стороне нотча — чёрная полоса (top safe area под Dynamic Island,
///    либо боковая в ландшафте). Контент в эту зону не лезет.
///  • Нав-бар на противоположной стороне (портрет → снизу, ландшафт →
///    напротив выреза). На устройствах без нотча — снизу.
///  • На время показа разрешаем все ориентации через
///    `StellaraAppDelegate.permitOrientations(.all)` и возвращаем `.portrait`
///    при закрытии.
///  • До загрузки в WKWebView дёргаем headless URLSession-probe по цепочке
///    кандидатов (saved finalURL → baseURL+pathId → baseURL). Первый
///    HTTP-200…403 идёт в WebView. Это копия логики Second:
///    `reconcileStoredRemote → stitchTokenIntoDraft → fallback`.
///  • Финальный URL (после всех редиректов в WebView) пишется в
///    `WebRecoveryStore`. pathId выдёргивается из его query.
struct WebShellView: View {

    let baseURL: URL
    var onDismiss: () -> Void
    /// Опционально: вызывается, если это первый вход (нет сохранённой
    /// финальной ссылки) и НИ ОДИН кандидат не пробился. Hosting view
    /// (AdaptyOnboardingHost) использует это, чтобы тихо закрыть онбординг
    /// и пометить его пройденным — пользователь не должен застрять на
    /// бесполезном экране.
    var onUnopenable: (() -> Void)? = nil

    @EnvironmentObject private var appDelegate: StellaraAppDelegate

    @StateObject private var pilot = WebPilot()
    @StateObject private var insets = WindowInsetVault()

    /// Готовый URL для WebView. nil → пока пробиваем кандидатов.
    @State private var resolvedURL: URL?
    @State private var orientationToken: UUID = UUID()
    /// Чтобы не зациклить fallback в самом WebView (после успешной пробы он всё
    /// же может упасть из-за каких-то 4xx уже внутри WKWebView).
    @State private var didTryRescue = false

    init(baseURL: URL,
         onDismiss: @escaping () -> Void,
         onUnopenable: (() -> Void)? = nil) {
        self.baseURL = baseURL
        self.onDismiss = onDismiss
        self.onUnopenable = onUnopenable
        print("[WebShell] init base=\(baseURL.absoluteString)")
        print("[WebShell] init saved finalURL=\(WebRecoveryStore.shared.finalURL?.absoluteString ?? "nil"), pathId=\(WebRecoveryStore.shared.pathId ?? "nil")")
    }

    var body: some View {
        ZStack {
            // Внешний фон = цвет рейла. Тогда зона под home-indicator (или сбоку
            // там, где не дотягиваются наши явные блоки) визуально сливается
            // с нав-баром — ничего «висящего» под панелью не видно.
            Self.railSurface.ignoresSafeArea()

            GeometryReader { geo in
                shell(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()

            // Невидимый watcher — пишет в insets.edges реальные insets окна.
            InsetWatcher(vault: insets)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea() // и сам ZStack тоже расширяем
        .id(orientationToken)
        .task {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            appDelegate.permitOrientations(.all)
            insets.refresh()
            await resolveURL()
        }
        .onDisappear {
            appDelegate.permitOrientations(.portrait)
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // Окно иногда отдаёт обновлённые safeAreaInsets с задержкой.
            // Опрашиваем несколько раз, чтобы поймать актуальные значения.
            insets.refresh()
            orientationToken = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                insets.refresh()
                orientationToken = UUID()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                insets.refresh()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Shell layout

    /// Layout строится по реальным `insets.edges` из окна, НЕ из GeometryProxy.
    /// Сторона нотча определяется по insets, с fallback'ом на UIDevice.orientation
    /// (insets иногда отстают на 1-2 кадра от реальной ориентации).
    @ViewBuilder
    private func shell(width: CGFloat, height: CGFloat) -> some View {
        let edges      = insets.edges
        let isPortrait = height >= width
        let notchSide  = resolveNotchSide(edges: edges, isPortrait: isPortrait)

        // Лог пригодится, если что-то пойдёт не так с layout.
        let _: Void = {
            print("[WebShell] shell w=\(Int(width)) h=\(Int(height)) edges(top=\(edges.top), left=\(edges.left), right=\(edges.right), bottom=\(edges.bottom)) → notch=\(notchSide)")
        }()

        switch notchSide {
        case .top:
            VStack(spacing: 0) {
                // Чёрная полоса под нотчем (top safe area).
                Color.black
                    .frame(height: edges.top)
                    .frame(maxWidth: .infinity)
                webContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Нав-бар; его фон — railSurface; зона ниже (home-indicator)
                // тоже railSurface за счёт outer-фона → визуально единая панель.
                navBarHorizontal
            }

        case .left:
            HStack(spacing: 0) {
                Color.black
                    .frame(width: edges.left)
                    .frame(maxHeight: .infinity)
                webContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                navBarVertical
            }

        case .right:
            HStack(spacing: 0) {
                navBarVertical
                webContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Color.black
                    .frame(width: edges.right)
                    .frame(maxHeight: .infinity)
            }

        case .none:
            // iPad / устройство без выреза — нав-бар снизу.
            VStack(spacing: 0) {
                webContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                navBarHorizontal
            }
        }
    }

    private enum NotchSide { case top, left, right, none }

    private func resolveNotchSide(edges: UIEdgeInsets, isPortrait: Bool) -> NotchSide {
        // В портрете нотч всегда сверху (а на устройствах без нотча `edges.top`
        // просто маленький → чёрная полоса будет тонкая, тоже ок).
        if isPortrait { return .top }
        // Primary: реальные insets из окна.
        let bias: CGFloat = 0.5
        if edges.left  > edges.right + bias { return .left }
        if edges.right > edges.left  + bias { return .right }
        // Fallback: device orientation.
        switch UIDevice.current.orientation {
        case .landscapeLeft:  return .left   // device.landscapeLeft = home button on right, notch on left
        case .landscapeRight: return .right
        default: break
        }
        // Совсем нет данных (iPad / face-up): нав-бар снизу.
        return .none
    }

    // MARK: - URL resolution (cascading probe)

    /// Цепочка кандидатов: saved → base+pathId → base.
    /// Первый, отдавший 200…403 на headless probe, идёт в WebView.
    ///
    /// Если ничего не пробилось:
    ///  • первый вход (saved == nil) → зовём `onUnopenable` (хост закроет нас
    ///    и пометит онбординг пройденным — иначе юзер застрянет);
    ///  • повторный вход (есть saved) → всё равно открываем base в WebView,
    ///    хоть что-то пользователю показать.
    private func resolveURL() async {
        let saved        = WebRecoveryStore.shared.finalURL
        let isFirstEntry = (saved == nil)
        let withPid      = WebRecoveryStore.shared.fallbackURL(forBase: baseURL)

        var seen = Set<String>()
        let candidates: [URL] = [saved, withPid, baseURL]
            .compactMap { $0 }
            .filter { url in seen.insert(url.absoluteString).inserted }

        for candidate in candidates {
            print("[WebShell] probing \(candidate.absoluteString)")
            if await ProbeService.isReachable(candidate) {
                print("[WebShell] probe OK → loading \(candidate.absoluteString)")
                if candidate.absoluteString != saved?.absoluteString {
                    WebRecoveryStore.shared.resetFinalURL()
                }
                await MainActor.run { resolvedURL = candidate }
                return
            }
            print("[WebShell] probe FAIL on \(candidate.absoluteString)")
        }

        // Все кандидаты упали.
        if isFirstEntry, let onUnopenable {
            print("[WebShell] all probes failed on first entry → finishing onboarding")
            await MainActor.run { onUnopenable() }
        } else {
            print("[WebShell] all probes failed → opening base anyway")
            await MainActor.run { resolvedURL = baseURL }
        }
    }

    // MARK: - Web

    private var webContent: some View {
        Group {
            if let url = resolvedURL {
                WebSurface(
                    url: url,
                    pilot: pilot,
                    onFinalURL: { final in
                        print("[WebShell] final loaded: \(final.absoluteString)")
                        WebRecoveryStore.shared.captureFinal(final)
                        if let saved = WebRecoveryStore.shared.finalURL?.absoluteString {
                            print("[WebShell] saved finalURL=\(saved), pathId=\(WebRecoveryStore.shared.pathId ?? "nil")")
                        }
                    },
                    onFailure: {
                        print("[WebShell] FAILURE inside WKWebView on \(url.absoluteString)")
                        guard !didTryRescue else { return }
                        didTryRescue = true
                        let rescue = WebRecoveryStore.shared.fallbackURL(forBase: baseURL)
                        if rescue.absoluteString != url.absoluteString {
                            print("[WebShell] rescue → \(rescue.absoluteString)")
                            WebRecoveryStore.shared.resetFinalURL()
                            resolvedURL = rescue
                        }
                    }
                )
                .id(url.absoluteString)
            } else {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Nav bar

    private static let railThickness: CGFloat = 56
    private static let railSurface = Color(red: 0.07, green: 0.05, blue: 0.16)

    /// Горизонтальный рейл (портрет / iPad). Фиксированная высота,
    /// без extra-padding'а — зона под home-indicator визуально продолжается
    /// outer-фоном того же цвета.
    private var navBarHorizontal: some View {
        HStack(spacing: 0) {
            ForEach(navButtons) { btn in
                navButton(btn).frame(maxWidth: .infinity)
            }
        }
        .frame(height: Self.railThickness)
        .background(Self.railSurface)
    }

    /// Вертикальный рейл (ландшафт). Растягивается на всю высоту экрана.
    private var navBarVertical: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ForEach(navButtons) { btn in
                navButton(btn).frame(maxHeight: 64)
            }
            Spacer(minLength: 0)
        }
        .frame(width: Self.railThickness)
        .frame(maxHeight: .infinity)
        .background(Self.railSurface)
    }

    private func navButton(_ btn: NavButtonModel) -> some View {
        Button(action: btn.action) {
            Image(systemName: btn.symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .disabled(!btn.enabled)
        .foregroundColor(btn.tint)
        .buttonStyle(.plain)
    }

    private var navButtons: [NavButtonModel] {
        let active = Color.white
        let muted  = Color.white.opacity(0.30)
        let veryMuted = Color.white.opacity(0.18) // для крестика — самый блёклый

        return [
            NavButtonModel(id: "back",    symbol: "chevron.backward",
                           enabled: pilot.canGoBack,
                           tint: pilot.canGoBack ? active : muted)    { pilot.goBack() },
            NavButtonModel(id: "forward", symbol: "chevron.forward",
                           enabled: pilot.canGoForward,
                           tint: pilot.canGoForward ? active : muted) { pilot.goForward() },
            NavButtonModel(id: "reload",  symbol: "arrow.clockwise",
                           enabled: true, tint: active)               { pilot.reload() },
            NavButtonModel(id: "home",    symbol: "house.fill",
                           enabled: true, tint: active)               { goHome() },
            NavButtonModel(id: "close",   symbol: "xmark",
                           enabled: true, tint: veryMuted)            { onDismiss() }
        ]
    }

    private func goHome() {
        let target = WebRecoveryStore.shared.finalURL ?? baseURL
        print("[WebShell] home → \(target.absoluteString)")
        if target.absoluteString != resolvedURL?.absoluteString {
            resolvedURL = target
        } else {
            pilot.load(target)
        }
    }
}

// MARK: - Models

private struct NavButtonModel: Identifiable {
    let id: String
    let symbol: String
    let enabled: Bool
    let tint: Color
    let action: () -> Void
}

// MARK: - Window inset vault (читает реальные insets из UIWindow)

@MainActor
final class WindowInsetVault: ObservableObject {
    @Published private(set) var edges: UIEdgeInsets = .zero

    func ingest(_ window: UIWindow) {
        let live = window.safeAreaInsets
        if !Self.almostEqual(edges, live) { edges = live }
    }

    func refresh() {
        guard let window = Self.activeWindow() else { return }
        ingest(window)
    }

    static func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let prime = scenes.first(where: {
            $0.activationState == .foregroundActive && $0.windows.contains(where: \.isKeyWindow)
        })
        let scene = prime ?? scenes.first(where: { $0.windows.contains(where: \.isKeyWindow) }) ?? scenes.first
        return scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first
    }

    private static func almostEqual(_ a: UIEdgeInsets, _ b: UIEdgeInsets) -> Bool {
        let tol: CGFloat = 0.25
        return abs(a.top - b.top) < tol
            && abs(a.left - b.left) < tol
            && abs(a.bottom - b.bottom) < tol
            && abs(a.right - b.right) < tol
    }
}

// MARK: - Inset watcher (UIView-backed, потому что SwiftUI безнадёжно врёт после ignoresSafeArea)

private struct InsetWatcher: UIViewRepresentable {
    let vault: WindowInsetVault

    func makeUIView(context: Context) -> Probe {
        let probe = Probe()
        probe.deliver = { [weak vault] window in
            guard let vault else { return }
            Task { @MainActor in vault.ingest(window) }
        }
        return probe
    }

    func updateUIView(_ probe: Probe, context: Context) {
        probe.deliver = { [weak vault] window in
            guard let vault else { return }
            Task { @MainActor in vault.ingest(window) }
        }
        probe.setNeedsLayout()
    }

    final class Probe: UIView {
        var deliver: ((UIWindow) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window { deliver?(window) }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let window { deliver?(window) }
        }
    }
}

// MARK: - Pilot

@MainActor
final class WebPilot: ObservableObject {
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    weak var webView: WKWebView?

    func sync() {
        guard let webView else { return }
        if canGoBack    != webView.canGoBack    { canGoBack    = webView.canGoBack }
        if canGoForward != webView.canGoForward { canGoForward = webView.canGoForward }
    }

    func goBack()    { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload()    { webView?.reload() }

    func load(_ url: URL) {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        webView?.load(request)
    }
}

// MARK: - Headless probe

private enum ProbeService {
    /// HEAD/GET с короткими таймаутами. Считаем «доступным» статусы 200…403:
    /// 401/403 значат «страница есть, просто требует авторизации» — нам ок.
    static func isReachable(_ url: URL, timeout: TimeInterval = 5.0) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = timeout
        cfg.timeoutIntervalForResource = timeout + 1
        cfg.waitsForConnectivity = false
        cfg.urlCache = nil
        let session = URLSession(configuration: cfg)
        defer { session.invalidateAndCancel() }
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...403).contains(http.statusCode)
        } catch {
            return false
        }
    }
}

// MARK: - WKWebView wrapper

private struct WebSurface: UIViewRepresentable {

    let url: URL
    let pilot: WebPilot
    let onFinalURL: (URL) -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinalURL: onFinalURL, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true

        let view = WKWebView(frame: .zero, configuration: cfg)
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.backgroundColor = .black
        view.isOpaque = false
        view.scrollView.backgroundColor = .black
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator

        context.coordinator.attach(view: view, pilot: pilot)
        print("[WebShell] open: \(url.absoluteString)")
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onFinalURL = onFinalURL
        context.coordinator.onFailure  = onFailure
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var onFinalURL: (URL) -> Void
        var onFailure: () -> Void

        private weak var view: WKWebView?
        private weak var pilot: WebPilot?
        private var observations: [NSKeyValueObservation] = []
        private var didCaptureFinalForCurrentLoad = false

        init(onFinalURL: @escaping (URL) -> Void, onFailure: @escaping () -> Void) {
            self.onFinalURL = onFinalURL
            self.onFailure = onFailure
        }

        func attach(view: WKWebView, pilot: WebPilot) {
            self.view = view
            self.pilot = pilot
            pilot.webView = view
            installObservers(on: view)
        }

        func detach() {
            observations.forEach { $0.invalidate() }
            observations.removeAll()
        }

        private func installObservers(on view: WKWebView) {
            let trigger: (Any, Any) -> Void = { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.pilot?.sync() }
            }
            observations = [
                view.observe(\.canGoBack,    options: [.new, .initial], changeHandler: trigger),
                view.observe(\.canGoForward, options: [.new, .initial], changeHandler: trigger),
                view.observe(\.url,          options: [.new],            changeHandler: trigger)
            ]
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url, ["http","https"].contains(url.scheme?.lowercased()) else { return }
            if !didCaptureFinalForCurrentLoad {
                didCaptureFinalForCurrentLoad = true
                onFinalURL(url)
            }
            Task { @MainActor in pilot?.sync() }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleFailure(error)
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            handleFailure(error)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.isForMainFrame,
               let http = navigationResponse.response as? HTTPURLResponse,
               (404...599).contains(http.statusCode) {
                decisionHandler(.cancel)
                onFailure()
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        private func handleFailure(_ error: Error) {
            let ns = error as NSError
            guard ns.code != NSURLErrorCancelled else { return }
            onFailure()
        }
    }
}
