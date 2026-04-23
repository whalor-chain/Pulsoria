import Combine
import SwiftUI

/// Identifiable wrapper around a friend's UID so `.sheet(item:)` can
/// drive the profile sheet. Keeping the raw uid optional in state keeps
/// the binding simpler than stashing a whole `FriendProfile`.
private struct FriendID: Identifiable, Hashable {
    let id: String
}

/// Lists the user's friends with live now-playing info and exposes their
/// own shareable code at the top. Add-friend + incoming-requests actions
/// live in the navigation toolbar (inherited from the parent tab).
struct FriendsListView: View {
    /// Owned by `SocialHubView` so the toolbar items defining these
    /// flags can live in the parent's body — that lets them animate
    /// with the picker's `withAnimation` context instead of iOS's
    /// default unanimated swap on view mount/unmount.
    @Binding var showAddFriend: Bool
    @Binding var showRequests: Bool

    @ObservedObject var manager = FriendsManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var selectedFriendID: String?

    /// Memoized "live-first, then alphabetic" view of the friends list.
    /// Recomputed only when the underlying data changes (via `.onChange`
    /// hooks) rather than on every body rebuild — friend-presence
    /// snapshots fire several Hz, sort cost was showing up in Instruments.
    @State private var sortedFriendsCache: [FriendProfile] = []

    /// Ticks once every 30 s so the "X min ago" labels stay current
    /// without needing a per-row timer.
    @State private var tickDate = Date()
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if manager.friends.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    friendsList
                        .padding(.top, 12)
                }
            }
            .padding(.bottom, 40)
        }
        .sheet(item: Binding(
            get: { selectedFriendID.map { FriendID(id: $0) } },
            set: { selectedFriendID = $0?.id }
        )) { wrapped in
            FriendProfileSheet(friendID: wrapped.id)
        }
        .onReceive(tick) { date in tickDate = date }
        .onAppear {
            sortedFriendsCache = makeSortedFriends(manager.friends, presence: manager.presenceByFriendID)
        }
        .onChange(of: manager.friends) { _, friends in
            sortedFriendsCache = makeSortedFriends(friends, presence: manager.presenceByFriendID)
        }
        // Re-sort when *live* status changes. We drop the full presence
        // dict into the key via live-uid set so we don't resort on
        // track-title-only changes (which are 4 Hz).
        .onChange(of: liveFriendIDs(from: manager.presenceByFriendID)) { _, _ in
            sortedFriendsCache = makeSortedFriends(manager.friends, presence: manager.presenceByFriendID)
        }
    }

    // MARK: - Friends list

    /// Set of uids that are currently live — derived key used to trigger
    /// a re-sort only when someone goes live / stops being live, not on
    /// every presence tick (title / progress updates).
    private func liveFriendIDs(from presence: [String: FriendPresence]) -> Set<String> {
        Set(presence.compactMap { $0.value.isLive ? $0.key : nil })
    }

    /// Pure sort helper — live friends float to the top, everyone else
    /// alphabetic. Runs only when `.onChange` below fires, never during
    /// regular body rebuilds.
    private func makeSortedFriends(
        _ friends: [FriendProfile],
        presence: [String: FriendPresence]
    ) -> [FriendProfile] {
        friends.sorted { a, b in
            let aLive = presence[a.id]?.isLive ?? false
            let bLive = presence[b.id]?.isLive ?? false
            if aLive != bLive { return aLive }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    private var friendsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(sortedFriendsCache) { friend in
                Button {
                    selectedFriendID = friend.id
                } label: {
                    FriendRowView(
                        friend: friend,
                        presence: manager.presenceByFriendID[friend.id],
                        referenceDate: tickDate
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
        .padding(.top, 4)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: sortedFriendsCache.map(\.id))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(Loc.noFriendsYet)
                .font(.custom(Loc.fontBold, size: 17))
            Text(Loc.noFriendsHint)
                .font(.custom(Loc.fontMedium, size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Avatar view (reused by rows)

/// Round avatar that prefers a remote URL and falls back to colored
/// initials so rows never render "blank". When `isLive` is true the
/// avatar wears a pulsating green ring — the "they're listening right
/// now" signal, visually echoing Instagram's stories ring.
struct FriendAvatarView: View {
    let displayName: String
    let avatarURL: String?
    var size: CGFloat = 44
    var isLive: Bool = false

    @ObservedObject var theme = ThemeManager.shared

    var body: some View {
        ZStack {
            if isLive {
                livePulseRing
            }
            Group {
                if let urlString = avatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure, .empty:
                            initialsCircle
                        @unknown default:
                            initialsCircle
                        }
                    }
                } else {
                    initialsCircle
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            // Small inset when ringed so the ring sits tightly around
            // the avatar instead of clipping the edge.
            .padding(isLive ? 3 : 0)
        }
        .frame(width: size + (isLive ? 8 : 0), height: size + (isLive ? 8 : 0))
    }

    /// Pulsating green ring. Animation is purely client-side (no
    /// Firestore reads) — a 1.2 s sine-ish breathe based on a continuous
    /// `TimelineView` clock.
    private var livePulseRing: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            // Breathe between 0.55 and 1.0 brightness + small scale pulse.
            let t = (sin(seconds * 2 * .pi / 1.2) + 1) / 2 // 0...1
            let brightness = 0.55 + t * 0.45
            let scale = 1.0 + t * 0.05
            ZStack {
                Circle()
                    .strokeBorder(
                        Color.green.opacity(brightness),
                        lineWidth: 2
                    )
                Circle()
                    .strokeBorder(
                        Color.green.opacity(0.3 * t),
                        lineWidth: 6
                    )
                    .blur(radius: 4)
            }
            .scaleEffect(scale)
        }
    }

    private var initialsCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [theme.currentTheme.accent.opacity(0.55), theme.currentTheme.secondary.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text(initials)
                    .font(.custom(Loc.fontBold, size: max(11, size * 0.36)))
                    .foregroundStyle(.white)
            }
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first.map { String($0.prefix(1)) } ?? ""
        let second = parts.dropFirst().first.map { String($0.prefix(1)) } ?? ""
        let combo = (first + second).uppercased()
        return combo.isEmpty ? "?" : combo
    }
}

// MARK: - Friend row

struct FriendRowView: View {
    let friend: FriendProfile
    let presence: FriendPresence?
    let referenceDate: Date

    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var manager = FriendsManager.shared
    @State private var showRemoveConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatarView(
                displayName: friend.displayName,
                avatarURL: friend.avatarURL,
                size: 44,
                isLive: presence?.isLive == true
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(presence?.isLive == true ? Color.green : Color.secondary.opacity(0.45))
                        .frame(width: 6, height: 6)
                    Text(friend.displayName)
                        .font(.custom(Loc.fontBold, size: 15))
                        .lineLimit(1)
                }
                statusLine
            }

            Spacer()

            if let presence, !presence.trackTitle.isEmpty {
                trackCover(for: presence)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            if presence?.isLive == true {
                liveBadge
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .contextMenu {
            Button(role: .destructive) {
                showRemoveConfirm = true
            } label: {
                Label(Loc.removeFriend, systemImage: "person.fill.xmark")
            }
        }
        .alert(Loc.removeFriend, isPresented: $showRemoveConfirm) {
            Button(Loc.cancel, role: .cancel) { }
            Button(Loc.removeFriend, role: .destructive) {
                Task { try? await manager.removeFriend(friend.id) }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let presence, !presence.trackTitle.isEmpty {
            if presence.isLive {
                Text("\(presence.trackTitle) — \(presence.trackArtist)")
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(theme.currentTheme.accent)
                    .lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(presence.trackTitle) — \(presence.trackArtist)")
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(Loc.lastListened.lowercased()) · \(relativeTime(for: presence.lastSeen))")
                        .font(.custom(Loc.fontMedium, size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        } else {
            Text(Loc.offlineStatus)
                .font(.custom(Loc.fontMedium, size: 12))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func trackCover(for presence: FriendPresence) -> some View {
        if let urlString = presence.coverURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    coverPlaceholder
                @unknown default:
                    coverPlaceholder
                }
            }
        } else {
            coverPlaceholder
        }
    }

    private var coverPlaceholder: some View {
        LinearGradient(
            colors: [theme.currentTheme.accent.opacity(0.35), theme.currentTheme.secondary.opacity(0.25)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "music.note")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text(Loc.liveNow)
                .font(.custom(Loc.fontBold, size: 10))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.green.opacity(0.15)))
    }

    private func relativeTime(for date: Date?) -> String {
        switch FriendPresence.relativeBucket(for: date, now: referenceDate) {
        case .none: return Loc.offlineStatus.lowercased()
        case .justNow: return Loc.justNow
        case .minutes(let n): return "\(n) \(Loc.minutesAgoSuffix)"
        case .hours(let n): return "\(n) \(Loc.hoursAgoSuffix)"
        case .days(let n): return "\(n) \(Loc.daysAgoSuffix)"
        }
    }
}

// MARK: - Incoming request row

struct IncomingRequestRow: View {
    let request: FriendRequest
    @ObservedObject var manager = FriendsManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var isSubmitting = false

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatarView(
                displayName: request.fromName,
                avatarURL: request.fromAvatarURL,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromName)
                    .font(.custom(Loc.fontBold, size: 15))
                    .lineLimit(1)
                Text(Loc.wantsToBeFriend)
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    act { try await manager.declineRequest(request) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.red.opacity(0.15)))
                }
                .disabled(isSubmitting)

                Button {
                    act { try await manager.acceptRequest(request) }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(theme.currentTheme.accent))
                }
                .disabled(isSubmitting)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    private func act(_ work: @escaping () async throws -> Void) {
        isSubmitting = true
        Task {
            try? await work()
            isSubmitting = false
        }
    }
}

// MARK: - Outgoing (pending) row

struct OutgoingRequestRow: View {
    let request: FriendRequest
    @ObservedObject var manager = FriendsManager.shared
    @ObservedObject var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatarView(
                displayName: request.toName,
                avatarURL: request.toAvatarURL,
                size: 44
            )
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "hourglass")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Circle().fill(Color.orange))
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(request.toName)
                    .font(.custom(Loc.fontBold, size: 15))
                    .lineLimit(1)
                Text(Loc.pendingOutgoing)
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task { try? await manager.cancelOutgoing(request) }
            } label: {
                Text(Loc.cancel)
                    .font(.custom(Loc.fontMedium, size: 13))
            }
            .buttonStyle(.glass)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }
}
