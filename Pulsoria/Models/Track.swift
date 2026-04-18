import Foundation

struct Track: Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let fileName: String
    let fileExtension: String
    var isFavorite: Bool
    var playCount: Int
    var lastPlayed: Date?
    var dateAdded: Date
    var album: String?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        fileName: String,
        fileExtension: String,
        isFavorite: Bool = false,
        playCount: Int = 0,
        lastPlayed: Date? = nil,
        dateAdded: Date = Date(),
        album: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.lastPlayed = lastPlayed
        self.dateAdded = dateAdded
        self.album = album
    }

    var fileURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent("\(fileName).\(fileExtension)")
    }

    /// Splits the `artist` field into individual artist names, handling the
    /// common collaboration separators: `&`, `feat./feat/ft./ft`, and `x/X`.
    /// Always returns trimmed, non-empty entries.
    var artistNames: [String] {
        artist
            .replacingOccurrences(of: " & ", with: ",")
            .replacingOccurrences(of: " feat. ", with: ",")
            .replacingOccurrences(of: " feat ", with: ",")
            .replacingOccurrences(of: " ft. ", with: ",")
            .replacingOccurrences(of: " ft ", with: ",")
            .replacingOccurrences(of: " x ", with: ",")
            .replacingOccurrences(of: " X ", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
