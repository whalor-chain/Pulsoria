import Testing
import Foundation
@testable import Pulsoria

@MainActor
struct BeatStoreManagerTests {

    // MARK: - Fixtures

    private func makeBeat(
        id: String? = nil,
        title: String = "Test Beat",
        beatmakerName: String = "Tester",
        uploaderID: String = "seller-1",
        genre: BeatGenre = .trap,
        bpm: Int = 140,
        key: MusicalKey = .cMinor,
        price: Double = 10,
        purchasedBy: [String] = []
    ) -> Beat {
        Beat(
            id: id,
            title: title,
            beatmakerName: beatmakerName,
            uploaderID: uploaderID,
            genre: genre,
            bpm: bpm,
            key: key,
            price: price,
            durationSeconds: 120,
            purchasedBy: purchasedBy
        )
    }

    /// Runs `body` with the store and auth singletons in a controlled state
    /// and restores everything on exit so tests don't pollute each other.
    private func withStore(
        beats: [Beat] = [],
        searchText: String = "",
        genre: BeatGenre? = nil,
        bpmRange: ClosedRange<Double> = 60...200,
        key: MusicalKey? = nil,
        priceRange: ClosedRange<Double> = 0...100,
        userID: String = "",
        _ body: (BeatStoreManager) -> Void
    ) {
        let store = BeatStoreManager.shared
        let auth = AuthManager.shared

        let originalBeats = store.allBeats
        let originalSearch = store.searchText
        let originalGenre = store.selectedGenre
        let originalBPM = store.bpmRange
        let originalKey = store.selectedKey
        let originalPrice = store.priceRange
        let originalUserID = auth.appleUserID

        defer {
            store.allBeats = originalBeats
            store.searchText = originalSearch
            store.selectedGenre = originalGenre
            store.bpmRange = originalBPM
            store.selectedKey = originalKey
            store.priceRange = originalPrice
            auth.appleUserID = originalUserID
        }

        store.allBeats = beats
        store.searchText = searchText
        store.selectedGenre = genre
        store.bpmRange = bpmRange
        store.selectedKey = key
        store.priceRange = priceRange
        auth.appleUserID = userID

        body(store)
    }

    // MARK: - filteredBeats

    @Test func filteredBeatsWithNoFiltersReturnsAll() {
        let beats = [makeBeat(id: "a"), makeBeat(id: "b"), makeBeat(id: "c")]
        withStore(beats: beats) { store in
            #expect(store.filteredBeats.count == 3)
        }
    }

    @Test func searchTextMatchesTitleOrBeatmaker() {
        let beats = [
            makeBeat(id: "1", title: "Dark Trap Anthem", beatmakerName: "Alpha"),
            makeBeat(id: "2", title: "Chill Vibes", beatmakerName: "Beta"),
            makeBeat(id: "3", title: "Soft Melody", beatmakerName: "Dark Wave")
        ]
        withStore(beats: beats, searchText: "dark") { store in
            // Matches "Dark Trap Anthem" (title) and "Dark Wave" (beatmaker).
            let ids = Set(store.filteredBeats.compactMap(\.id))
            #expect(ids == ["1", "3"])
        }
    }

    @Test func searchTextIsCaseInsensitive() {
        let beats = [makeBeat(id: "x", title: "LoFi Night")]
        withStore(beats: beats, searchText: "LOFI") { store in
            #expect(store.filteredBeats.count == 1)
        }
    }

    @Test func genreFilter() {
        let beats = [
            makeBeat(id: "t", genre: .trap),
            makeBeat(id: "p", genre: .pop),
            makeBeat(id: "d", genre: .drill)
        ]
        withStore(beats: beats, genre: .pop) { store in
            #expect(store.filteredBeats.map(\.id) == ["p"])
        }
    }

    @Test func bpmRangeFilterIsInclusive() {
        let beats = [
            makeBeat(id: "low", bpm: 70),
            makeBeat(id: "mid", bpm: 120),
            makeBeat(id: "high", bpm: 180)
        ]
        withStore(beats: beats, bpmRange: 100...150) { store in
            #expect(store.filteredBeats.map(\.id) == ["mid"])
        }
        withStore(beats: beats, bpmRange: 70...180) { store in
            #expect(Set(store.filteredBeats.compactMap(\.id)) == ["low", "mid", "high"])
        }
    }

    @Test func keyFilter() {
        let beats = [
            makeBeat(id: "cm", key: .cMinor),
            makeBeat(id: "am", key: .aMinor)
        ]
        withStore(beats: beats, key: .aMinor) { store in
            #expect(store.filteredBeats.map(\.id) == ["am"])
        }
    }

    @Test func priceRangeFilter() {
        let beats = [
            makeBeat(id: "cheap", price: 5),
            makeBeat(id: "mid", price: 25),
            makeBeat(id: "expensive", price: 90)
        ]
        withStore(beats: beats, priceRange: 10...50) { store in
            #expect(store.filteredBeats.map(\.id) == ["mid"])
        }
    }

    @Test func multipleFiltersCompose() {
        let beats = [
            makeBeat(id: "match", genre: .trap, bpm: 140, key: .cMinor, price: 20),
            makeBeat(id: "wrongGenre", genre: .pop, bpm: 140, key: .cMinor, price: 20),
            makeBeat(id: "wrongBPM", genre: .trap, bpm: 80, key: .cMinor, price: 20),
            makeBeat(id: "wrongKey", genre: .trap, bpm: 140, key: .aMinor, price: 20),
            makeBeat(id: "wrongPrice", genre: .trap, bpm: 140, key: .cMinor, price: 80)
        ]
        withStore(
            beats: beats,
            genre: .trap,
            bpmRange: 120...160,
            key: .cMinor,
            priceRange: 0...30
        ) { store in
            #expect(store.filteredBeats.map(\.id) == ["match"])
        }
    }

    // MARK: - purchasedBeats / myBeats

    @Test func purchasedBeatsMatchCurrentUser() {
        let beats = [
            makeBeat(id: "bought", purchasedBy: ["user-1"]),
            makeBeat(id: "otherBuyer", purchasedBy: ["user-2"]),
            makeBeat(id: "unbought", purchasedBy: [])
        ]
        withStore(beats: beats, userID: "user-1") { store in
            #expect(store.purchasedBeats.map(\.id) == ["bought"])
        }
    }

    @Test func myBeatsMatchUploaderID() {
        let beats = [
            makeBeat(id: "mine1", uploaderID: "me"),
            makeBeat(id: "someoneElse", uploaderID: "other"),
            makeBeat(id: "mine2", uploaderID: "me")
        ]
        withStore(beats: beats, userID: "me") { store in
            #expect(Set(store.myBeats.compactMap(\.id)) == ["mine1", "mine2"])
        }
    }

    @Test func purchasedCountsAndTotals() {
        let beats = [
            makeBeat(id: "a", price: 9.99, purchasedBy: ["me"]),
            makeBeat(id: "b", price: 15, purchasedBy: ["me", "someoneElse"]),
            makeBeat(id: "c", price: 30, purchasedBy: ["me"]),
            makeBeat(id: "d", price: 100, purchasedBy: ["other"])
        ]
        withStore(beats: beats, userID: "me") { store in
            #expect(store.totalPurchasesCount == 3)
            #expect(abs(store.totalSpentAmount - (9.99 + 15 + 30)) < 0.0001)
        }
    }

    @Test func salesCountsAndEarnings() {
        // Seller uploaded 2 beats; one sold to 3 people, one to 1.
        let beats = [
            makeBeat(id: "s1", uploaderID: "seller", price: 10, purchasedBy: ["a", "b", "c"]),
            makeBeat(id: "s2", uploaderID: "seller", price: 5, purchasedBy: ["d"]),
            makeBeat(id: "external", uploaderID: "someoneElse", price: 100, purchasedBy: ["x"])
        ]
        withStore(beats: beats, userID: "seller") { store in
            #expect(store.totalSalesCount == 4) // 3 + 1
            #expect(abs(store.totalEarnedAmount - (10 * 3 + 5 * 1)) < 0.0001)
            #expect(store.uploadedBeatsCount == 2)
        }
    }

    // MARK: - isBeatPurchased / isBeatMine

    @Test func isBeatPurchasedReflectsMembership() {
        let beat = makeBeat(id: "x", purchasedBy: ["buyer"])
        withStore(beats: [beat], userID: "buyer") { store in
            #expect(store.isBeatPurchased(beat))
        }
        withStore(beats: [beat], userID: "stranger") { store in
            #expect(!store.isBeatPurchased(beat))
        }
    }

    @Test func isBeatMineComparesUploader() {
        let beat = makeBeat(id: "x", uploaderID: "alice")
        withStore(beats: [beat], userID: "alice") { store in
            #expect(store.isBeatMine(beat))
        }
        withStore(beats: [beat], userID: "bob") { store in
            #expect(!store.isBeatMine(beat))
        }
    }

    // MARK: - hasActiveFilters / resetFilters

    @Test func hasActiveFiltersIsFalseAtDefaults() {
        withStore() { store in
            #expect(!store.hasActiveFilters)
        }
    }

    @Test func hasActiveFiltersTrueAfterAnyChange() {
        withStore(genre: .trap) { store in
            #expect(store.hasActiveFilters)
        }
        withStore(bpmRange: 100...140) { store in
            #expect(store.hasActiveFilters)
        }
        withStore(key: .cMinor) { store in
            #expect(store.hasActiveFilters)
        }
        withStore(priceRange: 10...50) { store in
            #expect(store.hasActiveFilters)
        }
    }

    @Test func resetFiltersRestoresDefaults() {
        withStore(
            searchText: "anything",
            genre: .drill,
            bpmRange: 130...160,
            key: .eMinor,
            priceRange: 5...20
        ) { store in
            store.resetFilters()
            #expect(!store.hasActiveFilters)
            #expect(store.searchText.isEmpty)
            #expect(store.selectedGenre == nil)
            #expect(store.bpmRange == 60...200)
            #expect(store.selectedKey == nil)
            #expect(store.priceRange == 0...100)
        }
    }
}
