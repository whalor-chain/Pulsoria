import Foundation

struct Playlist: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var trackFileNames: [String]
    let isAutoFavorites: Bool

    init(
        id: UUID = UUID(),
        name: String,
        trackFileNames: [String] = [],
        isAutoFavorites: Bool = false
    ) {
        self.id = id
        self.name = name
        self.trackFileNames = trackFileNames
        self.isAutoFavorites = isAutoFavorites
    }

    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
}
