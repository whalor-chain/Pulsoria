import Combine
import FirebaseCore
import FirebaseFirestore
import Foundation
import OSLog

/// Coordinates live listening rooms: creating, joining, leaving, keeping
/// playback in sync with the host, and streaming chat messages.
///
/// Synchronization model
/// ---------------------
/// The host is authoritative. When the host hits play, it writes
/// `startedAt = FieldValue.serverTimestamp()` and `isPlaying = true` onto
/// the room document. Every client subscribed to that doc computes
///
///     offset = Date().timeIntervalSince1970 - startedAt.timeIntervalSince1970
///
/// and seeks its local `AudioPlayerManager` to that offset on the matching
/// track. When the host pauses, it writes `pausedOffset` and clears
/// `startedAt`; clients seek there and pause.
///
/// Clients that do not own the same track (matched by `fileName`) still
/// subscribe to the metadata and chat — they just don't produce audio.
/// Chat works regardless.
@MainActor
final class ListeningRoomManager: ObservableObject {
    static let shared = ListeningRoomManager()

    // MARK: - Published state

    @Published private(set) var currentRoom: ListeningRoom?
    @Published private(set) var messages: [RoomChatMessage] = []
    @Published private(set) var isHost: Bool = false
    @Published private(set) var connectionError: String?

    // MARK: - Firebase (lazy, same pattern as BeatStoreManager)

    private lazy var db = Firestore.firestore()
    private var isFirebaseReady: Bool { FirebaseApp.app() != nil }

    // MARK: - Listeners

    private var roomListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?

    // MARK: - Sync state

    /// Last playback state we applied locally, so we don't re-seek on every
    /// snapshot if nothing relevant changed.
    private var lastAppliedPlayback: RoomPlaybackState?

    private init() {}

    // MARK: - Create

    /// Creates a new room for `track` with `self` as host. Returns the join
    /// code. Retries up to 3 times on the unlikely event of a code collision.
    func createRoom(for track: Track) async throws -> String {
        guard isFirebaseReady else {
            throw RoomError.firebaseUnavailable
        }
        let auth = AuthManager.shared
        let hostID = auth.appleUserID.isEmpty ? "anon-\(UUID().uuidString.prefix(6))" : auth.appleUserID
        let hostName = auth.userName.isEmpty ? "Host" : auth.userName

        let playback = RoomPlaybackState(
            trackFileName: track.fileName,
            trackTitle: track.title,
            trackArtist: track.artist,
            durationSeconds: 0, // Filled in by host when playback starts.
            startedAt: nil,
            pausedOffset: 0,
            isPlaying: false
        )

        var attempt = 0
        while attempt < 3 {
            let code = RoomCode.generate()
            let ref = db.collection("rooms").document(code)
            do {
                // `create` semantics: fail if the doc exists. Simulated via
                // a transaction that errors out on pre-existing data.
                let created = try await db.runTransaction { tx, errorPtr in
                    let snap: DocumentSnapshot
                    do {
                        snap = try tx.getDocument(ref)
                    } catch {
                        errorPtr?.pointee = error as NSError
                        return false
                    }
                    if snap.exists {
                        errorPtr?.pointee = NSError(domain: "RoomExists", code: 1)
                        return false
                    }
                    let room = ListeningRoom(
                        id: nil,
                        hostID: hostID,
                        hostName: hostName,
                        createdAt: Date(),
                        lastActivity: Date(),
                        playback: playback,
                        participants: [hostID: hostName]
                    )
                    do {
                        try tx.setData(from: room, forDocument: ref)
                    } catch {
                        errorPtr?.pointee = error as NSError
                        return false
                    }
                    return true
                }
                if (created as? Bool) == true {
                    isHost = true
                    subscribe(to: code)
                    return code
                }
            } catch {
                // Collision or transient — retry.
                Logger.beatStore.debug("Room create attempt \(attempt) failed: \(error.localizedDescription, privacy: .public)")
            }
            attempt += 1
        }
        throw RoomError.codeCollision
    }

    // MARK: - Join

    func joinRoom(code rawCode: String) async throws {
        guard isFirebaseReady else { throw RoomError.firebaseUnavailable }
        let code = RoomCode.normalize(rawCode)
        guard RoomCode.isValid(code) else { throw RoomError.invalidCode }

        let auth = AuthManager.shared
        let userID = auth.appleUserID.isEmpty ? "anon-\(UUID().uuidString.prefix(6))" : auth.appleUserID
        let displayName = auth.userName.isEmpty ? "Listener" : auth.userName

        let ref = db.collection("rooms").document(code)
        let snap = try await ref.getDocument()
        guard snap.exists else { throw RoomError.roomNotFound }

        try await ref.updateData([
            "participants.\(userID)": displayName,
            "lastActivity": FieldValue.serverTimestamp()
        ])
        isHost = false
        subscribe(to: code)
    }

    // MARK: - Leave

    func leaveRoom() {
        guard let code = currentRoom?.id else {
            teardown()
            return
        }
        let userID = AuthManager.shared.appleUserID

        if isHost {
            // Host leaving ends the room for everyone.
            Task { [weak self] in
                try? await self?.db.collection("rooms").document(code).delete()
                await MainActor.run { self?.teardown() }
            }
        } else {
            let field = "participants.\(userID)"
            Task { [weak self] in
                try? await self?.db.collection("rooms").document(code).updateData([
                    field: FieldValue.delete(),
                    "lastActivity": FieldValue.serverTimestamp()
                ])
                await MainActor.run { self?.teardown() }
            }
        }
    }

    private func teardown() {
        roomListener?.remove()
        messagesListener?.remove()
        roomListener = nil
        messagesListener = nil
        currentRoom = nil
        messages = []
        isHost = false
        lastAppliedPlayback = nil
        connectionError = nil
    }

    // MARK: - Subscribe

    private func subscribe(to code: String) {
        roomListener?.remove()
        messagesListener?.remove()

        let ref = db.collection("rooms").document(code)
        roomListener = ref.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.connectionError = error.localizedDescription
                    return
                }
                guard let snapshot, snapshot.exists else {
                    // Host deleted the room — eject.
                    self.teardown()
                    return
                }
                if let room = try? snapshot.data(as: ListeningRoom.self) {
                    self.currentRoom = room
                    self.applyPlaybackIfNeeded(room.playback)
                }
            }
        }

        messagesListener = ref.collection("messages")
            .order(by: "sentAt", descending: false)
            .limit(toLast: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, let snapshot else { return }
                    self.messages = snapshot.documents.compactMap { doc in
                        try? doc.data(as: RoomChatMessage.self)
                    }
                }
            }
    }

    // MARK: - Host controls

    /// Host: start or resume playback from the given offset.
    func hostPlay(offset: TimeInterval, duration: TimeInterval) async throws {
        try await updatePlayback([
            "playback.startedAt": FieldValue.serverTimestamp(),
            "playback.pausedOffset": offset,
            "playback.isPlaying": true,
            "playback.durationSeconds": duration,
            "lastActivity": FieldValue.serverTimestamp()
        ])
    }

    /// Host: pause at the given offset.
    func hostPause(at offset: TimeInterval) async throws {
        try await updatePlayback([
            "playback.startedAt": NSNull(),
            "playback.pausedOffset": offset,
            "playback.isPlaying": false,
            "lastActivity": FieldValue.serverTimestamp()
        ])
    }

    /// Host: switch to a different track and start from the beginning.
    func hostSwitchTrack(to track: Track) async throws {
        try await updatePlayback([
            "playback.trackFileName": track.fileName,
            "playback.trackTitle": track.title,
            "playback.trackArtist": track.artist,
            "playback.startedAt": FieldValue.serverTimestamp(),
            "playback.pausedOffset": 0,
            "playback.isPlaying": true,
            "playback.durationSeconds": 0,
            "lastActivity": FieldValue.serverTimestamp()
        ])
    }

    private func updatePlayback(_ fields: [String: Any]) async throws {
        guard isHost, let code = currentRoom?.id else { return }
        try await db.collection("rooms").document(code).updateData(fields)
    }

    // MARK: - Chat

    func sendMessage(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let code = currentRoom?.id else { return }
        let auth = AuthManager.shared
        let userID = auth.appleUserID.isEmpty ? "anon-\(UUID().uuidString.prefix(6))" : auth.appleUserID
        let displayName = auth.userName.isEmpty ? "Listener" : auth.userName

        let message = RoomChatMessage(
            id: nil,
            senderID: userID,
            senderName: displayName,
            text: trimmed,
            sentAt: Date()
        )
        let ref = db.collection("rooms").document(code).collection("messages").document()
        try ref.setData(from: message)
    }

    // MARK: - Playback sync

    /// Given the latest playback state from Firestore, bring the local
    /// `AudioPlayerManager` in line. Only reacts to *changes* — repeated
    /// snapshots with the same state are ignored so we don't re-seek on
    /// every tick.
    private func applyPlaybackIfNeeded(_ incoming: RoomPlaybackState) {
        // Host doesn't mirror its own writes — it already owns the player.
        guard !isHost else {
            lastAppliedPlayback = incoming
            return
        }
        defer { lastAppliedPlayback = incoming }

        let player = AudioPlayerManager.shared

        // If the track changed, try to play the matching file in the
        // client's local library. If it doesn't exist, bail out of audio
        // sync but keep UI updated.
        let trackChanged = lastAppliedPlayback?.trackFileName != incoming.trackFileName
        if trackChanged {
            if let index = player.tracks.firstIndex(where: { $0.fileName == incoming.trackFileName }) {
                player.playTrack(at: index)
            } else {
                // No local match — skip audio; UI still shows metadata.
                return
            }
        }

        // Compute where we should be and seek there.
        let targetOffset = resolvedOffset(for: incoming, now: Date())
        player.seek(to: targetOffset)
        if incoming.isPlaying {
            if !player.isPlaying { player.play() }
        } else {
            if player.isPlaying { player.pause() }
        }
    }

    /// Pure math: translate a playback state + current wall clock into the
    /// offset a synchronized client should seek to. Exposed as `internal`
    /// so tests can hit it without standing up Firebase.
    func resolvedOffset(for state: RoomPlaybackState, now: Date) -> TimeInterval {
        if state.isPlaying, let startedAt = state.startedAt {
            let base = state.pausedOffset ?? 0
            let elapsed = now.timeIntervalSince(startedAt)
            return max(0, base + elapsed)
        }
        return state.pausedOffset ?? 0
    }
}

// MARK: - Errors

enum RoomError: LocalizedError {
    case firebaseUnavailable
    case codeCollision
    case invalidCode
    case roomNotFound

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable: return "Rooms require an internet connection."
        case .codeCollision: return "Couldn't allocate a room code. Try again."
        case .invalidCode: return "That room code doesn't look right."
        case .roomNotFound: return "No active room with that code."
        }
    }
}
