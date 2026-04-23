import Foundation

/// One emoji reaction sent from one user to another, attached to the
/// recipient's currently-playing track at the moment the sender tapped.
/// Lives in Firestore under the top-level `reactions` collection.
///
/// Stored in two scenarios:
/// 1. Sent by me — created via `FriendsManager.sendReaction(...)`
/// 2. Received by me — picked up by the inbox listener and surfaced in
///    `FriendsManager.recentReactions`
struct MusicReaction: Identifiable, Equatable, Hashable {
    let id: String
    let fromUID: String
    let toUID: String
    let fromName: String
    let fromAvatarURL: String?
    /// Single emoji glyph the sender tapped — one of `Self.allowedEmojis`.
    let emoji: String
    let trackTitle: String
    let trackArtist: String
    let fileName: String
    /// Server timestamp; nil during optimistic-write window.
    let createdAt: Date?

    /// Whitelist of emojis a client may send. Server-side rules enforce
    /// the same set so a hostile client can't spam Unicode characters
    /// the UI can't render.
    static let allowedEmojis: [String] = ["🔥", "💎", "😭", "🎯", "❓"]
}
