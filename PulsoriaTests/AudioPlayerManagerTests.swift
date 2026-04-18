import Testing
import Foundation
@testable import Pulsoria

@MainActor
struct AudioPlayerManagerTests {

    // MARK: - formatTime

    @Test func formatTimeZero() {
        #expect(AudioPlayerManager.shared.formatTime(0) == "0:00")
    }

    @Test func formatTimePadsSingleDigitSeconds() {
        #expect(AudioPlayerManager.shared.formatTime(5) == "0:05")
    }

    @Test func formatTimeCrossesMinuteBoundary() {
        #expect(AudioPlayerManager.shared.formatTime(65) == "1:05")
        #expect(AudioPlayerManager.shared.formatTime(60) == "1:00")
    }

    @Test func formatTimeHandlesLargeValues() {
        // The player does not truncate to hour:min:sec — it shows total minutes.
        #expect(AudioPlayerManager.shared.formatTime(3725) == "62:05")
    }

    @Test func formatTimeTruncatesFractionalSeconds() {
        #expect(AudioPlayerManager.shared.formatTime(61.999) == "1:01")
    }

    @Test func formatTimeReturnsZeroForNaN() {
        #expect(AudioPlayerManager.shared.formatTime(.nan) == "0:00")
    }

    @Test func formatTimeReturnsZeroForInfinity() {
        #expect(AudioPlayerManager.shared.formatTime(.infinity) == "0:00")
        #expect(AudioPlayerManager.shared.formatTime(-.infinity) == "0:00")
    }

    // MARK: - Track model (used alongside AudioPlayerManager)

    @Test func trackEqualityIsIDBased() {
        let id = UUID()
        let a = Track(id: id, title: "A", artist: "X", fileName: "f", fileExtension: "mp3")
        let b = Track(id: id, title: "B", artist: "Y", fileName: "g", fileExtension: "wav")
        #expect(a == b)
    }

    @Test func trackDefaultsAreSensible() {
        let t = Track(title: "Test", artist: "T", fileName: "f", fileExtension: "mp3")
        #expect(!t.isFavorite)
        #expect(t.playCount == 0)
        #expect(t.lastPlayed == nil)
        #expect(t.album == nil)
    }

    @Test func trackFileURLPointsIntoDocuments() {
        let t = Track(title: "X", artist: "Y", fileName: "myFile", fileExtension: "mp3")
        let url = t.fileURL
        #expect(url != nil)
        #expect(url?.lastPathComponent == "myFile.mp3")
        #expect(url?.path.contains("/Documents/") == true)
    }

    // MARK: - Track.artistNames

    private func track(artist: String) -> Track {
        Track(title: "t", artist: artist, fileName: "f", fileExtension: "mp3")
    }

    @Test func artistNamesSingleArtist() {
        #expect(track(artist: "Adele").artistNames == ["Adele"])
    }

    @Test func artistNamesSplitsOnAmpersand() {
        #expect(track(artist: "Drake & Future").artistNames == ["Drake", "Future"])
    }

    @Test func artistNamesSplitsOnFeatVariants() {
        #expect(track(artist: "Lana Del Rey feat. Weeknd").artistNames == ["Lana Del Rey", "Weeknd"])
        #expect(track(artist: "A ft. B").artistNames == ["A", "B"])
        #expect(track(artist: "A ft B").artistNames == ["A", "B"])
        #expect(track(artist: "A feat B").artistNames == ["A", "B"])
    }

    @Test func artistNamesSplitsOnXSeparator() {
        #expect(track(artist: "Alpha x Beta").artistNames == ["Alpha", "Beta"])
        #expect(track(artist: "Alpha X Beta").artistNames == ["Alpha", "Beta"])
    }

    @Test func artistNamesHandlesMultipleSeparators() {
        #expect(
            track(artist: "A & B feat. C ft. D x E").artistNames
                == ["A", "B", "C", "D", "E"]
        )
    }

    @Test func artistNamesDoesNotSplitInsideWords() {
        // "Xerox" contains an "x" but no separator (no surrounding spaces).
        #expect(track(artist: "Xerox").artistNames == ["Xerox"])
    }

    @Test func artistNamesTrimsAndFiltersEmpties() {
        #expect(track(artist: "  Adele  ").artistNames == ["Adele"])
        #expect(track(artist: "").artistNames == [])
    }
}
