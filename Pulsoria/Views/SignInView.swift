import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @ObservedObject var auth = AuthManager.shared
    @ObservedObject var theme = ThemeManager.shared

    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 40
    @State private var buttonOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var gradientAngle: Double = 0

    var body: some View {
        ZStack {
            // Animated background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Rotating gradient orbs
            ZStack {
                Circle()
                    .fill(theme.currentTheme.accent.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(
                        x: 100 * cos(gradientAngle),
                        y: 100 * sin(gradientAngle)
                    )

                Circle()
                    .fill(theme.currentTheme.secondary.opacity(0.15))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(
                        x: -80 * cos(gradientAngle + 2),
                        y: -80 * sin(gradientAngle + 1.5)
                    )

                Circle()
                    .fill(theme.currentTheme.accent.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .blur(radius: 60)
                    .offset(
                        x: 60 * sin(gradientAngle + 1),
                        y: 120 * cos(gradientAngle + 0.5)
                    )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo with pulse
                ZStack {
                    // Pulse rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                theme.currentTheme.accent.opacity(0.15 - Double(i) * 0.04),
                                lineWidth: 1.5
                            )
                            .frame(
                                width: 140 + CGFloat(i) * 30,
                                height: 140 + CGFloat(i) * 30
                            )
                            .scaleEffect(pulseScale + CGFloat(i) * 0.05)
                    }

                    Image("NotLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(color: theme.currentTheme.accent.opacity(0.5), radius: 30, y: 10)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Image("FullLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 56)
                    .padding(.top, 24)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Text(Loc.signInSlogan)
                    .font(.custom(Loc.fontBold, size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                theme.currentTheme.accent,
                                theme.currentTheme.secondary
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Spacer()

                // Sign in with Apple button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    auth.handleAuthorization(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(Capsule())
                .shadow(color: .white.opacity(0.08), radius: 20)
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .offset(y: buttonOffset)
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            // Logo entrance
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            // Title entrance
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                titleOffset = 0
                titleOpacity = 1.0
            }

            // Button entrance
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                buttonOffset = 0
                buttonOpacity = 1.0
            }

            // Pulse animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }

            // Gradient orbs rotation
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                gradientAngle = .pi * 2
            }
        }
    }
}
