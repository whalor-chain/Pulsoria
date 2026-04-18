import Foundation
import CryptoKit

// MARK: - NaCl Crypto Box (XSalsa20-Poly1305)
// Pure Swift implementation for TON Connect 2.0 protocol

enum NaCl {

    private static let sigma: [UInt8] = Array("expand 32-byte k".utf8)

    // MARK: - Helpers

    private static func loadLE32(_ data: [UInt8], _ i: Int) -> UInt32 {
        UInt32(data[i]) | UInt32(data[i+1]) << 8 | UInt32(data[i+2]) << 16 | UInt32(data[i+3]) << 24
    }

    private static func storeLE32(_ v: UInt32, _ out: inout [UInt8], _ i: Int) {
        out[i]   = UInt8(truncatingIfNeeded: v)
        out[i+1] = UInt8(truncatingIfNeeded: v >> 8)
        out[i+2] = UInt8(truncatingIfNeeded: v >> 16)
        out[i+3] = UInt8(truncatingIfNeeded: v >> 24)
    }

    private static func rotl(_ v: UInt32, _ c: Int) -> UInt32 {
        (v << c) | (v >> (32 - c))
    }

    // MARK: - Salsa20 Core Rounds (20 rounds in place)

    private static func salsa20Rounds(_ x: inout [UInt32]) {
        for _ in 0..<10 {
            // Column round
            x[ 4] ^= rotl(x[ 0] &+ x[12],  7); x[ 8] ^= rotl(x[ 4] &+ x[ 0],  9)
            x[12] ^= rotl(x[ 8] &+ x[ 4], 13); x[ 0] ^= rotl(x[12] &+ x[ 8], 18)
            x[ 9] ^= rotl(x[ 5] &+ x[ 1],  7); x[13] ^= rotl(x[ 9] &+ x[ 5],  9)
            x[ 1] ^= rotl(x[13] &+ x[ 9], 13); x[ 5] ^= rotl(x[ 1] &+ x[13], 18)
            x[14] ^= rotl(x[10] &+ x[ 6],  7); x[ 2] ^= rotl(x[14] &+ x[10],  9)
            x[ 6] ^= rotl(x[ 2] &+ x[14], 13); x[10] ^= rotl(x[ 6] &+ x[ 2], 18)
            x[ 3] ^= rotl(x[15] &+ x[11],  7); x[ 7] ^= rotl(x[ 3] &+ x[15],  9)
            x[11] ^= rotl(x[ 7] &+ x[ 3], 13); x[15] ^= rotl(x[11] &+ x[ 7], 18)
            // Row round
            x[ 1] ^= rotl(x[ 0] &+ x[ 3],  7); x[ 2] ^= rotl(x[ 1] &+ x[ 0],  9)
            x[ 3] ^= rotl(x[ 2] &+ x[ 1], 13); x[ 0] ^= rotl(x[ 3] &+ x[ 2], 18)
            x[ 6] ^= rotl(x[ 5] &+ x[ 4],  7); x[ 7] ^= rotl(x[ 6] &+ x[ 5],  9)
            x[ 4] ^= rotl(x[ 7] &+ x[ 6], 13); x[ 5] ^= rotl(x[ 4] &+ x[ 7], 18)
            x[11] ^= rotl(x[10] &+ x[ 9],  7); x[ 8] ^= rotl(x[11] &+ x[10],  9)
            x[ 9] ^= rotl(x[ 8] &+ x[11], 13); x[10] ^= rotl(x[ 9] &+ x[ 8], 18)
            x[12] ^= rotl(x[15] &+ x[14],  7); x[13] ^= rotl(x[12] &+ x[15],  9)
            x[14] ^= rotl(x[13] &+ x[12], 13); x[15] ^= rotl(x[14] &+ x[13], 18)
        }
    }

    // MARK: - HSalsa20 (key derivation, no final addition)

    static func hsalsa20(key: [UInt8], nonce: [UInt8]) -> [UInt8] {
        var x: [UInt32] = [
            loadLE32(sigma, 0),  loadLE32(key, 0),    loadLE32(key, 4),    loadLE32(key, 8),
            loadLE32(key, 12),   loadLE32(sigma, 4),   loadLE32(nonce, 0),  loadLE32(nonce, 4),
            loadLE32(nonce, 8),  loadLE32(nonce, 12),  loadLE32(sigma, 8),  loadLE32(key, 16),
            loadLE32(key, 20),   loadLE32(key, 24),    loadLE32(key, 28),   loadLE32(sigma, 12)
        ]
        salsa20Rounds(&x)
        var out = [UInt8](repeating: 0, count: 32)
        storeLE32(x[0],  &out, 0);  storeLE32(x[5],  &out, 4)
        storeLE32(x[10], &out, 8);  storeLE32(x[15], &out, 12)
        storeLE32(x[6],  &out, 16); storeLE32(x[7],  &out, 20)
        storeLE32(x[8],  &out, 24); storeLE32(x[9],  &out, 28)
        return out
    }

    // MARK: - Salsa20 Block (single 64-byte block)

    private static func salsa20Block(key: [UInt8], nonce: [UInt8], counter: UInt64) -> [UInt8] {
        var x: [UInt32] = [
            loadLE32(sigma, 0),  loadLE32(key, 0),   loadLE32(key, 4),   loadLE32(key, 8),
            loadLE32(key, 12),   loadLE32(sigma, 4),  loadLE32(nonce, 0), loadLE32(nonce, 4),
            UInt32(truncatingIfNeeded: counter), UInt32(truncatingIfNeeded: counter >> 32),
            loadLE32(sigma, 8),  loadLE32(key, 16),
            loadLE32(key, 20),   loadLE32(key, 24),   loadLE32(key, 28),  loadLE32(sigma, 12)
        ]
        let orig = x
        salsa20Rounds(&x)
        for i in 0..<16 { x[i] = x[i] &+ orig[i] }
        var out = [UInt8](repeating: 0, count: 64)
        for i in 0..<16 { storeLE32(x[i], &out, i * 4) }
        return out
    }

    // MARK: - XSalsa20 Keystream

    static func xsalsa20Stream(key: [UInt8], nonce: [UInt8], length: Int) -> [UInt8] {
        let subkey = hsalsa20(key: key, nonce: Array(nonce[0..<16]))
        let subnonce = Array(nonce[16..<24])
        var output = [UInt8]()
        output.reserveCapacity(length)
        var ctr: UInt64 = 0
        while output.count < length {
            let block = salsa20Block(key: subkey, nonce: subnonce, counter: ctr)
            output.append(contentsOf: block.prefix(length - output.count))
            ctr += 1
        }
        return output
    }

    // MARK: - Poly1305 One-Time MAC

    static func poly1305(message: [UInt8], key: [UInt8]) -> [UInt8] {
        // Clamp r (first 16 bytes of key)
        var rb = Array(key[0..<16])
        rb[3] &= 15; rb[7] &= 15; rb[11] &= 15; rb[15] &= 15
        rb[4] &= 252; rb[8] &= 252; rb[12] &= 252

        // Load r into 5 x 26-bit limbs
        let r0 = UInt64(loadLE32(rb, 0)) & 0x3ffffff
        let r1 = UInt64(loadLE32(rb, 3) >> 2) & 0x3ffffff
        let r2 = UInt64(loadLE32(rb, 6) >> 4) & 0x3ffffff
        let r3 = UInt64(loadLE32(rb, 9) >> 6) & 0x3ffffff
        let r4 = UInt64(loadLE32(rb, 12) >> 8) & 0x3ffffff
        let s1 = r1 &* 5, s2 = r2 &* 5, s3 = r3 &* 5, s4 = r4 &* 5

        var h0: UInt64 = 0, h1: UInt64 = 0, h2: UInt64 = 0, h3: UInt64 = 0, h4: UInt64 = 0

        var offset = 0
        while offset < message.count {
            let blockLen = min(16, message.count - offset)
            var buf = [UInt8](repeating: 0, count: 17)
            for i in 0..<blockLen { buf[i] = message[offset + i] }
            buf[blockLen] = 1 // padding bit

            let t0 = UInt64(loadLE32(buf, 0))
            let t1 = UInt64(loadLE32(buf, 4))
            let t2 = UInt64(loadLE32(buf, 8))
            let t3 = UInt64(loadLE32(buf, 12))
            let t4 = UInt64(buf[16])

            h0 += t0 & 0x3ffffff
            h1 += ((t0 >> 26) | (t1 << 6)) & 0x3ffffff
            h2 += ((t1 >> 20) | (t2 << 12)) & 0x3ffffff
            h3 += ((t2 >> 14) | (t3 << 18)) & 0x3ffffff
            h4 += (t3 >> 8) | (t4 << 24)

            // Multiply h * r mod 2^130 - 5
            let d0 = h0 &* r0 &+ h1 &* s4 &+ h2 &* s3 &+ h3 &* s2 &+ h4 &* s1
            var d1 = h0 &* r1 &+ h1 &* r0 &+ h2 &* s4 &+ h3 &* s3 &+ h4 &* s2
            var d2 = h0 &* r2 &+ h1 &* r1 &+ h2 &* r0 &+ h3 &* s4 &+ h4 &* s3
            var d3 = h0 &* r3 &+ h1 &* r2 &+ h2 &* r1 &+ h3 &* r0 &+ h4 &* s4
            let d4 = h0 &* r4 &+ h1 &* r3 &+ h2 &* r2 &+ h3 &* r1 &+ h4 &* r0

            // Carry propagation
            var c: UInt64
            c = d0 >> 26; h0 = d0 & 0x3ffffff; d1 &+= c
            c = d1 >> 26; h1 = d1 & 0x3ffffff; d2 &+= c
            c = d2 >> 26; h2 = d2 & 0x3ffffff; d3 &+= c
            c = d3 >> 26; h3 = d3 & 0x3ffffff
            let d4c = d4 &+ c
            c = d4c >> 26; h4 = d4c & 0x3ffffff; h0 &+= c &* 5
            c = h0 >> 26; h0 &= 0x3ffffff; h1 &+= c

            offset += blockLen
        }

        // Final reduction
        var c: UInt64
        c = h1 >> 26; h1 &= 0x3ffffff; h2 &+= c
        c = h2 >> 26; h2 &= 0x3ffffff; h3 &+= c
        c = h3 >> 26; h3 &= 0x3ffffff; h4 &+= c
        c = h4 >> 26; h4 &= 0x3ffffff; h0 &+= c &* 5
        c = h0 >> 26; h0 &= 0x3ffffff; h1 &+= c

        // Check if h >= p (2^130 - 5), if so subtract p
        var g0 = h0 &+ 5; c = g0 >> 26; g0 &= 0x3ffffff
        var g1 = h1 &+ c; c = g1 >> 26; g1 &= 0x3ffffff
        var g2 = h2 &+ c; c = g2 >> 26; g2 &= 0x3ffffff
        var g3 = h3 &+ c; c = g3 >> 26; g3 &= 0x3ffffff
        let g4 = h4 &+ c &- (1 << 26)

        // If g4 didn't underflow (bit 63 = 0), use g; otherwise keep h
        let mask = (g4 >> 63) &- 1 // 0xFFF...F if use g, 0 if keep h
        h0 = (h0 & ~mask) | (g0 & mask)
        h1 = (h1 & ~mask) | (g1 & mask)
        h2 = (h2 & ~mask) | (g2 & mask)
        h3 = (h3 & ~mask) | (g3 & mask)
        h4 = (h4 & ~mask) | (g4 & mask)

        // Convert 26-bit limbs to 32-bit words
        let w0 = UInt32(truncatingIfNeeded: h0 | (h1 << 26))
        let w1 = UInt32(truncatingIfNeeded: (h1 >> 6) | (h2 << 20))
        let w2 = UInt32(truncatingIfNeeded: (h2 >> 12) | (h3 << 14))
        let w3 = UInt32(truncatingIfNeeded: (h3 >> 18) | (h4 << 8))

        // Add pad (s = key[16..32])
        let p0 = loadLE32(key, 16), p1 = loadLE32(key, 20)
        let p2 = loadLE32(key, 24), p3 = loadLE32(key, 28)
        var f: UInt64
        f = UInt64(w0) &+ UInt64(p0); let tag0 = UInt32(truncatingIfNeeded: f)
        f = UInt64(w1) &+ UInt64(p1) &+ (f >> 32); let tag1 = UInt32(truncatingIfNeeded: f)
        f = UInt64(w2) &+ UInt64(p2) &+ (f >> 32); let tag2 = UInt32(truncatingIfNeeded: f)
        f = UInt64(w3) &+ UInt64(p3) &+ (f >> 32); let tag3 = UInt32(truncatingIfNeeded: f)

        var tag = [UInt8](repeating: 0, count: 16)
        storeLE32(tag0, &tag, 0); storeLE32(tag1, &tag, 4)
        storeLE32(tag2, &tag, 8); storeLE32(tag3, &tag, 12)
        return tag
    }

    // MARK: - Constant-Time Comparison

    private static func constantTimeEqual(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }

    // MARK: - SecretBox (XSalsa20-Poly1305)

    static func secretbox(plaintext: [UInt8], nonce: [UInt8], key: [UInt8]) -> [UInt8] {
        let stream = xsalsa20Stream(key: key, nonce: nonce, length: 32 + plaintext.count)
        var ct = [UInt8](repeating: 0, count: plaintext.count)
        for i in 0..<plaintext.count { ct[i] = plaintext[i] ^ stream[32 + i] }
        let mac = poly1305(message: ct, key: Array(stream[0..<32]))
        return mac + ct
    }

    static func secretboxOpen(box: [UInt8], nonce: [UInt8], key: [UInt8]) -> [UInt8]? {
        guard box.count >= 16 else { return nil }
        let mac = Array(box[0..<16])
        let ct = Array(box[16...])
        let stream = xsalsa20Stream(key: key, nonce: nonce, length: 32 + ct.count)
        guard constantTimeEqual(mac, poly1305(message: ct, key: Array(stream[0..<32]))) else { return nil }
        var pt = [UInt8](repeating: 0, count: ct.count)
        for i in 0..<ct.count { pt[i] = ct[i] ^ stream[32 + i] }
        return pt
    }

    // MARK: - Box (x25519 + XSalsa20-Poly1305)

    static func boxBeforeNM(theirPublicKey: [UInt8], myPrivateKey: Curve25519.KeyAgreement.PrivateKey) -> [UInt8]? {
        guard let theirKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: Data(theirPublicKey)),
              let shared = try? myPrivateKey.sharedSecretFromKeyAgreement(with: theirKey) else { return nil }
        let sharedBytes: [UInt8] = shared.withUnsafeBytes { Array($0) }
        return hsalsa20(key: sharedBytes, nonce: [UInt8](repeating: 0, count: 16))
    }

    static func box(plaintext: [UInt8], nonce: [UInt8], theirPublicKey: [UInt8], myPrivateKey: Curve25519.KeyAgreement.PrivateKey) -> [UInt8]? {
        guard let key = boxBeforeNM(theirPublicKey: theirPublicKey, myPrivateKey: myPrivateKey) else { return nil }
        return secretbox(plaintext: plaintext, nonce: nonce, key: key)
    }

    static func boxOpen(box: [UInt8], nonce: [UInt8], theirPublicKey: [UInt8], myPrivateKey: Curve25519.KeyAgreement.PrivateKey) -> [UInt8]? {
        guard let key = boxBeforeNM(theirPublicKey: theirPublicKey, myPrivateKey: myPrivateKey) else { return nil }
        return secretboxOpen(box: box, nonce: nonce, key: key)
    }

    // MARK: - Utilities

    static func randomNonce() -> [UInt8] {
        var nonce = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, 24, &nonce)
        return nonce
    }

    static func hexEncode(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func hexDecode(_ hex: String) -> [UInt8]? {
        guard hex.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            guard let byte = UInt8(hex[idx..<next], radix: 16) else { return nil }
            bytes.append(byte)
            idx = next
        }
        return bytes
    }
}
