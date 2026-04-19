import Testing
import Foundation
@testable import Pulsoria

struct ListeningRoomTests {

    // MARK: - RoomCode.generate

    @Test func generatedCodesHaveCorrectLength() {
        for _ in 0..<50 {
            let code = RoomCode.generate()
            #expect(code.count == RoomCode.length)
        }
    }

    @Test func generatedCodesUseOnlyAllowedCharacters() {
        // Alphabet is uppercase A-Z minus I, O plus digits 2-9 (no 0, 1).
        let allowed: Set<Character> = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for _ in 0..<100 {
            let code = RoomCode.generate()
            for character in code {
                #expect(allowed.contains(character), "Unexpected char \(character) in \(code)")
            }
        }
    }

    @Test func generatedCodesAreTypicallyUnique() {
        // 32^6 ≈ 1.07B possible codes. Birthday-paradox estimate of a
        // collision in k draws is ~k² / (2·N): at k=500 it's ~0.012%,
        // enough to bite CI a few times a year; at k=100 it's ~0.0005%,
        // vanishingly rare — so we only need 100 to smoke-test that
        // `randomElement()` isn't stuck on one value. A real randomness
        // regression would show up long before it runs out of the
        // 1-billion-code space.
        let codes = Set((0..<100).map { _ in RoomCode.generate() })
        #expect(codes.count == 100)
    }

    // MARK: - RoomCode.isValid / normalize

    @Test func validCodesAcceptedRegardlessOfCase() {
        #expect(RoomCode.isValid("ABC234"))
        #expect(RoomCode.isValid("abc234"))      // lowercase is normalized up
        #expect(RoomCode.isValid("  ABC234  "))  // trims whitespace
    }

    @Test func invalidCodesRejected() {
        #expect(!RoomCode.isValid(""))
        #expect(!RoomCode.isValid("ABC"))         // too short
        #expect(!RoomCode.isValid("ABC2345"))     // too long
        #expect(!RoomCode.isValid("ABC23O"))      // contains O (excluded)
        #expect(!RoomCode.isValid("ABC23I"))      // contains I (excluded)
        #expect(!RoomCode.isValid("ABC230"))      // contains 0 (excluded)
        #expect(!RoomCode.isValid("ABC231"))      // contains 1 (excluded)
        #expect(!RoomCode.isValid("ABC-234"))     // non-alphanumeric
    }

    @Test func normalizeProducesCanonicalForm() {
        #expect(RoomCode.normalize("abc234") == "ABC234")
        #expect(RoomCode.normalize("  K7X2PM \n") == "K7X2PM")
    }

    // MARK: - resolvedOffset (playback sync math)

    private func state(
        isPlaying: Bool,
        pausedOffset: Double?,
        startedAt: Date?
    ) -> RoomPlaybackState {
        RoomPlaybackState(
            trackFileName: "track",
            trackTitle: "Title",
            trackArtist: "Artist",
            durationSeconds: 180,
            startedAt: startedAt,
            pausedOffset: pausedOffset,
            isPlaying: isPlaying
        )
    }

    @MainActor
    @Test func pausedStateReturnsPausedOffset() {
        let rooms = ListeningRoomManager.shared
        let now = Date()
        let s = state(isPlaying: false, pausedOffset: 42, startedAt: nil)
        #expect(rooms.resolvedOffset(for: s, now: now) == 42)
    }

    @MainActor
    @Test func pausedWithNilOffsetReturnsZero() {
        let rooms = ListeningRoomManager.shared
        let s = state(isPlaying: false, pausedOffset: nil, startedAt: nil)
        #expect(rooms.resolvedOffset(for: s, now: Date()) == 0)
    }

    @MainActor
    @Test func playingStateAddsElapsedToPausedOffset() {
        // Host hit play 10 seconds ago starting from 30s into the track.
        // Our expected offset is 40s.
        let rooms = ListeningRoomManager.shared
        let startedAt = Date(timeIntervalSinceNow: -10)
        let s = state(isPlaying: true, pausedOffset: 30, startedAt: startedAt)
        let resolved = rooms.resolvedOffset(for: s, now: Date())
        #expect(abs(resolved - 40) < 0.5) // tolerate half-second timing
    }

    @MainActor
    @Test func playingWithoutStartedAtFallsBackToPausedOffset() {
        // Edge: isPlaying=true but no server timestamp yet (snapshot
        // before server-side resolve). Should not produce a weird huge
        // offset — fall back to pausedOffset.
        let rooms = ListeningRoomManager.shared
        let s = state(isPlaying: true, pausedOffset: 15, startedAt: nil)
        #expect(rooms.resolvedOffset(for: s, now: Date()) == 15)
    }

    @MainActor
    @Test func playingClampsNegativeOffsetsToZero() {
        // Defensive: if clocks were massively skewed and arithmetic went
        // negative, we should seek to 0 rather than a negative time.
        let rooms = ListeningRoomManager.shared
        let futureStart = Date(timeIntervalSinceNow: 60) // "started" 60s from now
        let s = state(isPlaying: true, pausedOffset: 0, startedAt: futureStart)
        #expect(rooms.resolvedOffset(for: s, now: Date()) == 0)
    }

    // MARK: - RoomError descriptions

    @Test func roomErrorDescriptionsAreHuman() {
        #expect(RoomError.firebaseUnavailable.errorDescription == "Rooms require an internet connection.")
        #expect(RoomError.codeCollision.errorDescription == "Couldn't allocate a room code. Try again.")
        #expect(RoomError.invalidCode.errorDescription == "That room code doesn't look right.")
        #expect(RoomError.roomNotFound.errorDescription == "No active room with that code.")
    }
}
