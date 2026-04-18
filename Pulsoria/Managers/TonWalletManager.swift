import SwiftUI
import Combine
import CryptoKit
import FirebaseFirestore

// MARK: - TON Connect Session

struct TonConnectSession: Codable {
    let privateKeyData: Data
    let publicKeyHex: String
    var walletPublicKeyHex: String?
    var walletAddress: String?

    var privateKey: Curve25519.KeyAgreement.PrivateKey? {
        try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
    }

    static func create() -> TonConnectSession {
        let priv = Curve25519.KeyAgreement.PrivateKey()
        let pubBytes = Array(priv.publicKey.rawRepresentation)
        return TonConnectSession(
            privateKeyData: priv.rawRepresentation,
            publicKeyHex: NaCl.hexEncode(pubBytes)
        )
    }
}

// MARK: - TON Wallet Manager

@MainActor
class TonWalletManager: ObservableObject {
    static let shared = TonWalletManager()

    @Published var walletAddress: String = ""
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var balance: Double? = nil
    @Published var isLoadingBalance: Bool = false
    @Published var connectionError: String? = nil

    private let db = Firestore.firestore()
    
    
    private var session: TonConnectSession?
    private var bridgeTask: Task<Void, Never>?
    private var activeBridgeUrl = "https://bridge.tonapi.io/bridge"

    private let manifestUrl = "https://raw.githubusercontent.com/whalor-chain/pulsoria--ton--connect/refs/heads/main/tonconnect-manifest.json"
    private let tonkeeperBridge = "https://bridge.tonapi.io/bridge"
    private let telegramBridge = "https://walletbot.me/tonconnect-bridge/bridge"

    private init() {
        loadSession()
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handleAppForeground()
            }
        }
    }

    private func handleAppForeground() {
        guard !isConnected, session != nil, session?.walletAddress == nil else { return }
        isConnecting = true
        startBridgeListener()
    }

    // MARK: - Session Persistence

    private func loadSession() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKey.tonConnectSession),
           let saved = try? JSONDecoder().decode(TonConnectSession.self, from: data) {
            session = saved
            if let addr = saved.walletAddress, !addr.isEmpty {
                walletAddress = addr
                isConnected = true
                Task { await fetchBalance() }
            }
        }
    }

    private func saveSession() {
        guard let session else { return }
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.tonConnectSession)
        }
    }

    // MARK: - TON Connect 2.0 Flow

    private func buildConnectRequest() -> (json: String, encoded: String)? {
        let requestJSON = "{\"manifestUrl\":\"\(manifestUrl)\",\"items\":[{\"name\":\"ton_addr\"}]}"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = requestJSON.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return (requestJSON, encoded)
    }

    func connectViaTonConnect() {
        isConnecting = true
        connectionError = nil
        lastEventId = nil
        activeBridgeUrl = tonkeeperBridge

        session = TonConnectSession.create()
        saveSession()

        guard let session, let req = buildConnectRequest() else { return }

        let connectUrl = "https://app.tonkeeper.com/ton-connect?v=2&id=\(session.publicKeyHex)&r=\(req.encoded)&ret=none"
        if let url = URL(string: connectUrl) {
            UIApplication.shared.open(url)
        }
    }

    func connectViaTelegram() {
        isConnecting = true
        connectionError = nil
        lastEventId = nil
        activeBridgeUrl = telegramBridge

        session = TonConnectSession.create()
        saveSession()

        guard let session else { return }

        // Step 1: Build query string like JS SDK's URL.searchParams.append does
        // JS searchParams.append only allows: * - . 0-9 A-Z _ a-z (everything else is encoded)
        let requestJSON = "{\"manifestUrl\":\"\(manifestUrl)\",\"items\":[{\"name\":\"ton_addr\"}]}"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "*-._")
        guard let encodedR = requestJSON.addingPercentEncoding(withAllowedCharacters: allowed) else { return }
        let queryString = "v=2&id=\(session.publicKeyHex)&r=\(encodedR)&ret=back"

        // Step 2: Apply TON Connect SDK's encodeTelegramUrlParameters
        // Order matters exactly as in the SDK source
        let encoded = queryString
            .replacingOccurrences(of: ".", with: "%2E")
            .replacingOccurrences(of: "-", with: "%2D")
            .replacingOccurrences(of: "_", with: "%5F")
            .replacingOccurrences(of: "&", with: "-")
            .replacingOccurrences(of: "=", with: "__")
            .replacingOccurrences(of: "%", with: "--")

        let startapp = "tonconnect-\(encoded)"

        let directUrl = "tg://resolve?domain=wallet&attach=wallet&startapp=\(startapp)"
        let fallbackUrl = "https://t.me/wallet?attach=wallet&startapp=\(startapp)"

        if let url = URL(string: directUrl), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: fallbackUrl) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Bridge SSE Listener

    private var lastEventId: String?

    private func startBridgeListener() {
        bridgeTask?.cancel()
        bridgeTask = Task { [weak self] in
            guard let self, let session = self.session else { return }
            let clientId = session.publicKeyHex

            // Retry loop — reconnects after background/disconnect
            var retryCount = 0
            while !Task.isCancelled && !self.isConnected && retryCount < 15 {
                retryCount += 1

                var urlStr = "\(self.activeBridgeUrl)/events?client_id=\(clientId)"
                if let lastId = self.lastEventId {
                    urlStr += "&last_event_id=\(lastId)"
                }
                guard let url = URL(string: urlStr) else { return }

                do {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 60
                    let (bytes, _) = try await URLSession.shared.bytes(for: request)
                    var eventDataParts: [String] = []
                    var currentId: String?

                    for try await line in bytes.lines {
                        if Task.isCancelled || self.isConnected { break }

                        if line.hasPrefix("id:") {
                            currentId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            let part = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            eventDataParts.append(part)
                            let joined = eventDataParts.joined()
                            if joined.contains("\"from\"") && joined.contains("\"message\"") {
                                if let cid = currentId { self.lastEventId = cid }
                                await self.handleBridgeEvent(joined)
                                eventDataParts = []
                                currentId = nil
                            }
                        } else if line.hasPrefix("event:") {
                            // event type line
                        } else if line.isEmpty && !eventDataParts.isEmpty {
                            if let cid = currentId { self.lastEventId = cid }
                            await self.handleBridgeEvent(eventDataParts.joined())
                            eventDataParts = []
                            currentId = nil
                        }
                    }
                } catch {
                    if Task.isCancelled || self.isConnected { break }
                    await MainActor.run {
                        self.connectionError = "Bridge #\(retryCount) error: \(error.localizedDescription)"
                    }
                    try? await Task.sleep(for: .seconds(2))
                }
            }

            if !self.isConnected && !Task.isCancelled {
                await MainActor.run {
                    self.isConnecting = false
                    self.connectionError = "Bridge connection failed"
                }
            }
        }

        // Timeout after 3 minutes
        Task {
            try? await Task.sleep(for: .seconds(180))
            if isConnecting && !isConnected {
                isConnecting = false
                connectionError = "Connection timed out"
                bridgeTask?.cancel()
            }
        }
    }

    private func handleBridgeEvent(_ jsonStr: String) async {
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fromHex = json["from"] as? String,
              let messageBase64 = json["message"] as? String,
              let messageData = Data(base64Encoded: messageBase64) else { return }

        let messageBytes = Array(messageData)
        guard messageBytes.count > 24 else { return }

        let nonce = Array(messageBytes[0..<24])
        let box = Array(messageBytes[24...])

        guard let senderPubKey = NaCl.hexDecode(fromHex),
              let privKey = session?.privateKey,
              let plaintext = NaCl.boxOpen(box: box, nonce: nonce, theirPublicKey: senderPubKey, myPrivateKey: privKey),
              let responseStr = String(bytes: plaintext, encoding: .utf8),
              let responseData = responseStr.data(using: .utf8),
              let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            await MainActor.run {
                isConnecting = false
                connectionError = Loc.decryptionFailed
            }
            return
        }

        // Check for error
        if let error = response["error"] as? [String: Any],
           let message = error["message"] as? String {
            await MainActor.run {
                isConnecting = false
                connectionError = message
            }
            return
        }

        // Parse wallet address from response
        // TON Connect 2.0: response is {event, id, payload: {items: [...]}}
        let payload = response["payload"] as? [String: Any] ?? response
        if let items = (payload["items"] as? [[String: Any]]) {
            for item in items {
                if item["name"] as? String == "ton_addr",
                   let address = item["address"] as? String {
                    // Success!
                    await MainActor.run {
                        session?.walletPublicKeyHex = fromHex
                        session?.walletAddress = address
                        saveSession()

                        walletAddress = address
                        isConnected = true
                        isConnecting = false
                        connectionError = nil
                        bridgeTask?.cancel()
                    }

                    // Save to UserDefaults + Firestore
                    UserDefaults.standard.set(address, forKey: UserDefaultsKey.tonWalletAddress)
                    let userID = AuthManager.shared.appleUserID
                    if !userID.isEmpty {
                        try? await db.collection("users").document(userID).setData([
                            "tonWallet": address,
                            "updatedAt": Date().timeIntervalSince1970
                        ], merge: true)
                    }

                    await fetchBalance()
                    return
                }
            }
        }
    }

    // MARK: - Manual Connect (fallback)

    func connectWallet(address: String) async throws {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidTonAddress(trimmed) else {
            throw TonError.invalidAddress
        }

        walletAddress = trimmed
        isConnected = true
        UserDefaults.standard.set(trimmed, forKey: UserDefaultsKey.tonWalletAddress)

        let userID = AuthManager.shared.appleUserID
        if !userID.isEmpty {
            try await db.collection("users").document(userID).setData([
                "tonWallet": trimmed,
                "updatedAt": Date().timeIntervalSince1970
            ], merge: true)
        }

        await fetchBalance()
    }

    // MARK: - Disconnect

    func disconnectWallet() {
        walletAddress = ""
        isConnected = false
        isConnecting = false
        balance = nil
        connectionError = nil
        session = nil
        bridgeTask?.cancel()

        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.tonWalletAddress)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.tonConnectSession)

        let userID = AuthManager.shared.appleUserID
        if !userID.isEmpty {
            Task {
                try? await db.collection("users").document(userID).updateData([
                    "tonWallet": FieldValue.delete()
                ])
            }
        }
    }

    // MARK: - Handle Return URL

    func handleReturnURL() {
        guard !isConnected, session != nil else { return }
        isConnecting = true
        // Force reconnect to get buffered message
        startBridgeListener()
    }

    // MARK: - Fetch Balance

    func fetchBalance() async {
        guard !walletAddress.isEmpty else { return }
        isLoadingBalance = true
        defer { isLoadingBalance = false }

        do {
            let urlStr = "https://toncenter.com/api/v2/getAddressBalance?address=\(walletAddress)"
            guard let url = URL(string: urlStr) else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? String,
               let nanotons = Double(result) {
                balance = nanotons / 1_000_000_000.0
            }
        } catch { }
    }

    // MARK: - Get Seller Wallet

    func getSellerWallet(uploaderID: String) async -> String? {
        guard !uploaderID.isEmpty else { return nil }
        do {
            let doc = try await db.collection("users").document(uploaderID).getDocument()
            return doc.data()?["tonWallet"] as? String
        } catch {
            return nil
        }
    }

    // MARK: - Send Payment via Tonkeeper

    func sendPayment(toAddress: String, amount: Double, comment: String = "") -> Bool {
        let nanotons = Int64(amount * 1_000_000_000)
        let encodedComment = comment.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let tonkeeperURL = "tonkeeper://v1/transfer/\(toAddress)?amount=\(nanotons)&text=\(encodedComment)"
        let tonURL = "ton://transfer/\(toAddress)?amount=\(nanotons)&text=\(encodedComment)"

        if let url = URL(string: tonkeeperURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        } else if let url = URL(string: tonURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        }
        return false
    }

    // MARK: - Verify Transaction

    func verifyTransaction(fromAddress: String, toAddress: String, expectedAmount: Double, beatID: String) async -> Bool {
        do {
            let urlStr = "https://toncenter.com/api/v2/getTransactions?address=\(toAddress)&limit=10"
            guard let url = URL(string: urlStr) else { return false }
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [[String: Any]] else { return false }

            let expectedNano = Int64(expectedAmount * 1_000_000_000)
            let tolerance: Int64 = 10_000_000

            for tx in result {
                guard let inMsg = tx["in_msg"] as? [String: Any],
                      let source = inMsg["source"] as? String,
                      let valueStr = inMsg["value"] as? String,
                      let value = Int64(valueStr) else { continue }

                if source == fromAddress && abs(value - expectedNano) < tolerance {
                    let userID = AuthManager.shared.appleUserID
                    try await db.collection("beats").document(beatID).updateData([
                        "purchasedBy": FieldValue.arrayUnion([userID])
                    ])
                    return true
                }
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Validation

    func isValidTonAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 48 && (trimmed.hasPrefix("UQ") || trimmed.hasPrefix("EQ")) {
            return true
        }
        if trimmed.contains(":") && trimmed.count >= 64 {
            return true
        }
        return false
    }

    // MARK: - Formatted Balance

    var formattedBalance: String {
        guard let balance else { return "..." }
        return String(format: "%.2f TON", balance)
    }
}

// MARK: - Errors

enum TonError: LocalizedError {
    case invalidAddress
    case noWalletApp
    case transactionFailed

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "Invalid TON wallet address"
        case .noWalletApp: return "No TON wallet app installed (Tonkeeper)"
        case .transactionFailed: return "Transaction verification failed"
        }
    }
}
