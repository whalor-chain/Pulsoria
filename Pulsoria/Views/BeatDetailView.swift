import SwiftUI

struct BeatDetailView: View {
    let beat: Beat
    @ObservedObject var store = BeatStoreManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var tonWallet = TonWalletManager.shared
    @State private var showPurchaseAlert = false
    @State private var showTonPayment = false
    @State private var isPurchasing = false
    @State private var tonPaymentStatus: TonPaymentStatus = .idle
    @State private var showNoWalletAlert = false
    @State private var coverImage: UIImage? = nil
    @State private var barLevels: [CGFloat] = (0..<16).map { _ in CGFloat.random(in: 0.2...1.0) }
    @State private var eqLevels: [CGFloat] = [0.7, 0.85, 0.6, 0.5, 0.35]

    private let eqLabels = ["Sub", "Bass", "Mid", "High", "Air"]

    private var currentBeat: Beat {
        store.allBeats.first(where: { $0.id == beat.id }) ?? beat
    }

    private var isPreviewingThis: Bool {
        store.previewingBeatID == beat.id && store.isPreviewPlaying
    }

    private var isPurchased: Bool {
        store.isBeatPurchased(currentBeat)
    }

    private var isMine: Bool {
        store.isBeatMine(currentBeat)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                coverArt
                trackInfo
                metadataRow
                waveformSection
                eqSection
                previewSection
                if !isMine {
                    purchaseButton
                } else {
                    salesInfo
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(backgroundGradient)
        .navigationTitle(beat.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(Loc.confirmPurchase, isPresented: $showPurchaseAlert) {
            Button(Loc.cancel, role: .cancel) { }
            Button(Loc.buy) {
                purchaseBeat()
            }
        } message: {
            Text("\(Loc.confirmPurchaseMsg) \(beat.formattedPrice)")
        }
        .onDisappear {
            if isPreviewingThis {
                store.stopPreview()
            }
        }
        .task {
            await loadCoverImage()
        }
    }

    // MARK: - Load Cover

    private func loadCoverImage() async {
        guard let urlStr = beat.coverImageURL, let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                coverImage = img
            }
        } catch { }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                theme.currentTheme.accent.opacity(0.15),
                theme.currentTheme.secondary.opacity(0.08),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Cover Art

    private var coverArt: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(
                LinearGradient(
                    colors: [theme.currentTheme.accent.opacity(0.5), theme.currentTheme.secondary.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 280, height: 280)
            .overlay {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 280, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                } else {
                    Image(systemName: beat.coverImageName)
                        .font(.system(size: 72, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .shadow(color: theme.currentTheme.accent.opacity(0.3), radius: 20, y: 10)
    }

    // MARK: - Track Info

    private var trackInfo: some View {
        VStack(spacing: 6) {
            Text(beat.title)
                .font(.custom(Loc.fontBold, size: 22))
            Text(beat.beatmakerName)
                .font(.custom(Loc.fontMedium, size: 15))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 12) {
            metadataBadge(beat.genre.rawValue)
            metadataBadge("\(beat.bpm) BPM")
            metadataBadge(beat.key.rawValue)
            metadataBadge(beat.formattedDuration)
        }
    }

    private func metadataBadge(_ text: String) -> some View {
        Text(text)
            .font(.custom(Loc.fontMedium, size: 11))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(theme.currentTheme.accent.opacity(0.15))
            )
            .foregroundStyle(theme.currentTheme.accent)
    }

    // MARK: - Waveform Section

    private var waveformSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Loc.waveform)
                .font(.custom(Loc.fontBold, size: 15))
                .foregroundStyle(.secondary)

            Canvas { context, size in
                let barWidth = (size.width - CGFloat(barLevels.count - 1) * 3) / CGFloat(barLevels.count)
                for i in barLevels.indices {
                    let height = barLevels[i] * size.height * (isPreviewingThis ? 1.0 : 0.6)
                    let x = CGFloat(i) * (barWidth + 3)
                    let y = (size.height - height) / 2

                    let rect = CGRect(x: x, y: y, width: barWidth, height: height)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)

                    let opacity = isPreviewingThis ? 0.8 : 0.4
                    context.fill(path, with: .color(theme.currentTheme.accent.opacity(opacity)))
                }
            }
            .frame(height: 80)
            .animation(.easeInOut(duration: 0.3), value: isPreviewingThis)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }

    // MARK: - EQ Section

    private var eqSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Loc.equalizer)
                .font(.custom(Loc.fontBold, size: 15))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: 10) {
                        Text(eqLabels[i])
                            .font(.custom(Loc.fontMedium, size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [theme.currentTheme.accent, theme.currentTheme.secondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * eqLevels[i] * (isPreviewingThis ? 1.0 : 0.7))
                                .animation(.easeInOut(duration: 0.4), value: isPreviewingThis)
                        }
                        .frame(height: 12)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 10) {
            Text(Loc.preview)
                .font(.custom(Loc.fontBold, size: 15))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [theme.currentTheme.accent, theme.currentTheme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * store.previewProgress)
                        .animation(.linear(duration: 0.1), value: store.previewProgress)
                }
            }
            .frame(height: 6)

            GlassEffectContainer {
                Button {
                    if isPreviewingThis {
                        store.stopPreview()
                    } else {
                        store.startPreview(for: beat)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isPreviewingThis ? "stop.fill" : "play.fill")
                        Text(isPreviewingThis ? Loc.stopPreview : Loc.preview)
                            .font(.custom(Loc.fontMedium, size: 15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.glass)
                .tint(theme.currentTheme.accent)
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: isPreviewingThis)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        VStack(spacing: 10) {
            if isPurchased {
                GlassEffectContainer {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(Loc.purchased)
                            .font(.custom(Loc.fontBold, size: 17))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassEffect()
                }
                .tint(.green)
            } else {
                // TON Payment button
                if beat.priceTON > 0 {
                    GlassEffectContainer {
                        Button {
                            payWithTON()
                        } label: {
                            HStack(spacing: 10) {
                                if tonPaymentStatus == .processing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "diamond.fill")
                                }
                                Text("\(Loc.payWithTon) — \(beat.formattedPriceTON)")
                                    .font(.custom(Loc.fontBold, size: 17))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.glass)
                        .tint(.cyan)
                    }
                    .disabled(tonPaymentStatus == .processing)
                }

                // Regular purchase button
                GlassEffectContainer {
                    Button {
                        showPurchaseAlert = true
                    } label: {
                        HStack(spacing: 10) {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "bag.fill")
                            }
                            Text("\(Loc.buyBeat) — \(beat.formattedPrice)")
                                .font(.custom(Loc.fontBold, size: 17))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.glass)
                    .tint(theme.currentTheme.accent)
                }
                .disabled(isPurchasing)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isPurchased)
        .alert(Loc.walletNotConnected, isPresented: $showNoWalletAlert) {
            Button("OK") { }
        } message: {
            Text(Loc.connectWalletFirst)
        }
    }

    // MARK: - Sales Info (for owner)

    private var salesInfo: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(theme.currentTheme.accent)
                Text(Loc.yourBeat)
                    .font(.custom(Loc.fontBold, size: 17))
                Spacer()
            }
            HStack {
                Text(Loc.totalSales)
                    .font(.custom(Loc.fontMedium, size: 15))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(currentBeat.purchasedBy.count)")
                    .font(.custom(Loc.fontBold, size: 15))
            }
            HStack {
                Text(Loc.earned)
                    .font(.custom(Loc.fontMedium, size: 15))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "$%.2f", currentBeat.price * Double(currentBeat.purchasedBy.count)))
                    .font(.custom(Loc.fontBold, size: 15))
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }

    // MARK: - Purchase Action

    private func purchaseBeat() {
        isPurchasing = true
        Task {
            do {
                try await store.purchaseBeat(beat)
            } catch { }
            isPurchasing = false
        }
    }

    // MARK: - TON Payment

    private func payWithTON() {
        guard tonWallet.isConnected else {
            showNoWalletAlert = true
            return
        }

        tonPaymentStatus = .processing

        Task {
            // Get seller's wallet address
            guard let sellerWallet = await tonWallet.getSellerWallet(uploaderID: beat.uploaderID) else {
                tonPaymentStatus = .failed
                return
            }

            // Open Tonkeeper for payment
            let comment = "Pulsoria: \(beat.title)"
            let sent = tonWallet.sendPayment(toAddress: sellerWallet, amount: beat.priceTON, comment: comment)

            if !sent {
                tonPaymentStatus = .failed
                return
            }

            // Wait a bit then verify (user needs time to confirm in Tonkeeper)
            try? await Task.sleep(for: .seconds(15))

            let verified = await tonWallet.verifyTransaction(
                fromAddress: tonWallet.walletAddress,
                toAddress: sellerWallet,
                expectedAmount: beat.priceTON,
                beatID: beat.id
            )

            tonPaymentStatus = verified ? .success : .pending
        }
    }
}

// MARK: - TON Payment Status

enum TonPaymentStatus {
    case idle, processing, success, failed, pending
}
