import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct PulsoriaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
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
