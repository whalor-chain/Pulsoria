import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import OSLog

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Firebase requires GoogleService-Info.plist in the app bundle.
        // It is gitignored, so CI builds / fresh clones won't have it —
        // skip configuration in that case so the test host can still boot.
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
            // Firestore rules require `request.auth != null` for every write
            // into `beats` and `rooms`. Apple Sign-In gives us an identity
            // for the UI, but the Firestore backend only trusts Firebase Auth,
            // so we pair every install with an anonymous Firebase session.
            if Auth.auth().currentUser == nil {
                Auth.auth().signInAnonymously(completion: nil)
            }
        }
        return true
    }

    // MARK: - APNs → FCM bridge
    //
    // FirebaseMessaging's method swizzling *should* handle these for us,
    // but swizzling occasionally misses on certain Xcode / SDK combos —
    // implementing them explicitly removes the ambiguity and lets us see
    // in logs exactly when (or whether) APNs hands us a token.

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Logger.beatStore.info("APNs token received bytes=\(deviceToken.count, privacy: .public)")
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.beatStore.error(
            "APNs registration failed: \(error.localizedDescription, privacy: .public)"
        )
    }
}

@main
struct PulsoriaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage(UserDefaultsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var auth = AuthManager.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(0)
                } else if !auth.isSignedIn {
                    SignInView()
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            )
                        )
                        .zIndex(0)
                } else {
                    ContentView()
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 1.05).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                        .zIndex(0)
                }

                if showSplash {
                    SplashView {
                        showSplash = false
                        SharedImportState.splashFinished = true
                        if SharedImportState.pending {
                            SharedImportState.pending = false
                            NotificationCenter.default.post(name: .sharedAudioImport, object: nil)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(.smooth(duration: 0.7), value: hasCompletedOnboarding)
            .animation(.smooth(duration: 0.7), value: auth.isSignedIn)
            .tint(theme.currentTheme.accent)
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                if url.scheme == "pulsoria" && url.host == "import" {
                    if SharedImportState.splashFinished {
                        NotificationCenter.default.post(name: .sharedAudioImport, object: nil)
                    } else {
                        SharedImportState.pending = true
                    }
                } else if url.scheme == "pulsoria" && url.host == "ton-connect" {
                    TonWalletManager.shared.handleReturnURL()
                }
            }
        }
    }
}

enum SharedImportState {
    static var pending = false
    static var splashFinished = false
}

extension Notification.Name {
    static let sharedAudioImport = Notification.Name("sharedAudioImport")
}
