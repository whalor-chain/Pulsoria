import SwiftUI

/// Five-emoji row that lets you fire a reaction at a friend.
/// Reactions go through whether or not the friend is currently live —
/// `FriendsManager` attaches whatever track snapshot it has (or empty
/// strings) so the recipient still sees who reacted.
///
/// Each tap is rate-limited inside `FriendsManager.sendReaction(...)`
/// (~1.5s per friend), so a stuck-finger user just gets the haptic
/// feedback without flooding Firestore. UI confirmation: a brief
/// scale-bounce on the tapped emoji + ripple of the same glyph
/// floating up over the bar for ~0.8s.
struct ReactionBar: View {
    let friendID: String

    @State private var floaters: [Floater] = []
    @State private var pressedEmoji: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Loc.reactToTrack)
                .font(.custom(Loc.fontMedium, size: 12))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)

            HStack(spacing: 8) {
                ForEach(MusicReaction.allowedEmojis, id: \.self) { emoji in
                    Button {
                        send(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle().fill(.ultraThinMaterial)
                            )
                            .scaleEffect(pressedEmoji == emoji ? 1.25 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: pressedEmoji)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Loc.reactToTrack) \(emoji)")
                }

                Spacer(minLength: 0)
            }
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(floaters) { floater in
                        Text(floater.emoji)
                            .font(.system(size: 28))
                            .offset(x: floater.startX, y: floater.yOffset)
                            .opacity(floater.opacity)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: pressedEmoji)
    }

    // MARK: - Send

    private func send(_ emoji: String) {
        pressedEmoji = emoji
        spawnFloater(for: emoji)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            pressedEmoji = nil
        }
        Task {
            _ = await FriendsManager.shared.sendReaction(toFriendID: friendID, emoji: emoji)
        }
    }

    private func spawnFloater(for emoji: String) {
        let index = MusicReaction.allowedEmojis.firstIndex(of: emoji) ?? 0
        let x = CGFloat(index) * (44 + 8) + 8
        let id = UUID()
        floaters.append(Floater(id: id, emoji: emoji, startX: x, yOffset: 0, opacity: 1))

        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.8)) {
                if let idx = floaters.firstIndex(where: { $0.id == id }) {
                    floaters[idx].yOffset = -60
                    floaters[idx].opacity = 0
                }
            }
            try? await Task.sleep(nanoseconds: 850_000_000)
            floaters.removeAll { $0.id == id }
        }
    }

    private struct Floater: Identifiable, Equatable {
        let id: UUID
        let emoji: String
        var startX: CGFloat
        var yOffset: CGFloat
        var opacity: Double
    }
}
