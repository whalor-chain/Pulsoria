import SwiftUI
import CoreHaptics

struct SplashView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showWaves = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var wavePhase: CGFloat = 0
    @State private var isFinished = false
    @State private var hapticEngine: CHHapticEngine?

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Animated gradient background
            RadialGradient(
                colors: [
                    theme.currentTheme.accent.opacity(showLogo ? 0.3 : 0),
                    theme.currentTheme.secondary.opacity(showLogo ? 0.15 : 0),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: showLogo ? 400 : 0
            )
            .ignoresSafeArea()
            .animation(.easeOut(duration: 1.2), value: showLogo)

            VStack(spacing: 0) {
                Spacer()

                // Logo
                ZStack {
                    // Pulse rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                theme.currentTheme.accent.opacity(showLogo ? 0.15 - Double(i) * 0.04 : 0),
                                lineWidth: 1.5
                            )
                            .frame(
                                width: showLogo ? CGFloat(180 + i * 40) : 60,
                                height: showLogo ? CGFloat(180 + i * 40) : 60
                            )
                            .scaleEffect(pulseScale + CGFloat(i) * 0.03)
                    }
                    .animation(.easeOut(duration: 1.0).delay(0.3), value: showLogo)

                    // Logo image
                    Image("NotLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(color: theme.currentTheme.accent.opacity(0.5), radius: 30, y: 8)
                        .scaleEffect(showLogo ? 1.0 : 0.3)
                        .opacity(showLogo ? 1.0 : 0)
                }

                // Full logo
                Image("FullLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 70)
                    .opacity(showTitle ? 1.0 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .padding(.top, 24)

                Spacer()
                Spacer()
            }
        }
        .opacity(isFinished ? 0 : 1)
        .scaleEffect(isFinished ? 1.1 : 1.0)
        .task {
            // Step 1: Show logo
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                showLogo = true
            }

            // Haptic after logo appears
            try? await Task.sleep(for: .milliseconds(300))
            playPulseHaptic() // was: playRisingHaptic()

            // Step 2: Show title
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.5)) {
                showTitle = true
            }

            // Step 3: Show waves
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeOut(duration: 0.6)) {
                showWaves = true
            }

            // Step 4: Pulse animation
            startPulse()

            // Step 5: Finish after delay
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeInOut(duration: 0.4)) {
                isFinished = true
            }

            try? await Task.sleep(for: .milliseconds(400))
            onFinished()
        }
    }

    // MARK: - Waveform Bars

    private var waveformBars: some View {
        HStack(spacing: 4) {
            ForEach(0..<24, id: \.self) { i in
                let normalizedIndex = CGFloat(i) / 23.0
                let distance = abs(normalizedIndex - 0.5) * 2.0
                let baseHeight: CGFloat = 8 + (1.0 - distance) * 40
                let animatedHeight = baseHeight * (showWaves ? 1.0 : 0.2)

                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.currentTheme.accent.opacity(0.6),
                                theme.currentTheme.secondary.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 5, height: animatedHeight)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .delay(Double(i) * 0.03),
                        value: showWaves
                    )
            }
        }
    }

    // MARK: - Pulse

    private func startPulse() {
        withAnimation(
            .easeInOut(duration: 0.8)
                .repeatCount(3, autoreverses: true)
        ) {
            pulseScale = 1.06
        }
    }

    // MARK: - Pulse Haptic (heartbeat style)

    private func playPulseHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.stoppedHandler = { [weak engine] _ in
                engine?.stop()
            }
            engine.resetHandler = { [weak engine] in
                try? engine?.start()
            }
            try engine.start()
            self.hapticEngine = engine

            var events: [CHHapticEvent] = []

            let pulses: [(time: Double, intensity: Float, sharpness: Float)] = [
                (0.0,   1.0, 0.2),
                (0.22,  0.7, 0.1),
                (0.75,  1.0, 0.2),
                (0.97,  0.7, 0.1),
                (1.5,   1.0, 0.2),
                (1.72,  0.7, 0.1),
            ]

            for pulse in pulses {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: pulse.intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: pulse.sharpness)
                    ],
                    relativeTime: pulse.time
                ))
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: pulse.intensity * 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: pulse.sharpness * 0.5)
                    ],
                    relativeTime: pulse.time + 0.05,
                    duration: 0.15
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)

            // Stop engine after haptic completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                hapticEngine?.stop()
                hapticEngine = nil
            }
        } catch {
            // Haptics not available
        }
    }
}
