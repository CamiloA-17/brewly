import BrewlyDomain
import BrewlyFeatures
import UIKit
import UserNotifications

/// Registro de notificaciones push (APNs).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var dependencies: AppDependencies? {
        didSet { requestPushAuthorization() }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    private func requestPushAuthorization() {
        Task { @MainActor in
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        // Se guarda para que `SessionStore` lo registre cuando haya sesión iniciada.
        UserDefaults.standard.set(token, forKey: SessionStore.pushTokenDefaultsKey)
        Task { try? await dependencies?.notifications.registerPushToken(token) }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }
}
