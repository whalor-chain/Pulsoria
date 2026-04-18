import Testing
import Foundation
import CryptoKit
@testable import Pulsoria

struct NaClCryptoTests {

    // MARK: - Hex encoding

    @Test func hexRoundTrip() {
        let bytes: [UInt8] = [0x00, 0x01, 0x7f, 0x80, 0xff, 0xab, 0xcd]
        let hex = NaCl.hexEncode(bytes)
        #expect(hex == "00017f80ffabcd")
        #expect(NaCl.hexDecode(hex) == bytes)
    }

    @Test func hexDecodeRejectsOddLength() {
        #expect(NaCl.hexDecode("abc") == nil)
    }

    @Test func hexDecodeRejectsNonHex() {
        #expect(NaCl.hexDecode("zzzz") == nil)
    }

    // MARK: - Nonce

    @Test func randomNonceIs24Bytes() {
        let nonce = NaCl.randomNonce()
        #expect(nonce.count == 24)
    }

    @Test func randomNoncesDiffer() {
        let a = NaCl.randomNonce()
        let b = NaCl.randomNonce()
        #expect(a != b)
    }

    // MARK: - secretbox (symmetric)

    @Test func secretboxRoundTrip() {
        let key = [UInt8](repeating: 0x42, count: 32)
        let nonce = NaCl.randomNonce()
        let plaintext: [UInt8] = Array("hello pulsoria".utf8)

        let ciphertext = NaCl.secretbox(plaintext: plaintext, nonce: nonce, key: key)
        #expect(ciphertext.count == plaintext.count + 16) // +16 for Poly1305 MAC

        let decrypted = NaCl.secretboxOpen(box: ciphertext, nonce: nonce, key: key)
        #expect(decrypted == plaintext)
    }

    @Test func secretboxOpenRejectsWrongKey() {
        let key = [UInt8](repeating: 0x42, count: 32)
        let wrongKey = [UInt8](repeating: 0x43, count: 32)
        let nonce = NaCl.randomNonce()
        let plaintext: [UInt8] = Array("secret".utf8)

        let ciphertext = NaCl.secretbox(plaintext: plaintext, nonce: nonce, key: key)
        #expect(NaCl.secretboxOpen(box: ciphertext, nonce: nonce, key: wrongKey) == nil)
    }

    @Test func secretboxOpenRejectsTamperedCiphertext() {
        let key = [UInt8](repeating: 0x42, count: 32)
        let nonce = NaCl.randomNonce()
        let plaintext: [UInt8] = Array("integrity matters".utf8)

        var ciphertext = NaCl.secretbox(plaintext: plaintext, nonce: nonce, key: key)
        ciphertext[ciphertext.count / 2] ^= 0x01 // flip one bit
        #expect(NaCl.secretboxOpen(box: ciphertext, nonce: nonce, key: key) == nil)
    }

    // MARK: - box (asymmetric, Curve25519)

    @Test func boxRoundTrip() {
        let alicePriv = Curve25519.KeyAgreement.PrivateKey()
        let bobPriv = Curve25519.KeyAgreement.PrivateKey()
        let alicePubBytes = [UInt8](alicePriv.publicKey.rawRepresentation)
        let bobPubBytes = [UInt8](bobPriv.publicKey.rawRepresentation)

        let nonce = NaCl.randomNonce()
        let plaintext: [UInt8] = Array("from alice to bob".utf8)

        let sealed = NaCl.box(plaintext: plaintext, nonce: nonce, theirPublicKey: bobPubBytes, myPrivateKey: alicePriv)
        #expect(sealed != nil)

        let opened = NaCl.boxOpen(box: sealed!, nonce: nonce, theirPublicKey: alicePubBytes, myPrivateKey: bobPriv)
        #expect(opened == plaintext)
    }

    @Test func boxOpenRejectsWrongRecipient() {
        let alicePriv = Curve25519.KeyAgreement.PrivateKey()
        let bobPriv = Curve25519.KeyAgreement.PrivateKey()
        let evePriv = Curve25519.KeyAgreement.PrivateKey()
        let alicePubBytes = [UInt8](alicePriv.publicKey.rawRepresentation)
        let bobPubBytes = [UInt8](bobPriv.publicKey.rawRepresentation)

        let nonce = NaCl.randomNonce()
        let plaintext: [UInt8] = Array("private".utf8)

        let sealed = NaCl.box(plaintext: plaintext, nonce: nonce, theirPublicKey: bobPubBytes, myPrivateKey: alicePriv)
        #expect(sealed != nil)
        #expect(NaCl.boxOpen(box: sealed!, nonce: nonce, theirPublicKey: alicePubBytes, myPrivateKey: evePriv) == nil)
    }
}
