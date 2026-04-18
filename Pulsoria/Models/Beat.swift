import Foundation

// MARK: - Beat Genre

enum BeatGenre: String, CaseIterable, Codable, Identifiable {
    case trap = "Trap"
    case hiphop = "Hip-Hop"
    case rnb = "R&B"
    case pop = "Pop"
    case drill = "Drill"
    case lofi = "Lo-Fi"
    case electronic = "Electronic"
    case rock = "Rock"

    var id: String { rawValue }
}

// MARK: - Musical Key

enum MusicalKey: String, CaseIterable, Codable, Identifiable {
    case cMajor = "C Major"
    case cMinor = "C Minor"
    case dMajor = "D Major"
    case dMinor = "D Minor"
    case eMajor = "E Major"
    case eMinor = "E Minor"
    case fMajor = "F Major"
    case fMinor = "F Minor"
    case gMajor = "G Major"
    case gMinor = "G Minor"
    case aMajor = "A Major"
    case aMinor = "A Minor"
    case bMajor = "B Major"
    case bMinor = "B Minor"

    var id: String { rawValue }
}

// MARK: - User Role

enum UserRole: String, CaseIterable, Codable, Identifiable {
    case listener = "Listener"
    case artist = "Artist"
    case beatmaker = "Beatmaker"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .listener: return Loc.roleListener
        case .artist: return Loc.roleArtist
        case .beatmaker: return Loc.roleBeatmaker
        }
    }

    var icon: String {
        switch self {
        case .listener: return "headphones"
        case .artist: return "music.mic"
        case .beatmaker: return "pianokeys"
        }
    }

    var canUpload: Bool { self == .beatmaker }
    var canViewSales: Bool { self == .beatmaker }
    var canViewPurchases: Bool { self == .artist || self == .beatmaker }
}

// MARK: - Beat

struct Beat: Identifiable, Equatable, Codable, Hashable {
    var id: String
    let title: String
    let beatmakerName: String
    let uploaderID: String
    let genre: BeatGenre
    let bpm: Int
    let key: MusicalKey
    let price: Double
    let priceTON: Double
    let durationSeconds: Int
    let coverImageName: String
    var coverImageURL: String?
    var audioURL: String?
    let dateAdded: Date
    var isPurchased: Bool
    var purchasedBy: [String]

    init(
        id: String = UUID().uuidString,
        title: String,
        beatmakerName: String,
        uploaderID: String = "",
        genre: BeatGenre,
        bpm: Int,
        key: MusicalKey,
        price: Double,
        priceTON: Double = 0,
        durationSeconds: Int,
        coverImageName: String = "waveform.circle.fill",
        coverImageURL: String? = nil,
        audioURL: String? = nil,
        dateAdded: Date = Date(),
        isPurchased: Bool = false,
        purchasedBy: [String] = []
    ) {
        self.id = id
        self.title = title
        self.beatmakerName = beatmakerName
        self.uploaderID = uploaderID
        self.genre = genre
        self.bpm = bpm
        self.key = key
        self.price = price
        self.priceTON = priceTON
        self.durationSeconds = durationSeconds
        self.coverImageName = coverImageName
        self.coverImageURL = coverImageURL
        self.audioURL = audioURL
        self.dateAdded = dateAdded
        self.isPurchased = isPurchased
        self.purchasedBy = purchasedBy
    }

    var formattedPrice: String {
        String(format: "$%.2f", price)
    }

    var formattedPriceTON: String {
        priceTON > 0 ? String(format: "%.2f TON", priceTON) : ""
    }

    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func == (lhs: Beat, rhs: Beat) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Firestore Dictionary

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "title": title,
            "beatmakerName": beatmakerName,
            "uploaderID": uploaderID,
            "genre": genre.rawValue,
            "bpm": bpm,
            "key": key.rawValue,
            "price": price,
            "priceTON": priceTON,
            "durationSeconds": durationSeconds,
            "coverImageName": coverImageName,
            "dateAdded": dateAdded.timeIntervalSince1970,
            "purchasedBy": purchasedBy
        ]
        if let coverImageURL { data["coverImageURL"] = coverImageURL }
        if let audioURL { data["audioURL"] = audioURL }
        return data
    }

    static func from(id: String, data: [String: Any]) -> Beat? {
        guard let title = data["title"] as? String,
              let beatmakerName = data["beatmakerName"] as? String,
              let genreRaw = data["genre"] as? String,
              let genre = BeatGenre(rawValue: genreRaw),
              let bpm = data["bpm"] as? Int,
              let keyRaw = data["key"] as? String,
              let key = MusicalKey(rawValue: keyRaw),
              let price = data["price"] as? Double,
              let durationSeconds = data["durationSeconds"] as? Int,
              let dateAddedTimestamp = data["dateAdded"] as? Double
        else { return nil }

        return Beat(
            id: id,
            title: title,
            beatmakerName: beatmakerName,
            uploaderID: data["uploaderID"] as? String ?? "",
            genre: genre,
            bpm: bpm,
            key: key,
            price: price,
            priceTON: data["priceTON"] as? Double ?? 0,
            durationSeconds: durationSeconds,
            coverImageName: data["coverImageName"] as? String ?? "waveform.circle.fill",
            coverImageURL: data["coverImageURL"] as? String,
            audioURL: data["audioURL"] as? String,
            dateAdded: Date(timeIntervalSince1970: dateAddedTimestamp),
            purchasedBy: data["purchasedBy"] as? [String] ?? []
        )
    }
}
