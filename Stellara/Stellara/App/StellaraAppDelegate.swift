import UIKit
import Combine
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// Remote notifications (FCM): mirrors PocketInventory / Downshep setup —
/// manual APNs token handoff, topic `all`, foreground presentation.
///
/// Также служит «гейтом» для разрешённых ориентаций: по дефолту весь
/// app — портрет, но `WebShellView` на время своего показа просит .all,
/// чтобы in-app браузер мог поворачиваться. Возвращает обратно в .portrait
/// в `onDisappear`.
final class StellaraAppDelegate: NSObject,
    UIApplicationDelegate,
    UNUserNotificationCenterDelegate,
    MessagingDelegate,
    ObservableObject {

    /// Разрешённые ориентации. Меняй из view-кода через
    /// `permitOrientations(...)`, не трогай напрямую.
    var supportedOrientations: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        supportedOrientations
    }

    /// Отметить, какие ориентации сейчас разрешены. Дополнительно «дёргаем»
    /// систему, чтобы она пересмотрела текущую ориентацию (важно при
    /// возврате в портретный режим — иначе экран остаётся в ландшафте).
    func permitOrientations(_ mask: UIInterfaceOrientationMask) {
        supportedOrientations = mask
        if #available(iOS 16.0, *) {
            DispatchQueue.main.async {
                let scenes = UIApplication.shared.connectedScenes
                for case let scene as UIWindowScene in scenes {
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
                }
                UIViewController.attemptRotationToDeviceOrientation()
            }
        } else {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if DEBUG
        Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        #else
        Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Stellara][FCM] APNs registration failed:", error.localizedDescription)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, !token.isEmpty else {
            print("[Stellara][FCM] registration token is nil or empty")
            return
        }
        print("[Stellara][FCM] token:", token)
        UserDefaults.standard.set(token, forKey: "fcmToken")

        Messaging.messaging().subscribe(toTopic: "all") { error in
            if let error {
                print("[Stellara][FCM] subscribe topic 'all' error:", error.localizedDescription)
            } else {
                print("[Stellara][FCM] subscribed to topic 'all'")
            }
        }
    }
}
