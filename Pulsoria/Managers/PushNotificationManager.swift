import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import OSLog
import UIKit
import UserNotifications

/// Handles APNs registration + Firebase Cloud Messaging token storage so
/// the Cloud Functions layer can push notifications at the user (friend
/// requests, accepted requests, room invites).
///
/// Integration checklist
/// ---------------------
/// 1. Add `FirebaseMessaging` SPM product to the Pulsoria target.
/// 2. Enable the **Push Notifications** capability in the target's
///    Signing & Capabilities tab (creates the `aps-environment`
///    entitlement).
/// 3. Upload an APNs auth key (`.p8`) in Firebase Console → Project
///    Settings → Cloud Messaging → Apple app configuration.
/// 4. Info.plist needs no additional keys — FirebaseMessaging's default
///    method swizzling wires `didRegisterForRemoteNotificationsWithDeviceToken`
///    automatically.
///
/// The client writes its FCM token to `users/{uid}.fcmToken` so the
/// server side (Cloud Functions) can fan out pushes by uid.
@MainActor
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    private var didStart = false
    private lazy var db = Firestore.firestore()

    /// Retries we spawn to grab the FCM token as APNs delivery races
    /// with our request. Cancelled en masse once any of them succeeds
    /// so the later retries don't wastefully re-query FCM.
    private var fetchRetryTasks: [Task<Void, Never>] = []
    private var tokenPersisted = false

    private override init() { super.init() }

    /// Call from `ContentView.task` (idempotent). Prompts for notification
    /// permission once, registers for remote notifications, and wires the
    /// FCM delegate so we pick up the token as soon as APNs hands it
    /// over. Also polls `Messaging.token` explicitly — without this, if
    /// the delegate was set after the first token was issued (e.g. cold
    /// start race) we'd miss it and `fcmToken` never lands in Firestore.
    func start() {
        guard !didStart else { return }
        didStart = true

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // Hop straight onto the MainActor before touching `self`. The
        // outer completion block is sendable / nonisolated; capturing
        // `self` directly there trips Swift 6's concurrency diagnostic.
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            Task { @MainActor [weak self] in
                if let error {
                    Logger.beatStore.error(
                        "Push auth request failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
                Logger.beatStore.info("Push auth granted=\(granted, privacy: .public)")
                guard granted else { return }
                UIApplication.shared.registerForRemoteNotifications()
                self?.scheduleFetchRetries()
            }
        }
    }

    /// APNs delivery is async. Rather than one immediate fetch (which
    /// almost always races APNs), try at 0s/2s/5s/10s/20s — the very
    /// first call will usually fail with "APNS device token not set"
    /// and the later ones pick up once `apnsToken` is wired. Once any
    /// attempt persists the token, `cancelRetries()` stops the rest.
    private func scheduleFetchRetries() {
        cancelRetries()
        let delays: [TimeInterval] = [0, 2, 5, 10, 20]
        fetchRetryTasks = delays.map { delay in
            Task { @MainActor [weak self] in
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                if Task.isCancelled { return }
                // If an earlier retry already landed a token, skip the
                // rest — no need to re-query FCM.
                if self?.tokenPersisted == true { return }
                self?.fetchAndPersistToken()
            }
        }
    }

    private func cancelRetries() {
        for task in fetchRetryTasks { task.cancel() }
        fetchRetryTasks.removeAll()
    }

    /// Explicit token fetch — belt-and-suspenders to the delegate. Safe
    /// to call multiple times; FCM either returns the cached token or
    /// kicks off a registration.
    private func fetchAndPersistToken() {
        Messaging.messaging().token { token, error in
            // Same dance as in `start()` — hop to the MainActor before
            // touching `self` or the logger's isolated context.
            Task { @MainActor [weak self] in
                if let error {
                    Logger.beatStore.error(
                        "FCM token fetch failed: \(error.localizedDescription, privacy: .public)"
                    )
                    return
                }
                guard let token, !token.isEmpty else {
                    Logger.beatStore.info("FCM token fetch returned empty (APNs not ready yet)")
                    return
                }
                Logger.beatStore.info("FCM token received len=\(token.count, privacy: .public)")
                self?.persist(token: token)
            }
        }
    }

    /// Writes the FCM token onto the current user's doc. Called from
    /// `MessagingDelegate`. If Firebase Auth isn't ready yet (e.g. first
    /// launch before anonymous sign-in completes) we retry after a short
    /// delay.
    fileprivate func persist(token: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            Logger.beatStore.info("FCM token buffered — no auth uid yet, retrying in 2 s")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self.persist(token: token)
            }
            return
        }
        Task { @MainActor in
            do {
                try await db.collection("users").document(uid).updateData([
                    "fcmToken": token,
                    "fcmPlatform": "ios"
                ])
                Logger.beatStore.info("FCM token persisted to users/\(uid, privacy: .public)")
                self.tokenPersisted = true
                self.cancelRetries()
            } catch {
                Logger.beatStore.error(
                    "FCM token persist failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

// MARK: - Messaging delegate

extension PushNotificationManager: @preconcurrency MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else {
            Logger.beatStore.info("MessagingDelegate called with nil token")
            return
        }
        Logger.beatStore.info("MessagingDelegate delivered token len=\(fcmToken.count, privacy: .public)")
        Task { @MainActor in
            self.persist(token: fcmToken)
        }
    }
}

// MARK: - Notification center delegate

extension PushNotificationManager: @preconcurrency UNUserNotificationCenterDelegate {
    /// Show pushes as a banner + sound + badge even when the app is in
    /// the foreground — otherwise the OS suppresses them and the user
    /// never sees the friend request / room invite.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    /// Tap handler — no deep linking yet, but we at least mark the
    /// badge as cleared so the tray doesn't carry a stale number.
    /// Uses the iOS 17+ `setBadgeCount` API; the old
    /// `applicationIconBadgeNumber` setter was deprecated and nags in
    /// the compiler.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        UNUserNotificationCenter.current().setBadgeCount(0)
        completionHandler()
    }
}
