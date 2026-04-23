import AVFoundation
import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
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
/// Clients that own the matching track locally play their own copy. Clients
/// without it fall back to streaming the host's upload from Firebase Storage
/// (`playback.streamURL`) via an `AVPlayer`. If the upload hasn't finished
/// yet, they stay metadata-only until the URL lands. Chat works regardless.
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

    /// AVPlayer used when this client is a non-host listener without a local
    /// copy of the host's track — it streams from the Storage download URL
    /// the host writes into `playback.streamURL`. Nil when either we're the
    /// host, we have a local match, or no stream URL has arrived yet.
    private var remotePlayer: AVPlayer?

    /// Storage handle, lazy for the same reason `db` is.
    private lazy var storage = Storage.storage()

    private init() {}

    // MARK: - Create

    /// Creates a new room for `track` with `self` as host. Returns the join
    /// code. Retries up to 3 times on the unlikely event of a code collision.
    func createRoom(for track: Track) async throws -> String {
        guard isFirebaseReady else {
            throw RoomError.firebaseUnavailable
        }
        let auth = AuthManager.shared
        let hostID = try await currentAuthUID()
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
                    // Kick off upload in the background so clients that don't
                    // own this file locally can stream it. We write the URL
                    // back into `playback.streamURL` on success.
                    uploadTrackInBackground(track, code: code)
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
        let userID = try await currentAuthUID()
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
        // Firebase Auth UID is the participants-map key we wrote on join —
        // it must match here to delete our slot. If somehow we're not signed
        // in (shouldn't happen after create/join), fall back to no-op key.
        let userID = Auth.auth().currentUser?.uid ?? ""

        if isHost {
            // Host leaving ends the room for everyone.
            Task { [weak self] in
                try? await self?.db.collection("rooms").document(code).delete()
                // Best-effort: delete uploaded audio so we don't leak storage.
                await self?.deleteRoomStorage(code: code)
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
        stopRemotePlayback()
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
            // Clear the old stream URL so clients don't keep playing the
            // previous file while the new one uploads.
            "playback.streamURL": NSNull(),
            "lastActivity": FieldValue.serverTimestamp()
        ])
        if let code = currentRoom?.id {
            uploadTrackInBackground(track, code: code)
        }
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
        let userID = try await currentAuthUID()
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

    /// Given the latest playback state from Firestore, bring the client's
    /// audio in line with the host. Prefers the locally-owned copy of the
    /// track (via `AudioPlayerManager`); falls back to streaming the host's
    /// uploaded copy via `AVPlayer` when no local match exists. Only reacts
    /// to *changes* — repeated snapshots with the same state are ignored so
    /// we don't re-seek on every tick.
    private func applyPlaybackIfNeeded(_ incoming: RoomPlaybackState) {
        // Host doesn't mirror its own writes — it already owns the player.
        guard !isHost else {
            lastAppliedPlayback = incoming
            return
        }
        defer { lastAppliedPlayback = incoming }

        let player = AudioPlayerManager.shared
        let previous = lastAppliedPlayback

        let trackChanged = previous?.trackFileName != incoming.trackFileName
        let streamChanged = previous?.streamURL != incoming.streamURL
        let localIndex = player.tracks.firstIndex { $0.fileName == incoming.trackFileName }

        if trackChanged {
            // New track — drop any running remote stream and pick the best
            // local/remote source for this one.
            stopRemotePlayback()
            if let index = localIndex {
                player.playTrack(at: index)
            } else if let urlString = incoming.streamURL, let url = URL(string: urlString) {
                // Keep the local player from fighting with the stream.
                if player.isPlaying { player.pause() }
                startRemotePlayback(url: url)
            } else {
                // No local, no stream yet — wait for stream to land.
                return
            }
        } else if streamChanged, localIndex == nil, remotePlayer == nil,
                  let urlString = incoming.streamURL, let url = URL(string: urlString) {
            // Same track, but stream URL just became available (upload
            // finished after we already attached to the room).
            if player.isPlaying { player.pause() }
            startRemotePlayback(url: url)
        }

        // Apply seek + play/pause to whichever source is driving audio.
        let targetOffset = resolvedOffset(for: incoming, now: Date())
        if let remotePlayer {
            remotePlayer.seek(to: CMTime(seconds: targetOffset, preferredTimescale: 600))
            if incoming.isPlaying {
                remotePlayer.play()
            } else {
                remotePlayer.pause()
            }
        } else if localIndex != nil {
            player.seek(to: targetOffset)
            if incoming.isPlaying {
                if !player.isPlaying { player.play() }
            } else {
                if player.isPlaying { player.pause() }
            }
        }
    }

    private func startRemotePlayback(url: URL) {
        remotePlayer?.pause()
        remotePlayer = AVPlayer(url: url)
    }

    private func stopRemotePlayback() {
        remotePlayer?.pause()
        remotePlayer = nil
    }

    // MARK: - Track upload (host only)

    /// Spawns a detached upload so `createRoom` / `hostSwitchTrack` return
    /// to the UI immediately. On success we write the download URL back
    /// into `playback.streamURL` so listeners can stream.
    private func uploadTrackInBackground(_ track: Track, code: String) {
        Task { [weak self] in
            guard let self else { return }
            guard let url = await self.uploadTrackForRoom(track, code: code) else { return }
            // Only write back if the room still exists and the track didn't
            // change under us while the upload was running.
            guard await self.shouldWriteStreamURL(forTrack: track.fileName, code: code) else { return }
            try? await self.db.collection("rooms").document(code).updateData([
                "playback.streamURL": url
            ])
        }
    }

    /// True iff we're still in the room, still the host, and the current
    /// track matches the one whose upload just finished. Prevents us from
    /// publishing a stale URL after the host already switched tracks.
    private func shouldWriteStreamURL(forTrack fileName: String, code: String) async -> Bool {
        guard isHost, let room = currentRoom, room.id == code else { return false }
        return room.playback.trackFileName == fileName
    }

    /// Uploads the track's local audio file to `rooms/{code}/audio.{ext}`
    /// and returns the download URL. Uses `putFileAsync` so the SDK streams
    /// from disk rather than loading the whole file into memory — important
    /// for multi-MB tracks.
    private func uploadTrackForRoom(_ track: Track, code: String) async -> String? {
        guard let fileURL = track.fileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let ext = track.fileExtension.isEmpty ? "mp3" : track.fileExtension.lowercased()
        let ref = storage.reference().child("rooms/\(code)/audio.\(ext)")
        let meta = StorageMetadata()
        meta.contentType = Self.contentType(forExtension: ext)

        do {
            _ = try await ref.putFileAsync(from: fileURL, metadata: meta)
            return try await ref.downloadURL().absoluteString
        } catch {
            Logger.beatStore.error(
                "Room track upload failed: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    /// Best-effort cleanup of the room's uploaded audio on host leave.
    /// Non-fatal if it fails (e.g. offline) — Storage isn't source of truth.
    private func deleteRoomStorage(code: String) async {
        let folder = storage.reference().child("rooms/\(code)")
        do {
            let list = try await folder.listAll()
            for item in list.items {
                try? await item.delete()
            }
        } catch {
            Logger.beatStore.debug(
                "Room storage cleanup failed for \(code, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func contentType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "mp3": return "audio/mpeg"
        case "m4a", "aac": return "audio/mp4"
        case "wav": return "audio/wav"
        case "aiff": return "audio/aiff"
        case "flac": return "audio/flac"
        case "ogg": return "audio/ogg"
        case "wma": return "audio/x-ms-wma"
        default: return "audio/\(ext.lowercased())"
        }
    }

    // MARK: - Auth bridge

    /// Firestore rules require `request.auth != null` and tie ownership to
    /// `request.auth.uid`. Apple Sign-In (used elsewhere for UI identity)
    /// is not visible to Firestore, so every write path here must attach a
    /// Firebase Auth UID. We sign in anonymously on first use and re-use
    /// the session for the lifetime of the install.
    private func currentAuthUID() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
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
