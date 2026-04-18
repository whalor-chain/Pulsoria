import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseStorage

@MainActor
class BeatStoreManager: ObservableObject {
    static let shared = BeatStoreManager()

    // MARK: - Published State

    @Published var allBeats: [Beat] = []
    @Published var searchText: String = ""
    @Published var selectedGenre: BeatGenre? = nil
    @Published var bpmRange: ClosedRange<Double> = 60...200
    @Published var selectedKey: MusicalKey? = nil
    @Published var priceRange: ClosedRange<Double> = 0...100
    @Published var isLoading: Bool = false
    @Published var uploadProgress: Double = 0

    @Published var userRole: UserRole {
        didSet { UserDefaults.standard.set(userRole.rawValue, forKey: "userRole") }
    }

    // Preview playback
    @Published var previewingBeatID: String? = nil
    @Published var previewProgress: Double = 0
    @Published var isPreviewPlaying: Bool = false

    private var previewTimer: Timer?
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?

    // MARK: - Computed

    var filteredBeats: [Beat] {
        allBeats.filter { beat in
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesTitle = beat.title.lowercased().contains(query)
                let matchesBeatmaker = beat.beatmakerName.lowercased().contains(query)
                if !matchesTitle && !matchesBeatmaker { return false }
            }
            if let genre = selectedGenre, beat.genre != genre { return false }
            if Double(beat.bpm) < bpmRange.lowerBound || Double(beat.bpm) > bpmRange.upperBound { return false }
            if let key = selectedKey, beat.key != key { return false }
            if beat.price < priceRange.lowerBound || beat.price > priceRange.upperBound { return false }
            return true
        }
    }

    var purchasedBeats: [Beat] {
        let userID = AuthManager.shared.appleUserID
        return allBeats.filter { $0.purchasedBy.contains(userID) }
    }

    var myBeats: [Beat] {
        let userID = AuthManager.shared.appleUserID
        return allBeats.filter { $0.uploaderID == userID }
    }

    // Stats
    var totalPurchasesCount: Int { purchasedBeats.count }
    var totalSpentAmount: Double { purchasedBeats.reduce(0) { $0 + $1.price } }
    var totalSalesCount: Int {
        let userID = AuthManager.shared.appleUserID
        return allBeats.filter { $0.uploaderID == userID }.reduce(0) { $0 + $1.purchasedBy.count }
    }
    var totalEarnedAmount: Double {
        let userID = AuthManager.shared.appleUserID
        return allBeats.filter { $0.uploaderID == userID }.reduce(0) { $0 + $1.price * Double($1.purchasedBy.count) }
    }
    var uploadedBeatsCount: Int { myBeats.count }

    // MARK: - Init

    private init() {
        let roleRaw = UserDefaults.standard.string(forKey: "userRole") ?? "Listener"
        self.userRole = UserRole(rawValue: roleRaw) ?? .listener
        startListening()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Firestore Realtime Listener

    func startListening() {
        isLoading = true
        listener?.remove()
        listener = db.collection("beats")
            .order(by: "dateAdded", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, let snapshot else {
                        self?.isLoading = false
                        return
                    }
                    self.allBeats = snapshot.documents.compactMap { doc in
                        try? doc.data(as: Beat.self)
                    }
                    self.isLoading = false
                }
            }
    }

    // MARK: - Upload Beat

    func uploadBeat(
        title: String,
        beatmakerName: String,
        genre: BeatGenre,
        bpm: Int,
        key: MusicalKey,
        price: Double,
        priceTON: Double = 0,
        coverImageData: Data?,
        coverImageName: String,
        audioFileURL: URL?
    ) async throws {
        let userID = AuthManager.shared.appleUserID
        let beatID = UUID().uuidString
        var coverURL: String? = nil
        var audioURL: String? = nil

        uploadProgress = 0

        // Upload cover image
        if let coverData = coverImageData {
            let coverRef = storage.reference().child("beats/\(beatID)/cover.jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await coverRef.putDataAsync(coverData, metadata: metadata)
            coverURL = try await coverRef.downloadURL().absoluteString
            uploadProgress = 0.3
        }

        // Upload audio file
        if let fileURL = audioFileURL {
            guard fileURL.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "BeatStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access file"])
            }
            defer { fileURL.stopAccessingSecurityScopedResource() }

            let audioData = try Data(contentsOf: fileURL)
            let ext = fileURL.pathExtension.isEmpty ? "mp3" : fileURL.pathExtension
            let audioRef = storage.reference().child("beats/\(beatID)/audio.\(ext)")
            let audioMeta = StorageMetadata()
            audioMeta.contentType = "audio/\(ext)"

            let uploadTask = audioRef.putData(audioData, metadata: audioMeta)

            // Track upload progress
            uploadTask.observe(.progress) { [weak self] snapshot in
                Task { @MainActor [weak self] in
                    if let progress = snapshot.progress {
                        self?.uploadProgress = 0.3 + (Double(progress.completedUnitCount) / Double(progress.totalUnitCount)) * 0.6
                    }
                }
            }

            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                uploadTask.observe(.success) { snapshot in
                    continuation.resume(returning: snapshot.metadata ?? StorageMetadata())
                }
                uploadTask.observe(.failure) { snapshot in
                    continuation.resume(throwing: snapshot.error ?? NSError(domain: "BeatStore", code: 2))
                }
            }

            audioURL = try await audioRef.downloadURL().absoluteString
            uploadProgress = 0.95
        }

        // Create Firestore document — id is the document path, not stored in body
        let beat = Beat(
            title: title,
            beatmakerName: beatmakerName,
            uploaderID: userID,
            genre: genre,
            bpm: bpm,
            key: key,
            price: price,
            priceTON: priceTON,
            durationSeconds: 0,
            coverImageName: coverImageName,
            coverImageURL: coverURL,
            audioURL: audioURL,
            dateAdded: Date()
        )

        try await db.collection("beats").document(beatID).setData(from: beat)
        uploadProgress = 1.0
    }

    // MARK: - Purchase Beat

    func purchaseBeat(_ beat: Beat) async throws {
        guard let beatID = beat.id else { return }
        let userID = AuthManager.shared.appleUserID
        guard !userID.isEmpty else { return }
        guard !beat.purchasedBy.contains(userID) else { return }

        try await db.collection("beats").document(beatID).updateData([
            "purchasedBy": FieldValue.arrayUnion([userID])
        ])
    }

    // MARK: - Delete Beat

    func deleteBeat(_ beat: Beat) async throws {
        guard let beatID = beat.id else { return }
        // Delete files from Storage
        let beatRef = storage.reference().child("beats/\(beatID)")
        let items = try await beatRef.listAll()
        for item in items.items {
            try await item.delete()
        }
        // Delete Firestore document
        try await db.collection("beats").document(beatID).delete()
    }

    // MARK: - Preview

    func startPreview(for beat: Beat) {
        stopPreview()
        previewingBeatID = beat.id
        previewProgress = 0
        isPreviewPlaying = true

        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.previewProgress += 0.1 / 30.0
                if self.previewProgress >= 1.0 {
                    self.stopPreview()
                }
            }
        }
    }

    func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        previewingBeatID = nil
        previewProgress = 0
        isPreviewPlaying = false
    }

    func resetFilters() {
        selectedGenre = nil
        bpmRange = 60...200
        selectedKey = nil
        priceRange = 0...100
        searchText = ""
    }

    var hasActiveFilters: Bool {
        selectedGenre != nil || selectedKey != nil ||
        bpmRange != 60...200 || priceRange != 0...100
    }

    // MARK: - Check if purchased

    func isBeatPurchased(_ beat: Beat) -> Bool {
        let userID = AuthManager.shared.appleUserID
        return beat.purchasedBy.contains(userID)
    }

    func isBeatMine(_ beat: Beat) -> Bool {
        let userID = AuthManager.shared.appleUserID
        return beat.uploaderID == userID
    }
}
