import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import Foundation
import OSLog
import UIKit

/// Coordinates the friends + presence layer.
///
/// Data model (Firestore)
/// ----------------------
/// - `users/{uid}` — per-user profile, written by the owner only:
///   `displayName`, `friendCode`, `avatarURL`, `nowPlaying`, `lastSeen`.
/// - `friendCodes/{code}` — reverse index `{ uid }`.
/// - `friendRequests/{from}_{to}` — pending request; deleting the doc
///   is what accept/decline does. On accept we also create:
/// - `friendships/{pairID}` — authoritative membership. `pairID` is the
///   two uids joined in lexicographic order with `_`; `members` holds the
///   pair so `whereField("members", arrayContains: myUID)` works.
///
/// Storage
/// -------
/// - `users/{uid}/avatar.jpg` — uploaded from the locally-saved profile
///   photo (`SettingsView.loadProfileImage()`), refreshed whenever the
///   user edits their profile.
@MainActor
final class FriendsManager: ObservableObject {
    static let shared = FriendsManager()

    // MARK: - Published state

    @Published private(set) var myFriendCode: String = ""
    @Published private(set) var myAvatarURL: String?
    @Published private(set) var friends: [FriendProfile] = []
    @Published private(set) var presenceByFriendID: [String: FriendPresence] = [:]
    @Published private(set) var incomingRequests: [FriendRequest] = []
    @Published private(set) var outgoingRequests: [FriendRequest] = []
    /// Reactions other people sent to MY currently-playing track in
    /// the last 24h. Sorted newest-first. Drives the inbox bell + the
    /// in-app banner that pops up when a fresh reaction lands.
    @Published private(set) var recentReactions: [MusicReaction] = []
    /// Subset of `recentReactions` not yet acknowledged by the user
    /// (set is reset when they open the inbox sheet).
    @Published private(set) var unseenReactionIDs: Set<String> = []

    // MARK: - Private

    private lazy var db = Firestore.firestore()
    private lazy var storage = Storage.storage()
    private var isFirebaseReady: Bool { FirebaseApp.app() != nil }

    private var selfListener: ListenerRegistration?
    private var friendshipsListener: ListenerRegistration?
    private var incomingRequestsListener: ListenerRegistration?
    private var outgoingRequestsListener: ListenerRegistration?
    private var friendListeners: [String: ListenerRegistration] = [:]
    private var reactionsListener: ListenerRegistration?
    private var cancellables: Set<AnyCancellable> = []
    private var didStart = false

    /// Throttle outgoing reactions per friend so a stuck-finger user
    /// doesn't spam-burst 50 fires/sec. Keyed by friendID, value is
    /// the timestamp of the most-recent successful send.
    private var lastReactionSendByFriend: [String: Date] = [:]
    private let reactionMinIntervalPerFriend: TimeInterval = 1.5

    /// Heartbeat that re-stamps `lastSeen` every `heartbeatInterval`
    /// seconds while the user is actively playing. Without this,
    /// presence ages out after `FriendPresence.liveWindow` (2 min)
    /// and friends incorrectly see us as offline mid-song.
    private var heartbeatTask: Task<Void, Never>?
    private let heartbeatInterval: TimeInterval = 45

    /// Periodic clock that re-publishes every `clockInterval` seconds
    /// so views observing `FriendsManager` re-render and re-evaluate
    /// `presence.isLive` (which reads `Date()` at call time). Without
    /// this tick, a live indicator would stay green long after the
    /// friend's `lastSeen` had aged past the freshness window.
    @Published private(set) var presenceClock: Date = Date()
    private var presenceClockTask: Task<Void, Never>?
    private let clockInterval: TimeInterval = 20

    /// `fileName → Storage download URL` for covers we've already uploaded.
    /// Same track plays again → no re-upload. Bounded to 500 entries via
    /// `NSCache`'s automatic purging — unbounded growth could accumulate
    /// a few MB of strings over very long sessions.
    private let coverURLCache: NSCache<NSString, NSString> = {
        let c = NSCache<NSString, NSString>()
        c.countLimit = 500
        return c
    }()

    /// In-flight artwork wait task. Cancelled at the top of every
    /// `writePresence` so a rapid sequence of track changes doesn't
    /// spawn parallel poll loops.
    private var artworkWaitTask: Task<Data?, Never>?

    /// Rate-limit on outgoing friend requests to protect users from
    /// spam / accidental loops. Timestamps of sends in the last hour.
    private var recentRequestTimestamps: [Date] = []
    private let requestsPerHourLimit = 20

    private init() {}

    // MARK: - Start

    /// Idempotent — safe to call from `.task` / `onAppear`. Bails out if
    /// Firebase isn't configured (e.g. CI) or no auth session yet.
    func start() {
        guard !didStart, isFirebaseReady else { return }
        didStart = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let uid = try await self.ensureAuthUID()
                try await self.ensureMyProfile(uid: uid)
                self.attachSelfListener(uid: uid)
                self.attachFriendshipsListener(uid: uid)
                self.attachRequestListeners(uid: uid)
                self.attachReactionsListener(uid: uid)
                self.subscribeToPlayerForPresence()
                self.subscribeToRoomForPresence()
                self.subscribeToAppLifecycle()
                self.startPresenceClock()
                // Fire-and-forget avatar sync — if the user already has a
                // local profile photo, get it into Storage.
                Task { await self.syncMyAvatar() }
            } catch {
                Logger.beatStore.error(
                    "FriendsManager start failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    /// Full teardown — call from `AuthManager.signOut` so the next user
    /// on the same device doesn't inherit stale listeners under the
    /// previous uid. `start()` can be called again afterwards.
    func stop() {
        selfListener?.remove()
        friendshipsListener?.remove()
        incomingRequestsListener?.remove()
        outgoingRequestsListener?.remove()
        reactionsListener?.remove()
        selfListener = nil
        friendshipsListener = nil
        incomingRequestsListener = nil
        outgoingRequestsListener = nil
        reactionsListener = nil

        for (_, listener) in friendListeners { listener.remove() }
        friendListeners.removeAll()

        cancellables.removeAll()
        artworkWaitTask?.cancel()
        artworkWaitTask = nil
        stopHeartbeat()
        stopPresenceClock()

        myFriendCode = ""
        myAvatarURL = nil
        friends = []
        presenceByFriendID = [:]
        incomingRequests = []
        outgoingRequests = []
        recentReactions = []
        unseenReactionIDs = []
        recentRequestTimestamps = []
        lastReactionSendByFriend = [:]
        coverURLCache.removeAllObjects()
        didStart = false
    }

    private func ensureAuthUID() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }

    // MARK: - Profile bootstrap

    /// Creates / refreshes `users/{uid}`. On every launch we push the
    /// current locally-edited nickname so friends see the latest name.
    private func ensureMyProfile(uid: String) async throws {
        let ref = db.collection("users").document(uid)
        let snap = try await ref.getDocument()

        let displayName = Self.currentDisplayName()

        if snap.exists {
            try? await ref.updateData([
                "displayName": displayName,
                "lastSeen": FieldValue.serverTimestamp()
            ])
            return
        }

        let code = try await allocateFriendCode(uid: uid)
        try await ref.setData([
            "displayName": displayName,
            "friendCode": code,
            "lastSeen": FieldValue.serverTimestamp()
        ])
    }

    /// Locally-edited nickname wins over the Apple Sign-In name, since the
    /// nickname is what the user typed themselves in the profile editor.
    private static func currentDisplayName() -> String {
        let nickname = UserDefaults.standard.string(forKey: UserDefaultsKey.userNickname)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if !nickname.isEmpty { return nickname }
        let appleName = AuthManager.shared.userName.trimmingCharacters(in: .whitespaces)
        if !appleName.isEmpty { return appleName }
        return "User"
    }

    /// Called from the profile editor after the user saves. Refreshes
    /// both the display name (cheap, just an updateData) and the avatar
    /// (may re-upload to Storage).
    func refreshMyProfile() {
        guard isFirebaseReady, let uid = Auth.auth().currentUser?.uid else { return }
        let displayName = Self.currentDisplayName()
        Task {
            try? await self.db.collection("users").document(uid).updateData([
                "displayName": displayName
            ])
            await self.syncMyAvatar()
        }
    }

    /// Finds an unused 6-char code and claims it for `uid`. Retries up to
    /// five times in the unlikely event of a collision.
    private func allocateFriendCode(uid: String) async throws -> String {
        for _ in 0..<5 {
            let code = RoomCode.generate()
            let ref = db.collection("friendCodes").document(code)
            do {
                _ = try await db.runTransaction { tx, errorPtr in
                    let snap: DocumentSnapshot
                    do {
                        snap = try tx.getDocument(ref)
                    } catch {
                        errorPtr?.pointee = error as NSError
                        return false
                    }
                    if snap.exists {
                        errorPtr?.pointee = NSError(domain: "CodeExists", code: 1)
                        return false
                    }
                    tx.setData(["uid": uid], forDocument: ref)
                    return true
                }
                return code
            } catch {
                continue
            }
        }
        throw FriendsError.codeAllocation
    }

    // MARK: - Avatar upload

    /// Reads the on-disk profile photo, compresses it, uploads to
    /// `users/{uid}/avatar.jpg`, and writes the download URL back into
    /// the user doc so friends' listeners pick up the change.
    func syncMyAvatar() async {
        guard isFirebaseReady, let uid = Auth.auth().currentUser?.uid else { return }
        guard let image = SettingsView.loadProfileImage() else {
            // User removed their photo — clear Storage + URL field.
            let ref = storage.reference().child("users/\(uid)/avatar.jpg")
            try? await ref.delete()
            try? await db.collection("users").document(uid).updateData([
                "avatarURL": NSNull()
            ])
            return
        }
        // Downscale to ~256px longest side for friends-list thumbnails —
        // the profile editor already compresses but 1024px originals are
        // overkill for a 44pt avatar.
        let resized = image.downscaled(to: 256)
        guard let data = resized.jpegData(compressionQuality: 0.75) else { return }

        let ref = storage.reference().child("users/\(uid)/avatar.jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        do {
            _ = try await ref.putDataAsync(data, metadata: meta)
            let url = try await ref.downloadURL().absoluteString
            try? await db.collection("users").document(uid).updateData([
                "avatarURL": url
            ])
        } catch {
            Logger.beatStore.error(
                "Avatar upload failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Listeners

    private func attachSelfListener(uid: String) {
        selfListener?.remove()
        selfListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor [weak self] in
                    guard let self, let snapshot, snapshot.exists else { return }
                    let data = snapshot.data() ?? [:]
                    self.myFriendCode = data["friendCode"] as? String ?? ""
                    self.myAvatarURL = data["avatarURL"] as? String
                }
            }
    }

    private func attachFriendshipsListener(uid: String) {
        friendshipsListener?.remove()
        friendshipsListener = db.collection("friendships")
            .whereField("members", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor [weak self] in
                    guard let self, let snapshot else { return }
                    var friendIDs: [String] = []
                    for doc in snapshot.documents {
                        let members = doc.data()["members"] as? [String] ?? []
                        if let other = members.first(where: { $0 != uid }) {
                            friendIDs.append(other)
                        }
                    }
                    self.syncFriendListeners(for: friendIDs)
                }
            }
    }

    private func attachRequestListeners(uid: String) {
        incomingRequestsListener?.remove()
        incomingRequestsListener = db.collection("friendRequests")
            .whereField("to", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor [weak self] in
                    guard let self, let snapshot else { return }
                    self.incomingRequests = snapshot.documents.compactMap { doc in
                        Self.decodeRequest(id: doc.documentID, data: doc.data())
                    }
                }
            }

        outgoingRequestsListener?.remove()
        outgoingRequestsListener = db.collection("friendRequests")
            .whereField("from", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor [weak self] in
                    guard let self, let snapshot else { return }
                    self.outgoingRequests = snapshot.documents.compactMap { doc in
                        Self.decodeRequest(id: doc.documentID, data: doc.data())
                    }
                }
            }
    }

    /// Exposed for unit tests — `nonisolated` so tests don't need the
    /// MainActor hop, `internal` so `@testable import Pulsoria` can see it.
    nonisolated static func decodeRequest(id: String, data: [String: Any]) -> FriendRequest? {
        guard let from = data["from"] as? String,
              let to = data["to"] as? String else { return nil }
        return FriendRequest(
            id: id,
            fromUID: from,
            toUID: to,
            fromName: data["fromName"] as? String ?? "User",
            fromCode: data["fromCode"] as? String ?? "",
            fromAvatarURL: data["fromAvatarURL"] as? String,
            toName: data["toName"] as? String ?? "User",
            toAvatarURL: data["toAvatarURL"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }

    /// Diffs the incoming friend ID list against our current per-friend
    /// listeners and adds/removes subscriptions to match.
    private func syncFriendListeners(for ids: [String]) {
        let idSet = Set(ids)

        for (id, listener) in friendListeners where !idSet.contains(id) {
            listener.remove()
            friendListeners.removeValue(forKey: id)
            presenceByFriendID.removeValue(forKey: id)
            friends.removeAll { $0.id == id }
        }

        for id in ids where friendListeners[id] == nil {
            let listener = db.collection("users").document(id)
                .addSnapshotListener { [weak self] snapshot, _ in
                    Task { @MainActor [weak self] in
                        guard let self, let snapshot, snapshot.exists else { return }
                        self.applyFriendSnapshot(id: id, data: snapshot.data() ?? [:])
                    }
                }
            friendListeners[id] = listener
        }
    }

    private func applyFriendSnapshot(id: String, data: [String: Any]) {
        let profile = FriendProfile(
            id: id,
            displayName: data["displayName"] as? String ?? "User",
            friendCode: data["friendCode"] as? String ?? "",
            avatarURL: data["avatarURL"] as? String,
            currentRoomCode: data["currentRoomCode"] as? String
        )
        if let idx = friends.firstIndex(where: { $0.id == id }) {
            // Hot path: presence / displayName update for an existing
            // friend. Position in the list is unchanged — resorting here
            // fires O(N log N) on every presence tick (~4 Hz × friends).
            // Sort only when a friend is genuinely added or renamed
            // past their neighbour.
            let oldName = friends[idx].displayName
            friends[idx] = profile
            if oldName != profile.displayName {
                friends.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            }
        } else {
            friends.append(profile)
            friends.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }

        let lastSeen = (data["lastSeen"] as? Timestamp)?.dateValue()
        if let np = data["nowPlaying"] as? [String: Any] {
            presenceByFriendID[id] = FriendPresence(
                trackTitle: np["title"] as? String ?? "",
                trackArtist: np["artist"] as? String ?? "",
                fileName: np["fileName"] as? String ?? "",
                startedAt: (np["startedAt"] as? Timestamp)?.dateValue(),
                isPlaying: np["isPlaying"] as? Bool ?? false,
                lastSeen: lastSeen,
                coverURL: np["coverURL"] as? String
            )
        } else {
            presenceByFriendID[id] = FriendPresence(
                trackTitle: "",
                trackArtist: "",
                fileName: "",
                startedAt: nil,
                isPlaying: false,
                lastSeen: lastSeen,
                coverURL: nil
            )
        }
    }

    // MARK: - Requests

    /// Resolves `code` to a uid and creates a `friendRequests/{from}_{to}`
    /// doc. The recipient's `FriendsManager` will pick it up via the
    /// incoming-requests listener.
    func sendFriendRequest(byCode rawCode: String) async throws {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == RoomCode.length else { throw FriendsError.invalidCode }

        try enforceRequestRateLimit()

        let codeSnap = try await db.collection("friendCodes").document(code).getDocument()
        guard codeSnap.exists, let targetUID = codeSnap.data()?["uid"] as? String else {
            throw FriendsError.notFound
        }

        let myUID = try await ensureAuthUID()
        guard targetUID != myUID else { throw FriendsError.cantAddSelf }

        // Already friends? Skip — nothing to do.
        if friends.contains(where: { $0.id == targetUID }) { throw FriendsError.alreadyFriends }

        // If they already sent *us* a request, auto-accept instead of
        // creating a duplicate pending pair.
        if let existing = incomingRequests.first(where: { $0.fromUID == targetUID }) {
            try await acceptRequest(existing)
            return
        }

        let requestID = "\(myUID)_\(targetUID)"
        // If a stale outgoing doc still exists (e.g. we cancelled but
        // the listener snapshot hadn't propagated yet), delete it
        // before the create — Firestore rules forbid update on
        // friendRequests, so `setData` would otherwise silently fail.
        try? await db.collection("friendRequests").document(requestID).delete()

        async let myProfileSnap = db.collection("users").document(myUID).getDocument()
        async let targetProfileSnap = db.collection("users").document(targetUID).getDocument()
        let myData = (try await myProfileSnap).data() ?? [:]
        let targetData = (try await targetProfileSnap).data() ?? [:]

        try await db.collection("friendRequests").document(requestID).setData([
            "from": myUID,
            "to": targetUID,
            // These get overwritten server-side by `notifyOnFriendRequest`
            // with sanitized / server-trusted values — we still send
            // something so the UI renders correctly in the split-second
            // before the Cloud Function fires.
            "fromName": myData["displayName"] as? String ?? Self.currentDisplayName(),
            "fromCode": myData["friendCode"] as? String ?? myFriendCode,
            "fromAvatarURL": (myData["avatarURL"] as? String) ?? NSNull(),
            "toName": targetData["displayName"] as? String ?? "User",
            "toAvatarURL": (targetData["avatarURL"] as? String) ?? NSNull(),
            "createdAt": FieldValue.serverTimestamp()
        ])

        recordRequestSend()
    }

    /// Throws `.rateLimited` if the user has sent `requestsPerHourLimit`
    /// or more requests in the last hour. Purely client-side guard —
    /// the real server-side check would live in a Cloud Function; this
    /// still catches accidental loops / overly-enthusiastic testing.
    private func enforceRequestRateLimit() throws {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        recentRequestTimestamps.removeAll { $0 < oneHourAgo }
        if recentRequestTimestamps.count >= requestsPerHourLimit {
            throw FriendsError.rateLimited
        }
    }

    private func recordRequestSend() {
        recentRequestTimestamps.append(Date())
    }

    /// Delete the request doc + create the friendship doc in one batch so
    /// both sides flip to "friends" together. `acceptedBy` lets the
    /// Cloud Function send a push only to the *sender* (who doesn't
    /// yet have UI feedback) and skip the accepter (who already sees
    /// the list update).
    func acceptRequest(_ request: FriendRequest) async throws {
        let myUID = try await ensureAuthUID()
        guard request.toUID == myUID else { return }
        // Defensive: should be rejected at create-time by rules, but
        // double-check — accepting one's own self-spoofed request
        // would bypass the approval flow.
        guard request.fromUID != myUID else { return }

        let pairID = Self.pairID(request.fromUID, myUID)
        let batch = db.batch()
        batch.deleteDocument(db.collection("friendRequests").document(request.id))
        batch.setData([
            "members": [request.fromUID, myUID],
            "acceptedBy": myUID,
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: db.collection("friendships").document(pairID))
        try await batch.commit()
    }

    func declineRequest(_ request: FriendRequest) async throws {
        try await db.collection("friendRequests").document(request.id).delete()
    }

    /// Cancel a request we sent that's still pending.
    func cancelOutgoing(_ request: FriendRequest) async throws {
        try await db.collection("friendRequests").document(request.id).delete()
    }

    /// Unfriend — deletes the friendship doc. Both sides see them drop
    /// via their friendships listener.
    func removeFriend(_ friendID: String) async throws {
        guard let myUID = Auth.auth().currentUser?.uid else { return }
        let pairID = Self.pairID(myUID, friendID)
        try await db.collection("friendships").document(pairID).delete()
    }

    /// Deterministic doc id for a friendship — both sides derive the same
    /// key regardless of who initiated. Exposed `nonisolated` for tests.
    nonisolated static func pairID(_ a: String, _ b: String) -> String {
        a < b ? "\(a)_\(b)" : "\(b)_\(a)"
    }

    // MARK: - Presence writes

    /// Publishes the user's `currentRoomCode` whenever they create, join
    /// or leave a listening room. Friends' clients pick it up via the
    /// snapshot listener and expose a "Join their room" shortcut.
    private func subscribeToRoomForPresence() {
        ListeningRoomManager.shared.$currentRoom
            .map { $0?.id }
            .removeDuplicates()
            .sink { [weak self] code in
                Task { @MainActor [weak self] in
                    self?.writeCurrentRoomCode(code)
                }
            }
            .store(in: &cancellables)
    }

    private func writeCurrentRoomCode(_ code: String?) {
        guard isFirebaseReady, let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            try? await self.db.collection("users").document(uid).updateData([
                "currentRoomCode": code ?? NSNull()
            ])
        }
    }

    private func subscribeToPlayerForPresence() {
        let player = AudioPlayerManager.shared

        // Tighter debounce (300 ms) so a friend hitting pause is
        // reflected on others' devices ~instantly. The original 1 s
        // window was conservative; in practice play/pause events
        // don't burst that fast.
        player.$currentTrack
            .combineLatest(player.$isPlaying)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] track, isPlaying in
                Task { @MainActor [weak self] in
                    self?.writePresence(track: track, isPlaying: isPlaying)
                }
            }
            .store(in: &cancellables)
    }

    /// Re-fires `writePresence` on `willEnterForeground` so a friend
    /// who briefly backgrounded the app gets stamped fresh as soon as
    /// they come back, instead of waiting for the next track change.
    /// Also shuts down the heartbeat in background — `Task.sleep`
    /// fires unreliably when suspended, and iOS would just retry the
    /// updateData on resume anyway.
    private func subscribeToAppLifecycle() {
        NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification
        )
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let player = AudioPlayerManager.shared
                self.writePresence(track: player.currentTrack, isPlaying: player.isPlaying)
            }
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: UIApplication.didEnterBackgroundNotification
        )
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopHeartbeat()
            }
        }
        .store(in: &cancellables)
    }

    private func writePresence(track: Track?, isPlaying: Bool) {
        guard isFirebaseReady, let uid = Auth.auth().currentUser?.uid else { return }
        let ref = db.collection("users").document(uid)

        // Heartbeat lifecycle — only run the keep-alive when actually
        // playing. On pause / track-clear we let the natural age-out
        // mark us offline within the live window.
        if isPlaying, track != nil {
            startHeartbeat()
        } else {
            stopHeartbeat()
        }

        Task {
            var data: [String: Any] = [
                "lastSeen": FieldValue.serverTimestamp()
            ]
            if let track {
                // Wait up to ~3 s for artwork to finish loading so the
                // cover lands on the friend's side in the same snapshot
                // as the title / artist — no "text first, cover later"
                // pop-in.
                let coverURL = await self.uploadCoverWaitingForArt(for: track)

                // Bail out if the user switched tracks while we were
                // waiting — the next debounce cycle will write the real
                // current track.
                guard AudioPlayerManager.shared.currentTrack?.fileName == track.fileName else {
                    return
                }

                var nowPlaying: [String: Any] = [
                    "title": track.title,
                    "artist": track.artist,
                    "fileName": track.fileName,
                    "startedAt": FieldValue.serverTimestamp(),
                    "isPlaying": isPlaying
                ]
                if let coverURL { nowPlaying["coverURL"] = coverURL }
                data["nowPlaying"] = nowPlaying
            } else {
                data["nowPlaying"] = NSNull()
            }
            try? await ref.updateData(data)
        }
    }

    // MARK: - Heartbeat & clock

    /// Starts a background loop that re-stamps `lastSeen` every
    /// `heartbeatInterval` seconds. Idempotent — calling start twice
    /// just replaces the prior task.
    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTask = Task { [weak self] in
            // Sleep first then write — the initial writePresence call
            // already stamped lastSeen, no need to spam another write
            // immediately.
            while !Task.isCancelled {
                let interval = self?.heartbeatInterval ?? 45
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                await MainActor.run {
                    self?.bumpHeartbeat()
                }
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    /// Cheap update — only `lastSeen` plus a guard write of
    /// `nowPlaying.isPlaying = true` so any stale `false` (e.g.
    /// from a brief Combine glitch) gets repaired automatically.
    /// No-op if we're not actually playing right now.
    private func bumpHeartbeat() {
        guard isFirebaseReady, let uid = Auth.auth().currentUser?.uid else { return }
        let player = AudioPlayerManager.shared
        guard player.isPlaying, player.currentTrack != nil else {
            stopHeartbeat()
            return
        }
        Task {
            try? await db.collection("users").document(uid).updateData([
                "lastSeen": FieldValue.serverTimestamp(),
                "nowPlaying.isPlaying": true
            ])
        }
    }

    /// Drives a periodic `presenceClock` re-publish so views consuming
    /// `presence.isLive` re-render and pick up freshness changes
    /// without needing a presence-doc update from the friend's side.
    private func startPresenceClock() {
        stopPresenceClock()
        presenceClockTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.clockInterval ?? 20
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                await MainActor.run {
                    self?.presenceClock = Date()
                }
            }
        }
    }

    private func stopPresenceClock() {
        presenceClockTask?.cancel()
        presenceClockTask = nil
    }

    /// Polls `artworkCache` for up to ~3 s, then uploads. Genius artwork
    /// loads async from `AudioPlayerManager.playTrack`, so without this
    /// wait the very first play of a brand-new track would land on
    /// friends without a cover.
    private func uploadCoverWaitingForArt(for track: Track) async -> String? {
        if let cached = coverURLCache.object(forKey: track.fileName as NSString) {
            return cached as String
        }

        let data = await waitForArtwork(fileName: track.fileName, timeout: 3)
        guard let data, !data.isEmpty else { return nil }
        return await uploadCoverData(data, fileName: track.fileName)
    }

    /// Polls `AudioPlayerManager.artworkCache` every 150 ms until either
    /// artwork appears for `fileName` or `timeout` elapses. Any previous
    /// wait is cancelled when a new one starts so rapid track changes
    /// don't stack parallel poll loops.
    private func waitForArtwork(fileName: String, timeout: TimeInterval) async -> Data? {
        artworkWaitTask?.cancel()
        let task = Task<Data?, Never> { @MainActor in
            let player = AudioPlayerManager.shared
            if let data = player.artworkCache[fileName], !data.isEmpty { return data }

            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                try? await Task.sleep(nanoseconds: 150_000_000)
                if Task.isCancelled { return nil }
                // If the user flipped tracks, stop waiting for the old
                // one — caller's track-equality guard handles any stale
                // write.
                guard AudioPlayerManager.shared.currentTrack?.fileName == fileName else {
                    return nil
                }
                if let data = player.artworkCache[fileName], !data.isEmpty { return data }
            }
            return player.artworkCache[fileName]
        }
        artworkWaitTask = task
        return await task.value
    }

    /// Uploads raw artwork bytes to `users/{uid}/covers/{key}.jpg` and
    /// returns the download URL, caching the result for the fileName.
    private func uploadCoverData(_ data: Data, fileName: String) async -> String? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }

        // Downscale to a thumb — rows render at ~36 pt, 256 px is plenty.
        guard let image = UIImage(data: data)?.downscaled(to: 256),
              let jpeg = image.jpegData(compressionQuality: 0.75) else {
            return nil
        }

        let key = Self.safeStorageKey(for: fileName)
        let ref = storage.reference().child("users/\(uid)/covers/\(key).jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        do {
            _ = try await ref.putDataAsync(jpeg, metadata: meta)
            let url = try await ref.downloadURL().absoluteString
            coverURLCache.setObject(url as NSString, forKey: fileName as NSString)
            return url
        } catch {
            Logger.beatStore.error(
                "Cover upload failed: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    /// Sanitizes a track fileName into a path-safe Storage key. User
    /// imports can have `/`, `#`, `?`, etc. in the name — strip to
    /// alphanumerics + dashes/underscores, cap length so we don't blow
    /// past Storage path limits on freakishly long titles.
    private static func safeStorageKey(for fileName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = fileName.unicodeScalars.map {
            allowed.contains($0) ? Character($0) : "_"
        }
        let joined = String(filtered).prefix(80)
        return joined.isEmpty ? "cover" : String(joined)
    }

    // MARK: - Music Reactions

    /// Sends an emoji reaction to a friend's currently-playing track.
    /// Reads the friend's live presence so the reaction carries the
    /// exact track title/artist/fileName they're listening to right
    /// now — the recipient sees the context, not just the emoji.
    /// No-ops if the friend isn't currently live, or if we just sent
    /// a reaction to them within the throttle window.
    @discardableResult
    func sendReaction(toFriendID: String, emoji: String) async -> Bool {
        guard MusicReaction.allowedEmojis.contains(emoji) else {
            Logger.beatStore.warning("sendReaction: emoji '\(emoji, privacy: .public)' not in whitelist")
            return false
        }
        guard isFirebaseReady, let myUID = Auth.auth().currentUser?.uid else {
            Logger.beatStore.warning("sendReaction: no Firebase auth UID available")
            await MainActor.run {
                ErrorBannerManager.shared.report("Sign in required to send reactions")
            }
            return false
        }

        // Throttle — one reaction per ~1.5s per friend.
        let now = Date()
        if let last = lastReactionSendByFriend[toFriendID],
           now.timeIntervalSince(last) < reactionMinIntervalPerFriend {
            Logger.beatStore.info("sendReaction: throttled (last sent \(now.timeIntervalSince(last))s ago)")
            return false
        }

        // Track snapshot is best-effort — we send the reaction even if
        // the friend isn't currently live, so the user gets feedback
        // and the recipient still sees who reacted. Empty strings are
        // valid per the Firestore rule.
        let presence = presenceByFriendID[toFriendID]
        let trackTitle = presence?.trackTitle ?? ""
        let trackArtist = presence?.trackArtist ?? ""
        let fileName = presence?.fileName ?? ""

        let myName = Self.currentDisplayName()
        let myAvatar = myAvatarURL ?? ""

        let data: [String: Any] = [
            "fromUID": myUID,
            "toUID": toFriendID,
            "fromName": myName,
            "fromAvatarURL": myAvatar,
            "emoji": emoji,
            "trackTitle": trackTitle,
            "trackArtist": trackArtist,
            "fileName": fileName,
            "createdAt": FieldValue.serverTimestamp()
        ]

        do {
            let ref = try await db.collection("reactions").addDocument(data: data)
            lastReactionSendByFriend[toFriendID] = now
            Logger.beatStore.info("sendReaction: wrote \(ref.documentID, privacy: .public) emoji=\(emoji, privacy: .public)")
            return true
        } catch {
            Logger.beatStore.error(
                "sendReaction failed: \(error.localizedDescription, privacy: .public)"
            )
            // Surface the real error so the user (and we) can see what
            // Firestore actually rejected — usually rules-not-deployed.
            let message = "Reaction send failed: \(error.localizedDescription)"
            await MainActor.run {
                ErrorBannerManager.shared.report(message)
            }
            return false
        }
    }

    /// Watches `reactions` where `toUID == myUID` so reactions from
    /// friends pop up in the inbox as soon as they arrive. Capped at
    /// the last 100 raw entries; we filter to "last 24h" + sort by
    /// `createdAt` descending on the *client* so the query stays
    /// index-free (a server-side `where + orderBy` combo would need
    /// a composite index deployed via `firestore.indexes.json`).
    private func attachReactionsListener(uid: String) {
        reactionsListener?.remove()

        reactionsListener = db.collection("reactions")
            .whereField("toUID", isEqualTo: uid)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let error {
                    Logger.beatStore.error(
                        "reactions listener error: \(error.localizedDescription, privacy: .public)"
                    )
                    return
                }
                guard let docs = snap?.documents else { return }
                let cutoff = Date().addingTimeInterval(-86400)
                let parsed = docs
                    .compactMap(Self.decodeReaction)
                    // 24h window — older reactions still sit in
                    // Firestore but aren't surfaced in the inbox.
                    .filter { ($0.createdAt ?? .distantPast) > cutoff }
                    .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                    .prefix(30)
                let trimmed = Array(parsed)
                Task { @MainActor in
                    let previous = Set(self.recentReactions.map(\.id))
                    self.recentReactions = trimmed
                    let fresh = trimmed
                        .map(\.id)
                        .filter { !previous.contains($0) }
                    if !fresh.isEmpty {
                        self.unseenReactionIDs.formUnion(fresh)
                    }
                }
            }
    }

    /// Marks all currently-loaded reactions as seen. Call when the
    /// inbox sheet is opened — clears the badge counter.
    func markReactionsSeen() {
        unseenReactionIDs.removeAll()
    }

    /// Decodes a Firestore reaction doc — tolerant of missing fields
    /// so a corrupt write doesn't break the inbox stream.
    private static func decodeReaction(_ snap: QueryDocumentSnapshot) -> MusicReaction? {
        let d = snap.data()
        guard let fromUID = d["fromUID"] as? String,
              let toUID = d["toUID"] as? String,
              let emoji = d["emoji"] as? String,
              let trackTitle = d["trackTitle"] as? String,
              let trackArtist = d["trackArtist"] as? String,
              let fileName = d["fileName"] as? String else {
            return nil
        }
        return MusicReaction(
            id: snap.documentID,
            fromUID: fromUID,
            toUID: toUID,
            fromName: d["fromName"] as? String ?? "User",
            fromAvatarURL: d["fromAvatarURL"] as? String,
            emoji: emoji,
            trackTitle: trackTitle,
            trackArtist: trackArtist,
            fileName: fileName,
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue()
        )
    }
}

// MARK: - Errors

enum FriendsError: LocalizedError {
    case invalidCode
    case notFound
    case cantAddSelf
    case alreadyFriends
    case codeAllocation
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "Enter a 6-character code."
        case .notFound: return "No user with that code."
        case .cantAddSelf: return "You can't add yourself."
        case .alreadyFriends: return "You're already friends."
        case .codeAllocation: return "Couldn't reserve a friend code. Try again."
        case .rateLimited: return "Too many requests sent recently. Try again later."
        }
    }
}

// MARK: - Image helper

private extension UIImage {
    /// Resizes the image so its longest side is `target` points, preserving
    /// aspect ratio. Cheap enough to run on the main thread for avatars.
    func downscaled(to target: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > target else { return self }
        let scale = target / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
