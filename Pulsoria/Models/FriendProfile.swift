import Foundation

/// A friend you've added by their short `friendCode`. Decoded loosely from
/// their `users/{uid}` doc — only the fields we need for the list UI.
struct FriendProfile: Identifiable, Equatable, Hashable {
    /// Firebase Auth UID — doubles as the `users` doc id.
    let id: String
    let displayName: String
    let friendCode: String
    /// Firebase Storage download URL for the friend's avatar, or nil if
    /// they haven't uploaded one yet.
    let avatarURL: String?
    /// Room code the friend is currently hosting or listening in, or nil
    /// if they're not in a live room. Written by the friend's own client
    /// when they create/join/leave a room; powers the "Join their room"
    /// shortcut in the profile sheet.
    let currentRoomCode: String?
}

/// An incoming (or outgoing) friend request, decoded from a
/// `friendRequests/{from}_{to}` doc. Carries enough cached fields to
/// render either-side rows without a second fetch on the other user doc.
struct FriendRequest: Identifiable, Equatable, Hashable {
    /// Firestore doc id — `"{from}_{to}"`.
    let id: String
    let fromUID: String
    let toUID: String
    let fromName: String
    let fromCode: String
    let fromAvatarURL: String?
    let toName: String
    let toAvatarURL: String?
    let createdAt: Date?
}

/// Live "what is this friend listening to right now" snapshot, pulled
/// from their `users/{uid}.nowPlaying` map + `lastSeen` field.
struct FriendPresence: Equatable, Hashable {
    let trackTitle: String
    let trackArtist: String
    let fileName: String
    /// Server time when the friend hit play on this track. We show a
    /// "X min ago" label relative to `Date()`.
    let startedAt: Date?
    let isPlaying: Bool
    /// Last time the friend's client wrote anything — used to decide if
    /// they're still around or the presence is stale.
    let lastSeen: Date?
    /// Firebase Storage URL for the track's cover art. The friend's
    /// client uploads it the first time a given fileName is played; nil
    /// if the artwork hadn't loaded yet or the track has no embedded art.
    var coverURL: String? = nil

    /// Freshness window for "Live" status. Beyond this, we treat the
    /// friend as offline even if the raw bits say `isPlaying: true`
    /// (their phone probably dropped without sending a pause).
    /// Set to ~3 × the friend's heartbeat interval so a single missed
    /// keep-alive (poor network blip) doesn't flip the indicator off.
    static let liveWindow: TimeInterval = 150 // 2.5 min

    var isLive: Bool {
        isLive(now: Date())
    }

    /// Variant that takes an explicit `now` — useful for tests so they
    /// don't depend on real wall-clock time.
    func isLive(now: Date) -> Bool {
        guard isPlaying, let lastSeen else { return false }
        return now.timeIntervalSince(lastSeen) < Self.liveWindow
    }
}

// MARK: - Relative time bucketing

/// Structured "X ago" breakdown — language-agnostic and pure, so it can
/// be unit-tested without touching `Loc` (which is MainActor-isolated).
/// The view layer turns the enum into a localized string via
/// `FriendPresence.relativeTime(for:now:)`.
enum RelativeTimeBucket: Equatable {
    case none          // date is nil
    case justNow       // < 60 s
    case minutes(Int)  // 1 … 59 min
    case hours(Int)    // 1 … 23 h
    case days(Int)     // ≥ 1 d
}

extension FriendPresence {
    /// Classifies how long ago `date` was relative to `now`. Pure.
    ///
    /// Boundaries follow the UI spec: 59 s → `justNow`, 60 s → `minutes(1)`,
    /// 59 min → `minutes(59)`, 60 min → `hours(1)`, 23 h → `hours(23)`,
    /// 24 h → `days(1)`.
    static func relativeBucket(for date: Date?, now: Date) -> RelativeTimeBucket {
        guard let date else { return .none }
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return .justNow }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return .minutes(minutes) }
        let hours = minutes / 60
        if hours < 24 { return .hours(hours) }
        return .days(hours / 24)
    }
}
