import Testing
import Foundation
import FirebaseFirestore
@testable import Pulsoria

struct BeatTests {

    // MARK: - Factory

    private func makeBeat(
        id: String? = nil,
        price: Double = 9.99,
        priceTON: Double = 0,
        durationSeconds: Int = 125
    ) -> Beat {
        Beat(
            id: id,
            title: "Test Beat",
            beatmakerName: "Tester",
            uploaderID: "u-123",
            genre: .trap,
            bpm: 140,
            key: .cMinor,
            price: price,
            priceTON: priceTON,
            durationSeconds: durationSeconds,
            dateAdded: Date(timeIntervalSince1970: 1_700_000_000),
            purchasedBy: ["alice", "bob"]
        )
    }

    // MARK: - Formatting

    @Test func formattedPriceHasTwoDecimals() {
        #expect(makeBeat(price: 9.99).formattedPrice == "$9.99")
        #expect(makeBeat(price: 10).formattedPrice == "$10.00")
        #expect(makeBeat(price: 0).formattedPrice == "$0.00")
    }

    @Test func formattedPriceTONIsEmptyWhenZero() {
        #expect(makeBeat(priceTON: 0).formattedPriceTON == "")
    }

    @Test func formattedPriceTONIsFormattedWhenPositive() {
        #expect(makeBeat(priceTON: 2.5).formattedPriceTON == "2.50 TON")
        #expect(makeBeat(priceTON: 10).formattedPriceTON == "10.00 TON")
    }

    @Test func formattedDurationPadsSeconds() {
        #expect(makeBeat(durationSeconds: 0).formattedDuration == "0:00")
        #expect(makeBeat(durationSeconds: 5).formattedDuration == "0:05")
        #expect(makeBeat(durationSeconds: 65).formattedDuration == "1:05")
        #expect(makeBeat(durationSeconds: 3725).formattedDuration == "62:05")
    }

    // MARK: - Defaults

    @Test func defaultCoverImageNameUsed() {
        let beat = Beat(
            title: "x",
            beatmakerName: "y",
            genre: .pop,
            bpm: 100,
            key: .aMajor,
            price: 1,
            durationSeconds: 60
        )
        #expect(beat.coverImageName == "waveform.circle.fill")
        #expect(beat.purchasedBy.isEmpty)
        #expect(beat.priceTON == 0)
        #expect(beat.uploaderID == "")
    }

    // MARK: - Identity

    @Test func equalityIsByID() {
        let a = makeBeat(id: "beat-1")
        let b = Beat(
            id: "beat-1",
            title: "Different title",
            beatmakerName: "Different maker",
            genre: .rock,
            bpm: 1,
            key: .bMajor,
            price: 999,
            durationSeconds: 1
        )
        #expect(a == b)
    }

    @Test func differentIDsAreNotEqual() {
        #expect(makeBeat(id: "a") != makeBeat(id: "b"))
    }

    // MARK: - Codable (via Firestore.Encoder/Decoder)

    @Test func firestoreCodableRoundTripPreservesFields() throws {
        // id is not round-tripped here — @DocumentID is written by the
        // document *path*, not the body, so Firestore.Encoder strips it
        // on encode and Firestore.Decoder populates it from the path on
        // decode. Body-only round trip is what we verify.
        let original = makeBeat(id: nil, price: 14.50, priceTON: 3, durationSeconds: 200)
        let encoded = try Firestore.Encoder().encode(original)
        let decoded = try Firestore.Decoder().decode(Beat.self, from: encoded)

        #expect(decoded.title == original.title)
        #expect(decoded.beatmakerName == original.beatmakerName)
        #expect(decoded.uploaderID == original.uploaderID)
        #expect(decoded.genre == original.genre)
        #expect(decoded.bpm == original.bpm)
        #expect(decoded.key == original.key)
        #expect(decoded.price == original.price)
        #expect(decoded.priceTON == original.priceTON)
        #expect(decoded.durationSeconds == original.durationSeconds)
        #expect(decoded.coverImageName == original.coverImageName)
        #expect(decoded.purchasedBy == original.purchasedBy)
        // Date is lossy via Firestore Timestamp (microsecond precision).
        #expect(abs(decoded.dateAdded.timeIntervalSince1970 - original.dateAdded.timeIntervalSince1970) < 0.001)
    }

    @Test func firestoreEncoderOmitsDocumentID() throws {
        let beat = makeBeat(id: "beat-x")
        let dict = try Firestore.Encoder().encode(beat)
        // @DocumentID must not appear in the document body — it's the document path.
        #expect(dict["id"] == nil)
    }

    // MARK: - Enums

    @Test func beatGenreCoversAllCases() {
        #expect(BeatGenre.allCases.count == 8)
        #expect(BeatGenre.trap.rawValue == "Trap")
    }

    @Test func musicalKeyCoversAllCases() {
        #expect(MusicalKey.allCases.count == 14)
    }

    @Test func userRolePermissions() {
        #expect(UserRole.beatmaker.canUpload)
        #expect(!UserRole.artist.canUpload)
        #expect(!UserRole.listener.canUpload)

        #expect(UserRole.beatmaker.canViewSales)
        #expect(!UserRole.artist.canViewSales)

        #expect(UserRole.artist.canViewPurchases)
        #expect(UserRole.beatmaker.canViewPurchases)
        #expect(!UserRole.listener.canViewPurchases)
    }
}
