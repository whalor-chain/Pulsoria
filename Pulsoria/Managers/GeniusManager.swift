import Foundation
import SwiftUI
import Combine

// MARK: - Synced Lyrics Line

struct SyncedLyricLine: Identifiable {
    let id = UUID()
    let time: TimeInterval  // in seconds
    let text: String
    let isSection: Bool     // [Chorus], [Verse 1], etc.
}

struct GeniusArtistInfo {
    let name: String
    let imageURL: URL?
    let description: String?
    let instagramName: String?
    let twitterName: String?
    let facebookName: String?
}

struct GeniusSongInfo {
    let title: String
    let artist: String
    let albumName: String?
    let releaseDate: String?
    let thumbnailURL: URL?
    let pageURL: URL?
}

@MainActor
class GeniusManager: ObservableObject {
    static let shared = GeniusManager()

    @Published var artistInfo: GeniusArtistInfo?
    @Published var songInfo: GeniusSongInfo?
    @Published var isLoading = false
    @Published var error: String?

    // Cache for artist card previews (keyed by lowercased artist name)
    @Published var cachedArtistImages: [String: URL] = [:]
    @Published var cachedArtistBios: [String: String] = [:]
    private var prefetchedArtists: Set<String> = []

    // Album cache (keyed by track fileName)
    var cachedAlbumNames: [String: String] = [:] // fileName -> albumName
    var cachedAlbumArtwork: [String: URL] = [:] // albumName.lowercased -> artworkURL
    var cachedAlbumReleaseDate: [String: String] = [:] // albumName.lowercased -> release date
    var cachedAlbumArtist: [String: String] = [:] // albumName.lowercased -> primary artist name
    private var albumFetchedTracks: Set<String> = []

    // Lyrics cache (keyed by "title - artist" lowercased)
    @Published var cachedLyrics: [String: String] = [:]
    @Published var cachedSyncedLyrics: [String: [SyncedLyricLine]] = [:]
    @Published var isLoadingLyrics = false


    let token = "gB3kEDDXSGWhF9CKBO9DaKvkjTsgJ41GxFYbAnEOIwgJd0AqckDNyqc6amq7_yhR"

    var hasToken: Bool { true }

    private let baseURL = "https://api.genius.com"

    // MARK: - Search Artist

    func fetchArtistInfo(name: String) async {
        guard hasToken else { return }

        isLoading = true
        error = nil
        artistInfo = nil

        do {
            // Step 1: Search for artist
            let searchResult = try await searchArtist(query: name)
            guard let artistID = searchResult else {
                isLoading = false
                return
            }

            // Step 2: Get artist details
            let info = try await getArtistDetails(id: artistID)
            artistInfo = info
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Search Song

    func fetchSongInfo(title: String, artist: String) async {
        guard hasToken else { return }

        isLoading = true
        songInfo = nil

        do {
            let query = "\(title) \(artist)"
            guard let url = URL(string: "\(baseURL)/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let response = json?["response"] as? [String: Any]
            let hits = response?["hits"] as? [[String: Any]]

            if let firstHit = hits?.first,
               let result = firstHit["result"] as? [String: Any] {
                let songTitle = result["title"] as? String ?? title
                let primaryArtist = result["primary_artist"] as? [String: Any]
                let artistName = primaryArtist?["name"] as? String ?? artist
                let albumInfo = result["album"] as? [String: Any]
                let albumName = albumInfo?["name"] as? String
                let releaseDateStr = result["release_date_for_display"] as? String
                let thumbnailStr = result["song_art_image_thumbnail_url"] as? String
                let pageStr = result["url"] as? String

                songInfo = GeniusSongInfo(
                    title: songTitle,
                    artist: artistName,
                    albumName: albumName,
                    releaseDate: releaseDateStr,
                    thumbnailURL: thumbnailStr.flatMap { URL(string: $0) },
                    pageURL: pageStr.flatMap { URL(string: $0) }
                )
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Private

    private func searchArtist(query: String) async throws -> Int? {
        guard let url = URL(string: "\(baseURL)/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = json?["response"] as? [String: Any]
        let hits = response?["hits"] as? [[String: Any]]

        // Find artist ID from search results
        for hit in hits ?? [] {
            if let result = hit["result"] as? [String: Any],
               let primaryArtist = result["primary_artist"] as? [String: Any],
               let name = primaryArtist["name"] as? String,
               name.lowercased() == query.lowercased() || name.lowercased().contains(query.lowercased()),
               let id = primaryArtist["id"] as? Int {
                return id
            }
        }

        // Fallback: use first result's artist
        if let firstHit = hits?.first,
           let result = firstHit["result"] as? [String: Any],
           let primaryArtist = result["primary_artist"] as? [String: Any],
           let id = primaryArtist["id"] as? Int {
            return id
        }

        return nil
    }

    // MARK: - Prefetch for Artist Card

    func prefetchArtists(from artistString: String) async {
        let artists = artistString
            .components(separatedBy: CharacterSet(charactersIn: ",&"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for artist in artists {
            let key = artist.lowercased()
            guard !prefetchedArtists.contains(key) else { continue }
            prefetchedArtists.insert(key)

            do {
                guard let searchURL = URL(string: "\(baseURL)/search?q=\(artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { continue }

                var request = URLRequest(url: searchURL)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (data, _) = try await URLSession.shared.data(for: request)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let response = json?["response"] as? [String: Any]
                let hits = response?["hits"] as? [[String: Any]]

                var foundID: Int?
                for hit in hits ?? [] {
                    if let result = hit["result"] as? [String: Any],
                       let primaryArtist = result["primary_artist"] as? [String: Any],
                       let name = primaryArtist["name"] as? String,
                       name.lowercased().contains(key) || key.contains(name.lowercased()),
                       let id = primaryArtist["id"] as? Int {
                        foundID = id
                        break
                    }
                }

                // Fallback to first result
                if foundID == nil,
                   let firstHit = hits?.first,
                   let result = firstHit["result"] as? [String: Any],
                   let primaryArtist = result["primary_artist"] as? [String: Any],
                   let id = primaryArtist["id"] as? Int {
                    foundID = id
                }

                guard let artistID = foundID else { continue }

                // Fetch details
                guard let detailURL = URL(string: "\(baseURL)/artists/\(artistID)?text_format=plain") else { continue }
                var detailRequest = URLRequest(url: detailURL)
                detailRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (detailData, _) = try await URLSession.shared.data(for: detailRequest)
                let detailJSON = try JSONSerialization.jsonObject(with: detailData) as? [String: Any]
                let detailResponse = detailJSON?["response"] as? [String: Any]
                let artistObj = detailResponse?["artist"] as? [String: Any]

                if let imageStr = artistObj?["image_url"] as? String,
                   let imageURL = URL(string: imageStr) {
                    cachedArtistImages[key] = imageURL
                }

                if let descObj = artistObj?["description"] as? [String: Any],
                   let plain = descObj["plain"] as? String,
                   plain != "?" {
                    cachedArtistBios[key] = plain
                }
            } catch {
                // Silently fail
            }
        }
    }

    // MARK: - Prefetch All Albums

    private var albumsPrefetched = false

    func prefetchAllAlbums(tracks: [Track]) async {
        guard !albumsPrefetched else { return }
        albumsPrefetched = true

        // Fetch in batches of 5 to avoid overwhelming the API
        let unfetched = tracks.filter { !albumFetchedTracks.contains($0.fileName) }
        for batch in stride(from: 0, to: unfetched.count, by: 5) {
            let end = min(batch + 5, unfetched.count)
            let slice = unfetched[batch..<end]
            await withTaskGroup(of: Void.self) { group in
                for track in slice {
                    group.addTask {
                        _ = await self.fetchAlbumInfo(for: track)
                    }
                }
            }
        }
    }

    // MARK: - Fetch Album Info

    func fetchAlbumInfo(for track: Track) async -> String? {
        guard hasToken else { return nil }
        let key = track.fileName
        guard !albumFetchedTracks.contains(key) else {
            return cachedAlbumNames[key]
        }
        albumFetchedTracks.insert(key)

        do {
            let cleanTitle = cleanSearchString(track.title)
            let cleanArtist = track.artist
                .components(separatedBy: CharacterSet(charactersIn: ",&"))
                .first?
                .trimmingCharacters(in: .whitespaces) ?? track.artist

            let query = "\(cleanTitle) \(cleanArtist)"
            guard let url = URL(string: "\(baseURL)/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return nil }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let response = json?["response"] as? [String: Any]
            let hits = response?["hits"] as? [[String: Any]] ?? []

            // Try to find album from search results first
            for hit in hits {
                guard let result = hit["result"] as? [String: Any] else { continue }

                // Check if album is in search result
                if let albumObj = result["album"] as? [String: Any],
                   let albumName = albumObj["name"] as? String {
                    cachedAlbumNames[key] = albumName
                    let albumKey = albumName.lowercased()
                    if cachedAlbumArtwork[albumKey] == nil {
                        let artStr = (albumObj["cover_art_url"] as? String)
                            ?? (albumObj["cover_art_thumbnail_url"] as? String)
                        if let artStr, let artURL = URL(string: artStr) {
                            cachedAlbumArtwork[albumKey] = artURL
                        }
                    }
                    if cachedAlbumReleaseDate[albumKey] == nil,
                       let releaseDate = result["release_date_for_display"] as? String {
                        cachedAlbumReleaseDate[albumKey] = releaseDate
                    }
                    // Cache primary artist of the album
                    if cachedAlbumArtist[albumKey] == nil,
                       let primaryArtist = result["primary_artist"] as? [String: Any],
                       let artistName = primaryArtist["name"] as? String {
                        cachedAlbumArtist[albumKey] = artistName
                    }
                    return albumName
                }

                // Album not in search result — fetch song details by ID
                if let songID = result["id"] as? Int {
                    if let albumName = try await fetchSongAlbum(songID: songID) {
                        cachedAlbumNames[key] = albumName
                        return albumName
                    }
                }

                break // Only try first result
            }
        } catch {
            // Silently fail
        }

        return nil
    }

    /// Fetch full song details to get album info
    private func fetchSongAlbum(songID: Int) async throws -> String? {
        guard let url = URL(string: "\(baseURL)/songs/\(songID)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = json?["response"] as? [String: Any]
        let song = response?["song"] as? [String: Any]
        let albumObj = song?["album"] as? [String: Any]

        guard let albumName = albumObj?["name"] as? String else { return nil }

        let albumKey = albumName.lowercased()
        if cachedAlbumArtwork[albumKey] == nil {
            let artStr = (albumObj?["cover_art_url"] as? String)
                ?? (albumObj?["cover_art_thumbnail_url"] as? String)
            if let artStr, let artURL = URL(string: artStr) {
                cachedAlbumArtwork[albumKey] = artURL
            }
        }

        // Cache release date from song
        if cachedAlbumReleaseDate[albumKey] == nil,
           let releaseDate = song?["release_date_for_display"] as? String {
            cachedAlbumReleaseDate[albumKey] = releaseDate
        }

        // Cache primary artist of the album
        if cachedAlbumArtist[albumKey] == nil,
           let primaryArtist = song?["primary_artist"] as? [String: Any],
           let artistName = primaryArtist["name"] as? String {
            cachedAlbumArtist[albumKey] = artistName
        }

        return albumName
    }

    // MARK: - Fetch Synced Lyrics (LRCLIB)

    func fetchSyncedLyrics(title: String, artist: String) async {
        let cacheKey = "\(title) - \(artist)".lowercased()
        guard cachedSyncedLyrics[cacheKey] == nil else { return }

        isLoadingLyrics = true
        let cleanTitle = cleanSearchString(title)
        let cleanArtist = artist
            .components(separatedBy: CharacterSet(charactersIn: ",&"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? artist

        do {
            let query = "\(cleanTitle) \(cleanArtist)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            guard let url = URL(string: "https://lrclib.net/api/search?q=\(query)") else { return }

            var request = URLRequest(url: url)
            request.setValue("Pulsoria/1.0", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

            // Find best match
            let titleLower = cleanTitle.lowercased()
            let artistLower = cleanArtist.lowercased()

            var bestMatch: String?
            var bestScore = 0

            for result in results {
                guard let syncedLyrics = result["syncedLyrics"] as? String,
                      !syncedLyrics.isEmpty else { continue }

                let rTitle = (result["trackName"] as? String ?? "").lowercased()
                let rArtist = (result["artistName"] as? String ?? "").lowercased()

                var score = 0
                if rTitle == titleLower { score += 100 }
                else if rTitle.contains(titleLower) || titleLower.contains(rTitle) { score += 60 }

                if rArtist == artistLower { score += 50 }
                else if rArtist.contains(artistLower) || artistLower.contains(rArtist) { score += 30 }

                if score > bestScore {
                    bestScore = score
                    bestMatch = syncedLyrics
                }
            }

            // Fallback: use first result with synced lyrics
            if bestMatch == nil {
                bestMatch = results.first(where: { ($0["syncedLyrics"] as? String)?.isEmpty == false })?["syncedLyrics"] as? String
            }

            if let lrc = bestMatch {
                let lines = parseLRC(lrc)
                if !lines.isEmpty {
                    cachedSyncedLyrics[cacheKey] = lines
                    isLoadingLyrics = false
                    return
                }
            }
        } catch {
            // Silently fail — will fallback to Genius plain lyrics
        }
    }

    private func parseLRC(_ lrc: String) -> [SyncedLyricLine] {
        var lines: [SyncedLyricLine] = []
        let pattern = #"\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for rawLine in lrc.components(separatedBy: "\n") {
            let nsRange = NSRange(rawLine.startIndex..<rawLine.endIndex, in: rawLine)
            guard let match = regex.firstMatch(in: rawLine, range: nsRange) else { continue }

            guard let minRange = Range(match.range(at: 1), in: rawLine),
                  let secRange = Range(match.range(at: 2), in: rawLine),
                  let msRange = Range(match.range(at: 3), in: rawLine),
                  let textRange = Range(match.range(at: 4), in: rawLine) else { continue }

            let minutes = Double(rawLine[minRange]) ?? 0
            let seconds = Double(rawLine[secRange]) ?? 0
            let msStr = String(rawLine[msRange])
            let ms = (Double(msStr) ?? 0) / (msStr.count == 2 ? 100 : 1000)

            let time = minutes * 60 + seconds + ms
            let text = String(rawLine[textRange]).trimmingCharacters(in: .whitespaces)

            guard !text.isEmpty else { continue }

            let isSection = text.hasPrefix("[") && text.hasSuffix("]")
            lines.append(SyncedLyricLine(time: time, text: text, isSection: isSection))
        }

        return lines.sorted { $0.time < $1.time }
    }

    // MARK: - Fetch Lyrics (Genius fallback)

    func fetchLyrics(title: String, artist: String) async {
        let cacheKey = "\(title) - \(artist)".lowercased()
        guard cachedLyrics[cacheKey] == nil else { return }

        isLoadingLyrics = true

        do {
            // Clean title: remove "(feat. ...)", "[...]", etc.
            let cleanTitle = cleanSearchString(title)
            let cleanArtist = artist
                .components(separatedBy: CharacterSet(charactersIn: ",&"))
                .first?
                .trimmingCharacters(in: .whitespaces) ?? artist

            let query = "\(cleanTitle) \(cleanArtist)"
            guard let url = URL(string: "\(baseURL)/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
                isLoadingLyrics = false
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let response = json?["response"] as? [String: Any]
            let hits = response?["hits"] as? [[String: Any]] ?? []

            // Find best match among results
            let pageURL = findBestMatch(hits: hits, title: cleanTitle, artist: cleanArtist)

            guard let pageURL else {
                isLoadingLyrics = false
                return
            }

            // Fetch the Genius page HTML
            var pageRequest = URLRequest(url: pageURL)
            pageRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

            let (pageData, _) = try await URLSession.shared.data(for: pageRequest)
            guard let html = String(data: pageData, encoding: .utf8) else {
                isLoadingLyrics = false
                return
            }

            // Parse lyrics from HTML
            let lyrics = parseLyrics(from: html)
            if !lyrics.isEmpty {
                cachedLyrics[cacheKey] = lyrics
            }
        } catch {
            // Silently fail
        }

        isLoadingLyrics = false
    }

    private func cleanSearchString(_ str: String) -> String {
        var result = str
        // Remove content in parentheses: (feat. ...), (Remix), etc.
        while let open = result.range(of: "("),
              let close = result.range(of: ")", range: open.upperBound..<result.endIndex) {
            result.removeSubrange(open.lowerBound...close.lowerBound)
        }
        // Remove content in brackets: [Deluxe], [Explicit], etc.
        while let open = result.range(of: "["),
              let close = result.range(of: "]", range: open.upperBound..<result.endIndex) {
            result.removeSubrange(open.lowerBound...close.lowerBound)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private func findBestMatch(hits: [[String: Any]], title: String, artist: String) -> URL? {
        let titleLower = title.lowercased()
        let artistLower = artist.lowercased()

        struct ScoredResult {
            let url: URL
            let score: Int
        }

        var scored: [ScoredResult] = []

        for hit in hits {
            guard let result = hit["result"] as? [String: Any],
                  let resultTitle = result["title"] as? String,
                  let primaryArtist = result["primary_artist"] as? [String: Any],
                  let resultArtist = primaryArtist["name"] as? String,
                  let urlStr = result["url"] as? String,
                  let url = URL(string: urlStr) else { continue }

            let rTitle = resultTitle.lowercased()
            let rArtist = resultArtist.lowercased()
            var score = 0

            // Title matching
            if rTitle == titleLower {
                score += 100
            } else if rTitle.contains(titleLower) || titleLower.contains(rTitle) {
                score += 60
            } else {
                // Check word overlap
                let titleWords = Set(titleLower.components(separatedBy: .whitespaces))
                let resultWords = Set(rTitle.components(separatedBy: .whitespaces))
                let overlap = titleWords.intersection(resultWords).count
                if overlap > 0 {
                    score += overlap * 15
                } else {
                    continue // Skip if no title overlap at all
                }
            }

            // Artist matching
            if rArtist == artistLower {
                score += 50
            } else if rArtist.contains(artistLower) || artistLower.contains(rArtist) {
                score += 30
            }

            scored.append(ScoredResult(url: url, score: score))
        }

        // Return the best match, but only if score is reasonable
        guard let best = scored.max(by: { $0.score < $1.score }),
              best.score >= 60 else {
            return nil
        }

        return best.url
    }

    private func parseLyrics(from html: String) -> String {
        var lyrics = ""

        // Find all lyrics containers: data-lyrics-container="true"
        let containerPattern = "data-lyrics-container=\"true\""
        var searchRange = html.startIndex..<html.endIndex

        while let containerRange = html.range(of: containerPattern, range: searchRange) {
            // Find the closing > of this opening tag
            guard let tagClose = html.range(of: ">", range: containerRange.upperBound..<html.endIndex) else { break }

            // Find the matching </div> by tracking nested div depth
            let contentStart = tagClose.upperBound
            var depth = 1
            var cursor = contentStart
            var matchingClose: String.Index?

            while cursor < html.endIndex && depth > 0 {
                let remaining = cursor..<html.endIndex

                let nextOpen = html.range(of: "<div", options: .caseInsensitive, range: remaining)
                let nextClose = html.range(of: "</div>", options: .caseInsensitive, range: remaining)

                if let close = nextClose {
                    if let open = nextOpen, open.lowerBound < close.lowerBound {
                        // Found a nested <div before the next </div>
                        depth += 1
                        cursor = open.upperBound
                    } else {
                        // Found </div>
                        depth -= 1
                        if depth == 0 {
                            matchingClose = close.lowerBound
                        }
                        cursor = close.upperBound
                    }
                } else {
                    break
                }
            }

            guard let endIndex = matchingClose else {
                searchRange = tagClose.upperBound..<html.endIndex
                continue
            }

            var chunk = String(html[contentStart..<endIndex])

            // Replace <br/> and <br> with newlines
            chunk = chunk.replacingOccurrences(of: "<br/>", with: "\n")
            chunk = chunk.replacingOccurrences(of: "<br>", with: "\n")
            chunk = chunk.replacingOccurrences(of: "<br />", with: "\n")

            // Remove all HTML tags
            while let openTag = chunk.range(of: "<"),
                  let closeTag = chunk.range(of: ">", range: openTag.upperBound..<chunk.endIndex) {
                chunk.removeSubrange(openTag.lowerBound...closeTag.lowerBound)
            }

            // Decode common HTML entities
            chunk = chunk.replacingOccurrences(of: "&amp;", with: "&")
            chunk = chunk.replacingOccurrences(of: "&lt;", with: "<")
            chunk = chunk.replacingOccurrences(of: "&gt;", with: ">")
            chunk = chunk.replacingOccurrences(of: "&#x27;", with: "'")
            chunk = chunk.replacingOccurrences(of: "&quot;", with: "\"")
            chunk = chunk.replacingOccurrences(of: "&#39;", with: "'")
            chunk = chunk.replacingOccurrences(of: "&#8217;", with: "'")
            chunk = chunk.replacingOccurrences(of: "&apos;", with: "'")
            chunk = chunk.replacingOccurrences(of: "&#160;", with: " ")
            chunk = chunk.replacingOccurrences(of: "&nbsp;", with: " ")

            if !lyrics.isEmpty && !chunk.isEmpty {
                lyrics += "\n\n"
            }
            lyrics += chunk

            searchRange = (matchingClose ?? tagClose.upperBound)..<html.endIndex
        }

        return lyrics.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Fetch Song Artwork

    /// Searches Genius for a song and returns the artwork image data, if found.
    nonisolated func fetchSongArtworkData(title: String, artist: String) async -> Data? {
        let query = "\(title) \(artist)"
        guard let url = URL(string: "https://api.genius.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? [String: Any],
              let hits = response["hits"] as? [[String: Any]],
              let firstHit = hits.first,
              let result = firstHit["result"] as? [String: Any],
              let imageStr = result["song_art_image_url"] as? String,
              let imageURL = URL(string: imageStr) else { return nil }

        // Download the image
        guard let (imageData, _) = try? await URLSession.shared.data(from: imageURL) else { return nil }
        return imageData
    }

    private func getArtistDetails(id: Int) async throws -> GeniusArtistInfo? {
        guard let url = URL(string: "\(baseURL)/artists/\(id)?text_format=plain") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = json?["response"] as? [String: Any]
        let artist = response?["artist"] as? [String: Any]

        guard let artist else { return nil }

        let name = artist["name"] as? String ?? ""
        let imageStr = artist["image_url"] as? String
        let descObj = artist["description"] as? [String: Any]
        let description = descObj?["plain"] as? String
        let instagramName = artist["instagram_name"] as? String
        let twitterName = artist["twitter_name"] as? String
        let facebookName = artist["facebook_name"] as? String

        return GeniusArtistInfo(
            name: name,
            imageURL: imageStr.flatMap { URL(string: $0) },
            description: description,
            instagramName: instagramName,
            twitterName: twitterName,
            facebookName: facebookName
        )
    }
}
