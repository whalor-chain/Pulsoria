import Foundation
import FirebaseFirestore

// MARK: - Room

/// A live listening room — host picks a track, participants join by code and
/// hear it in lockstep. Chat lives in a `messages` subcollection.
///
/// The document ID *is* the join code (6 uppercase alphanumerics). Keeping
/// code==docID means a `joinRoom(code:)` call can go straight to
/// `collection("rooms").document(code)` without a query.
struct ListeningRoom: Identifiable, Codable, Equatable, Hashable {
    @DocumentID var id: String?
    let hostID: String
    let hostName: String
    let createdAt: Date
    var lastActivity: Date
    var playback: RoomPlaybackState
    /// Map of participantID -> display name. Kept as an embedded map (not a
    /// subcollection) because we expect ≤ 20 participants per room.
    var participants: [String: String]
}

// MARK: - Playback state

/// Authoritative playback state written by the host and mirrored by every
/// client. Clients compute their local offset from `startedAt` so all
/// players land on the same second of the track.
struct RoomPlaybackState: Codable, Equatable, Hashable {
    /// Matches the `fileName` of a `Track` in the host's library; clients use
    /// this to look up the same file in *their* library. If they don't have
    /// it, they fall back to metadata-only (title/artist are still shown).
    var trackFileName: String
    var trackTitle: String
    var trackArtist: String
    var durationSeconds: Double
    /// Server-side timestamp of when `isPlaying` last flipped to true.
    /// Clients compute `offset = now - startedAt` to know where to seek.
    /// Nil immediately after room creation, before the host hits play.
    var startedAt: Date?
    /// When paused, the offset (seconds into the track) at which the host
    /// paused. Nil while playing.
    var pausedOffset: Double?
    var isPlaying: Bool
}

// MARK: - Chat

struct RoomChatMessage: Identifiable, Codable, Equatable, Hashable {
    @DocumentID var id: String?
    let senderID: String
    let senderName: String
    let text: String
    let sentAt: Date
}

// MARK: - Code generation

enum RoomCode {
    /// Alphabet deliberately skips 0/O/1/I to reduce misreads when a user
    /// reads the code to someone else.
    private static let alphabet: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 6

    /// Random 6-char uppercase alphanumeric code, e.g. "K7X2PM".
    /// 32^6 = ~1.07B combinations — collisions are sparse but the caller
    /// should still retry on write-conflict.
    static func generate() -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    /// Validate a user-entered code: exactly `length` characters, all from
    /// the alphabet. Case-insensitive so callers don't have to uppercase.
    static func isValid(_ code: String) -> Bool {
        let trimmed = normalize(code)
        guard trimmed.count == length else { return false }
        return trimmed.allSatisfy { alphabet.contains($0) }
    }

    /// Normalize user input into the canonical on-disk form.
    /// `.whitespacesAndNewlines` — if the user pastes a code copied from
    /// Messages/WhatsApp it often carries a trailing newline.
    static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
