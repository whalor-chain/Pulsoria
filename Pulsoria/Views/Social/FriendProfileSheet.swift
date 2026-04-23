import SwiftUI

/// Detail view for a single friend — big avatar, current track info, a
/// shortcut to join the room they're in, and a destructive remove.
/// Reacts to presence changes in real time via `FriendsManager`.
struct FriendProfileSheet: View {
    let friendID: String

    @ObservedObject var manager = FriendsManager.shared
    @ObservedObject var rooms = ListeningRoomManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isJoining = false
    @State private var joinError: String?

    /// Current snapshot — falls back to a placeholder if the friendship
    /// disappears while this sheet is open (user removed them).
    private var friend: FriendProfile? {
        manager.friends.first { $0.id == friendID }
    }

    private var presence: FriendPresence? {
        manager.presenceByFriendID[friendID]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let friend {
                    content(for: friend)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                } else {
                    ContentUnavailableView(
                        Loc.noFriendsYet,
                        systemImage: "person.slash"
                    )
                    .padding(.top, 80)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .alert(Loc.errorTitle, isPresented: Binding(
                get: { joinError != nil },
                set: { if !$0 { joinError = nil } }
            ), presenting: joinError) { _ in
                Button("OK", role: .cancel) { }
            } message: { msg in
                Text(msg)
            }
        }
    }

    @ViewBuilder
    private func content(for friend: FriendProfile) -> some View {
        VStack(spacing: 20) {
            FriendAvatarView(
                displayName: friend.displayName,
                avatarURL: friend.avatarURL,
                size: 96,
                isLive: presence?.isLive == true
            )

            VStack(spacing: 4) {
                Text(friend.displayName)
                    .font(.custom(Loc.fontBold, size: 22))
                    .lineLimit(1)
                Text(friend.friendCode)
                    .font(.custom(Loc.fontMedium, size: 13).monospaced())
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }

            if let friend = self.friend, let code = friend.currentRoomCode {
                roomCard(code: code)
            }

            nowPlayingCard

            // Emoji reactions — fire-and-forget, FriendsManager
            // attaches a track snapshot if the friend is currently live.
            ReactionBar(friendID: friendID)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Room card

    private func roomCard(code: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.and.background.dotted")
                    .foregroundStyle(theme.currentTheme.accent)
                Text(Loc.inRoomNow)
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
                Text(code)
                    .font(.custom(Loc.fontBold, size: 16).monospaced())
                    .foregroundStyle(theme.currentTheme.accent)
            }

            Button {
                joinRoom(code: code)
            } label: {
                HStack(spacing: 8) {
                    if isJoining {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    Text(Loc.joinTheirRoom)
                        .font(.custom(Loc.fontBold, size: 15))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .tint(theme.currentTheme.accent)
            .disabled(isJoining || rooms.currentRoom?.id == code)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    private func joinRoom(code: String) {
        isJoining = true
        Task {
            do {
                try await rooms.joinRoom(code: code)
                isJoining = false
                dismiss()
            } catch {
                isJoining = false
                joinError = error.localizedDescription
            }
        }
    }

    // MARK: - Now playing card

    @ViewBuilder
    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Loc.currentTrack)
                .font(.custom(Loc.fontMedium, size: 12))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)

            if let presence, !presence.trackTitle.isEmpty {
                HStack(spacing: 12) {
                    trackCover
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if presence.isLive {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                            }
                            Text(presence.trackTitle)
                                .font(.custom(Loc.fontBold, size: 16))
                                .lineLimit(1)
                        }
                        Text(presence.trackArtist)
                            .font(.custom(Loc.fontMedium, size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            } else {
                Text(Loc.notListening)
                    .font(.custom(Loc.fontMedium, size: 14))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    @ViewBuilder
    private var trackCover: some View {
        if let urlString = presence?.coverURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure, .empty:
                    coverFallback
                @unknown default:
                    coverFallback
                }
            }
        } else {
            coverFallback
        }
    }

    private var coverFallback: some View {
        LinearGradient(
            colors: [theme.currentTheme.accent.opacity(0.4), theme.currentTheme.secondary.opacity(0.25)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "music.note")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
