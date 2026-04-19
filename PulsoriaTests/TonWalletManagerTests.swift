import Testing
import Foundation
import CryptoKit
@testable import Pulsoria

@MainActor
struct TonWalletManagerTests {

    // MARK: - isValidTonAddress

    @Test func userFriendlyMainnetAddressIsValid() {
        let wallet = TonWalletManager.shared
        // Real TON user-friendly addresses are 48 chars, base64url, starting
        // with UQ (non-bounceable) or EQ (bounceable). Mainnet addresses.
        let uq = "UQAbcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRST"
        let eq = "EQAbcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRST"
        #expect(uq.count == 48)
        #expect(eq.count == 48)
        #expect(wallet.isValidTonAddress(uq))
        #expect(wallet.isValidTonAddress(eq))
    }

    @Test func rawFormatAddressIsValid() {
        let wallet = TonWalletManager.shared
        // Raw format: workchain:hex256 — e.g. "0:<64 hex chars>". Total length
        // is 66; the validator accepts any ":"-containing string of length
        // >= 64.
        let raw = "0:" + String(repeating: "a", count: 64)
        #expect(wallet.isValidTonAddress(raw))
    }

    @Test func tooShortAddressIsInvalid() {
        let wallet = TonWalletManager.shared
        #expect(!wallet.isValidTonAddress(""))
        #expect(!wallet.isValidTonAddress("UQ"))
        #expect(!wallet.isValidTonAddress("UQAbcdef")) // 8 chars
    }

    @Test func wrongPrefixIsInvalid() {
        let wallet = TonWalletManager.shared
        // Right length, wrong prefix.
        let notBase64 = "XYAbcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRST"
        #expect(notBase64.count == 48)
        #expect(!wallet.isValidTonAddress(notBase64))
    }

    @Test func trimsSurroundingWhitespace() {
        let wallet = TonWalletManager.shared
        let padded = "  UQAbcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRST  \n"
        #expect(wallet.isValidTonAddress(padded))
    }

    @Test func rawFormatTooShortIsInvalid() {
        let wallet = TonWalletManager.shared
        let shortRaw = "0:abc" // has ":" but only 5 chars
        #expect(!wallet.isValidTonAddress(shortRaw))
    }

    // MARK: - formattedBalance

    @Test func formattedBalanceShowsPlaceholderWhenNil() {
        let wallet = TonWalletManager.shared
        let original = wallet.balance
        defer { wallet.balance = original }

        wallet.balance = nil
        #expect(wallet.formattedBalance == "...")
    }

    @Test func formattedBalanceHasTwoDecimals() {
        let wallet = TonWalletManager.shared
        let original = wallet.balance
        defer { wallet.balance = original }

        wallet.balance = 0
        #expect(wallet.formattedBalance == "0.00 TON")

        wallet.balance = 1.5
        #expect(wallet.formattedBalance == "1.50 TON")

        wallet.balance = 123.456
        // %.2f rounds half-to-even in Swift; 123.456 formats as "123.46".
        #expect(wallet.formattedBalance == "123.46 TON")
    }

    // MARK: - TonError

    @Test func tonErrorDescriptionsAreHuman() {
        #expect(TonError.invalidAddress.errorDescription == "Invalid TON wallet address")
        #expect(TonError.noWalletApp.errorDescription == "No TON wallet app installed (Tonkeeper)")
        #expect(TonError.transactionFailed.errorDescription == "Transaction verification failed")
    }

    // MARK: - TonConnectSession

    @Test func sessionCreateProducesFresh32ByteKey() {
        let session = TonConnectSession.create()
        // Curve25519 private keys are 32 bytes.
        #expect(session.privateKeyData.count == 32)
        // Public key hex should be 64 chars (32 bytes * 2).
        #expect(session.publicKeyHex.count == 64)
        // Wallet fields are empty until a wallet connects.
        #expect(session.walletPublicKeyHex == nil)
        #expect(session.walletAddress == nil)
    }

    @Test func sessionPrivateKeyRoundTrip() throws {
        let session = TonConnectSession.create()
        let key = try #require(session.privateKey)
        // The reconstructed private key's raw representation matches the stored bytes.
        #expect(key.rawRepresentation == session.privateKeyData)
    }

    @Test func sessionsAreIndependent() {
        let a = TonConnectSession.create()
        let b = TonConnectSession.create()
        // Fresh Curve25519 keys must differ across calls.
        #expect(a.privateKeyData != b.privateKeyData)
        #expect(a.publicKeyHex != b.publicKeyHex)
    }

    @Test func sessionEncodesAndDecodes() throws {
        var session = TonConnectSession.create()
        session.walletAddress = "UQAbcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRST"
        session.walletPublicKeyHex = "deadbeef"

        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(TonConnectSession.self, from: encoded)

        #expect(decoded.privateKeyData == session.privateKeyData)
        #expect(decoded.publicKeyHex == session.publicKeyHex)
        #expect(decoded.walletAddress == session.walletAddress)
        #expect(decoded.walletPublicKeyHex == session.walletPublicKeyHex)
    }
}
