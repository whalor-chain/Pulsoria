import Testing
import Foundation
@testable import Pulsoria

@MainActor
struct GeniusManagerTests {

    // MARK: - cleanSearchString

    @Test func cleanSearchStringRemovesParens() {
        let gm = GeniusManager.shared
        #expect(gm.cleanSearchString("Song Name (feat. Artist)") == "Song Name")
        #expect(gm.cleanSearchString("Song (Remix)") == "Song")
        #expect(gm.cleanSearchString("Intro (prod. Foo)") == "Intro")
    }

    @Test func cleanSearchStringRemovesBrackets() {
        let gm = GeniusManager.shared
        #expect(gm.cleanSearchString("Track [Deluxe]") == "Track")
        #expect(gm.cleanSearchString("Album [Explicit] Title") == "Album  Title")
    }

    @Test func cleanSearchStringCombinesBoth() {
        let gm = GeniusManager.shared
        #expect(gm.cleanSearchString("Song (feat. X) [Remix]") == "Song")
    }

    @Test func cleanSearchStringLeavesCleanStringsAlone() {
        let gm = GeniusManager.shared
        #expect(gm.cleanSearchString("Simple Song") == "Simple Song")
        #expect(gm.cleanSearchString("") == "")
    }

    @Test func cleanSearchStringTrimsWhitespace() {
        let gm = GeniusManager.shared
        #expect(gm.cleanSearchString("  Song (feat. Y)  ") == "Song")
    }

    // MARK: - findBestMatch

    /// Build a minimal Genius-shaped hit payload.
    private func hit(title: String, artist: String, url: String) -> [String: Any] {
        [
            "result": [
                "title": title,
                "primary_artist": ["name": artist],
                "url": url
            ]
        ]
    }

    @Test func findBestMatchPrefersExactTitleAndArtist() {
        let gm = GeniusManager.shared
        let hits: [[String: Any]] = [
            hit(title: "Wrong Song", artist: "Wrong Artist", url: "https://genius.com/a"),
            hit(title: "Hello", artist: "Adele", url: "https://genius.com/b"),
            hit(title: "Hello Remix", artist: "Adele", url: "https://genius.com/c")
        ]
        let match = gm.findBestMatch(hits: hits, title: "Hello", artist: "Adele")
        #expect(match?.absoluteString == "https://genius.com/b")
    }

    @Test func findBestMatchReturnsNilBelowThreshold() {
        let gm = GeniusManager.shared
        let hits: [[String: Any]] = [
            hit(title: "Something Else", artist: "Other", url: "https://genius.com/x")
        ]
        #expect(gm.findBestMatch(hits: hits, title: "Hello", artist: "Adele") == nil)
    }

    @Test func findBestMatchIsCaseInsensitive() {
        let gm = GeniusManager.shared
        let hits: [[String: Any]] = [
            hit(title: "HELLO", artist: "ADELE", url: "https://genius.com/upper")
        ]
        let match = gm.findBestMatch(hits: hits, title: "hello", artist: "adele")
        #expect(match?.absoluteString == "https://genius.com/upper")
    }

    @Test func findBestMatchAcceptsSubstringMatch() {
        let gm = GeniusManager.shared
        // Title "Hello From The Other Side" contains "Hello" → 60 points.
        // Artist "Adele" matches exactly → +50. Total 110 ≥ 60.
        let hits: [[String: Any]] = [
            hit(title: "Hello From The Other Side", artist: "Adele", url: "https://genius.com/sub")
        ]
        let match = gm.findBestMatch(hits: hits, title: "Hello", artist: "Adele")
        #expect(match?.absoluteString == "https://genius.com/sub")
    }

    @Test func findBestMatchSkipsHitsWithoutURL() {
        let gm = GeniusManager.shared
        // Missing url field — the hit should be skipped (not crash).
        let hits: [[String: Any]] = [
            [
                "result": [
                    "title": "Hello",
                    "primary_artist": ["name": "Adele"]
                    // no "url"
                ]
            ],
            hit(title: "Hello", artist: "Adele", url: "https://genius.com/ok")
        ]
        let match = gm.findBestMatch(hits: hits, title: "Hello", artist: "Adele")
        #expect(match?.absoluteString == "https://genius.com/ok")
    }

    // MARK: - parseLRC

    @Test func parseLRCBasicLine() {
        let gm = GeniusManager.shared
        let lrc = "[00:12.34]Hello world"
        let lines = gm.parseLRC(lrc)
        #expect(lines.count == 1)
        #expect(abs(lines[0].time - 12.34) < 0.001)
        #expect(lines[0].text == "Hello world")
        #expect(!lines[0].isSection)
    }

    @Test func parseLRCSortsByTime() {
        let gm = GeniusManager.shared
        let lrc = """
        [01:00.00]Second
        [00:30.00]First
        [01:30.00]Third
        """
        let lines = gm.parseLRC(lrc)
        #expect(lines.map(\.text) == ["First", "Second", "Third"])
    }

    @Test func parseLRCHandlesMillisecondsVsCentiseconds() {
        let gm = GeniusManager.shared
        // 2-digit fraction = centiseconds (/100), 3-digit = milliseconds (/1000).
        let centi = gm.parseLRC("[00:10.50]x")
        #expect(abs(centi[0].time - 10.5) < 0.001)

        let milli = gm.parseLRC("[00:10.500]x")
        #expect(abs(milli[0].time - 10.5) < 0.001)

        let milli250 = gm.parseLRC("[00:10.250]x")
        #expect(abs(milli250[0].time - 10.25) < 0.001)
    }

    @Test func parseLRCSkipsMalformedLines() {
        let gm = GeniusManager.shared
        let lrc = """
        not a timestamped line
        [00:05.00]valid
        [broken]also invalid
        """
        let lines = gm.parseLRC(lrc)
        #expect(lines.count == 1)
        #expect(lines[0].text == "valid")
    }

    @Test func parseLRCSkipsEmptyText() {
        let gm = GeniusManager.shared
        let lrc = "[00:00.00]\n[00:05.00]hello"
        let lines = gm.parseLRC(lrc)
        #expect(lines.count == 1)
        #expect(lines[0].text == "hello")
    }

    @Test func parseLRCDetectsSectionHeaders() {
        let gm = GeniusManager.shared
        let lrc = "[00:00.00][Verse 1]\n[00:05.00]regular line"
        let lines = gm.parseLRC(lrc)
        #expect(lines.count == 2)
        #expect(lines[0].isSection)
        #expect(!lines[1].isSection)
    }

    // MARK: - parseLyrics (HTML → text)

    @Test func parseLyricsExtractsPlainText() {
        let gm = GeniusManager.shared
        let html = """
        <html><body>
        <div data-lyrics-container="true">Line one<br/>Line two<br>Line three</div>
        </body></html>
        """
        let result = gm.parseLyrics(from: html)
        #expect(result == "Line one\nLine two\nLine three")
    }

    @Test func parseLyricsDecodesHTMLEntities() {
        let gm = GeniusManager.shared
        let html = #"<div data-lyrics-container="true">Rock &amp; roll &#39;til we&#8217;re done</div>"#
        let result = gm.parseLyrics(from: html)
        #expect(result == "Rock & roll 'til we're done")
    }

    @Test func parseLyricsStripsInlineTags() {
        let gm = GeniusManager.shared
        let html = """
        <div data-lyrics-container="true"><i>Italic</i> and <b>bold</b> text</div>
        """
        let result = gm.parseLyrics(from: html)
        #expect(result == "Italic and bold text")
    }

    @Test func parseLyricsJoinsMultipleContainers() {
        let gm = GeniusManager.shared
        let html = """
        <div data-lyrics-container="true">Verse 1</div>
        <div>unrelated</div>
        <div data-lyrics-container="true">Chorus</div>
        """
        let result = gm.parseLyrics(from: html)
        #expect(result == "Verse 1\n\nChorus")
    }

    @Test func parseLyricsReturnsEmptyWhenNoContainer() {
        let gm = GeniusManager.shared
        let html = "<html><body>No lyrics here</body></html>"
        #expect(gm.parseLyrics(from: html) == "")
    }
}
