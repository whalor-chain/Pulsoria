import Testing
import Foundation
import FirebaseFirestore
@testable import Pulsoria

@MainActor
struct FriendsTests {

    // MARK: - pairID

    @Test func pairIDIsLexicographicallySorted() {
        // The smaller uid comes first regardless of argument order, so
        // both sides of a friendship land on the same Firestore doc.
        #expect(FriendsManager.pairID("aaa", "bbb") == "aaa_bbb")
        #expect(FriendsManager.pairID("bbb", "aaa") == "aaa_bbb")
    }

    @Test func pairIDEqualUIDsStillStable() {
        // Rules prevent self-friendships, but the helper itself shouldn't
        // crash on equal input. Result is well-defined: "x_x".
        #expect(FriendsManager.pairID("x", "x") == "x_x")
    }

    @Test func pairIDHandlesFirebaseLikeUIDs() {
        // Realistic Firebase UIDs are 28-char alphanumerics. Ensure the
        // helper is order-independent on those too.
        let a = "abcDEF1234567890ghiJKL7654321"
        let b = "zyxWVU0987654321rqpONM1234567"
        #expect(FriendsManager.pairID(a, b) == FriendsManager.pairID(b, a))
        #expect(FriendsManager.pairID(a, b).hasPrefix(a))
    }

    // MARK: - FriendPresence.isLive

    private func presence(
        isPlaying: Bool,
        lastSeen: Date?
    ) -> FriendPresence {
        FriendPresence(
            trackTitle: "T",
            trackArtist: "A",
            fileName: "f",
            startedAt: nil,
            isPlaying: isPlaying,
            lastSeen: lastSeen
        )
    }

    @Test func isLiveWhenPlayingAndRecent() {
        let now = Date()
        let p = presence(isPlaying: true, lastSeen: now.addingTimeInterval(-30))
        #expect(p.isLive(now: now) == true)
    }

    @Test func isLiveFalseWhenPlayingButStale() {
        // liveWindow is 120 s — a 3-minute-old snapshot is offline.
        let now = Date()
        let p = presence(isPlaying: true, lastSeen: now.addingTimeInterval(-180))
        #expect(p.isLive(now: now) == false)
    }

    @Test func isLiveFalseWhenNotPlaying() {
        let now = Date()
        let p = presence(isPlaying: false, lastSeen: now.addingTimeInterval(-1))
        #expect(p.isLive(now: now) == false)
    }

    @Test func isLiveFalseWhenLastSeenNil() {
        // Defensive: if Firestore hasn't sent a lastSeen yet we should
        // treat the friend as offline, not crash.
        let p = presence(isPlaying: true, lastSeen: nil)
        #expect(p.isLive(now: Date()) == false)
    }

    // MARK: - relativeBucket (boundaries)

    @Test func relativeBucketNilDate() {
        #expect(FriendPresence.relativeBucket(for: nil, now: Date()) == .none)
    }

    @Test func relativeBucketJustNowAt59Seconds() {
        let now = Date()
        let bucket = FriendPresence.relativeBucket(for: now.addingTimeInterval(-59), now: now)
        #expect(bucket == .justNow)
    }

    @Test func relativeBucketOneMinuteAt60Seconds() {
        // Exactly 60 s ago should flip from "just now" to "1 min".
        let now = Date()
        let bucket = FriendPresence.relativeBucket(for: now.addingTimeInterval(-60), now: now)
        #expect(bucket == .minutes(1))
    }

    @Test func relativeBucket59Minutes() {
        let now = Date()
        let bucket = FriendPresence.relativeBucket(for: now.addingTimeInterval(-59 * 60), now: now)
        #expect(bucket == .minutes(59))
    }

    @Test func relativeBucketFlipsToHoursAt60Minutes() {
        let now = Date()
        let bucket = FriendPresence.relativeBucket(for: now.addingTimeInterval(-60 * 60), now: now)
        #expect(bucket == .hours(1))
    }

    @Test func relativeBucket23Hours() {
        let now = Date()
        let bucket = FriendPresence.relativeBucket(for: now.addingTimeInterval(-23 * 3600), now: now)
        #expect(bucket == .hours(23))
    }

    @Test func relativeBucketFlipsToDaysAt24Hours() {
        let now = Date()
        let bucket = FriendPresence.relativeBucket(for: now.addingTimeInterval(-24 * 3600), now: now)
        #expect(bucket == .days(1))
    }

    // MARK: - decodeRequest

    @Test func decodeRequestFullDocument() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        // Firestore hands us `Timestamp` objects in raw snapshots; the
        // decoder does `as? Timestamp`, so mirror that here.
        let ts = Timestamp(date: timestamp)
        let data: [String: Any] = [
            "from": "uidA",
            "to": "uidB",
            "fromName": "Alice",
            "fromCode": "ABC123",
            "fromAvatarURL": "https://cdn/a.jpg",
            "toName": "Bob",
            "toAvatarURL": "https://cdn/b.jpg",
            "createdAt": ts
        ]
        let request = FriendsManager.decodeRequest(id: "uidA_uidB", data: data)
        #expect(request != nil)
        #expect(request?.fromUID == "uidA")
        #expect(request?.toUID == "uidB")
        #expect(request?.fromName == "Alice")
        #expect(request?.toName == "Bob")
        #expect(request?.fromAvatarURL == "https://cdn/a.jpg")
        #expect(request?.toAvatarURL == "https://cdn/b.jpg")
        #expect(request?.createdAt == timestamp)
    }

    @Test func decodeRequestMissingFromReturnsNil() {
        let data: [String: Any] = ["to": "uidB"]
        #expect(FriendsManager.decodeRequest(id: "any", data: data) == nil)
    }

    @Test func decodeRequestMissingToReturnsNil() {
        let data: [String: Any] = ["from": "uidA"]
        #expect(FriendsManager.decodeRequest(id: "any", data: data) == nil)
    }

    @Test func decodeRequestAppliesDefaultsForOptionalFields() {
        // Only the required from/to are present — names fall back to
        // "User", avatar to nil, code to empty.
        let data: [String: Any] = ["from": "u1", "to": "u2"]
        let request = FriendsManager.decodeRequest(id: "u1_u2", data: data)
        #expect(request?.fromName == "User")
        #expect(request?.toName == "User")
        #expect(request?.fromCode == "")
        #expect(request?.fromAvatarURL == nil)
        #expect(request?.toAvatarURL == nil)
        #expect(request?.createdAt == nil)
    }
}

