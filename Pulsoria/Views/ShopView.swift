import OSLog
import SwiftUI

struct ShopView: View {
    @ObservedObject var store = BeatStoreManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var tonWallet = TonWalletManager.shared
    @State private var showFilterSheet = false
    @State private var showUploadSheet = false
    @State private var showTonWalletSheet = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.allBeats.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.filteredBeats.isEmpty {
                    emptyState
                } else {
                    scrollContent
                }
            }
            .navigationTitle(Loc.shop)
            .searchable(text: $store.searchText, prompt: Loc.searchBeats)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTonWalletSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "wallet.bifold")
                                .foregroundStyle(tonWallet.isConnected ? .cyan : .secondary)
                            if tonWallet.isConnected {
                                Text(tonWallet.formattedBalance)
                                    .font(.custom(Loc.fontMedium, size: 13))
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }
                    .accessibilityLabel(Loc.connectTonWallet)
                    .accessibilityValue(tonWallet.isConnected ? tonWallet.formattedBalance : Loc.walletNotConnected)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showFilterSheet = true
                        } label: {
                            Image(systemName: store.hasActiveFilters
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                                .foregroundStyle(store.hasActiveFilters
                                                 ? theme.currentTheme.accent
                                                 : .secondary)
                        }
                        .accessibilityLabel(Loc.a11yFilters)
                        .accessibilityValue(store.hasActiveFilters ? "active" : "none")

                        if store.userRole.canUpload {
                            Button {
                                showUploadSheet = true
                            } label: {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(theme.currentTheme.accent)
                            }
                            .accessibilityLabel(Loc.uploadBeat)
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                BeatFilterSheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showUploadSheet) {
                BeatUploadView()
            }
            .sheet(isPresented: $showTonWalletSheet) {
                TonWalletSheet()
            }
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.filteredBeats) { beat in
                    NavigationLink(value: beat) {
                        BeatCardView(beat: beat)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .navigationDestination(for: Beat.self) { beat in
            BeatDetailView(beat: beat)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bag")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.secondary)
            Text(Loc.noBeatsFound)
                .font(.custom(Loc.fontBold, size: 22))
            Text(Loc.noBeatsFoundHint)
                .font(.custom(Loc.fontMedium, size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if store.hasActiveFilters {
                Button {
                    withAnimation { store.resetFilters() }
                } label: {
                    Text(Loc.resetFilters)
                        .font(.custom(Loc.fontMedium, size: 15))
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.currentTheme.accent)
            }

            if store.userRole.canUpload {
                Button {
                    showUploadSheet = true
                } label: {
                    Label(Loc.uploadBeat, systemImage: "plus.circle.fill")
                        .font(.custom(Loc.fontMedium, size: 15))
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.currentTheme.accent)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Beat Card

struct BeatCardView: View {
    let beat: Beat
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var store = BeatStoreManager.shared
    @State private var coverImage: UIImage? = nil

    private var isPurchased: Bool {
        store.isBeatPurchased(beat)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover art
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [theme.currentTheme.accent.opacity(0.4), theme.currentTheme.secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 140)
                .overlay {
                    if let coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Image(systemName: beat.coverImageName)
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    VStack(spacing: 4) {
                        if beat.priceTON > 0 {
                            Text(beat.formattedPriceTON)
                                .font(.custom(Loc.fontBold, size: 11))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.cyan.opacity(0.8))
                                )
                        }
                        Text(beat.formattedPrice)
                            .font(.custom(Loc.fontBold, size: 13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(theme.currentTheme.accent.opacity(0.8))
                            )
                    }
                    .padding(8)
                }
                .overlay(alignment: .topLeading) {
                    if isPurchased {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.green)
                            .padding(8)
                    }
                }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(beat.title)
                    .font(.custom(Loc.fontBold, size: 14))
                    .lineLimit(1)

                Text(beat.beatmakerName)
                    .font(.custom(Loc.fontMedium, size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(beat.genre.rawValue)
                        .font(.custom(Loc.fontMedium, size: 10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(theme.currentTheme.accent.opacity(0.6))
                        )

                    Text("\(beat.bpm) BPM")
                        .font(.custom(Loc.fontMedium, size: 10))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
            .padding(.horizontal, 4)
        }
        .task {
            await loadCover()
        }
    }

    private func loadCover() async {
        guard let urlStr = beat.coverImageURL, let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                coverImage = img
            }
        } catch {
            Logger.beatStore.debug("Cover load failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Filter Sheet

struct BeatFilterSheet: View {
    @ObservedObject var store = BeatStoreManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Genre
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Loc.genre)
                            .font(.custom(Loc.fontBold, size: 17))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                genreButton(nil, title: Loc.allGenres)
                                ForEach(BeatGenre.allCases) { genre in
                                    genreButton(genre, title: genre.rawValue)
                                }
                            }
                        }
                    }

                    // BPM Range
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(Loc.bpmRange)
                                .font(.custom(Loc.fontBold, size: 17))
                            Spacer()
                            Text("\(Int(store.bpmRange.lowerBound))–\(Int(store.bpmRange.upperBound))")
                                .font(.custom(Loc.fontMedium, size: 14))
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 16) {
                            Text("\(Int(store.bpmRange.lowerBound))")
                                .font(.custom(Loc.fontMedium, size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            Slider(value: Binding(
                                get: { store.bpmRange.lowerBound },
                                set: { store.bpmRange = $0...store.bpmRange.upperBound }
                            ), in: 60...200, step: 5)
                            .tint(theme.currentTheme.accent)
                        }
                        HStack(spacing: 16) {
                            Text("\(Int(store.bpmRange.upperBound))")
                                .font(.custom(Loc.fontMedium, size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            Slider(value: Binding(
                                get: { store.bpmRange.upperBound },
                                set: { store.bpmRange = store.bpmRange.lowerBound...$0 }
                            ), in: 60...200, step: 5)
                            .tint(theme.currentTheme.accent)
                        }
                    }

                    // Key
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Loc.key)
                            .font(.custom(Loc.fontBold, size: 17))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                keyButton(nil, title: Loc.allKeys)
                                ForEach(MusicalKey.allCases) { key in
                                    keyButton(key, title: key.rawValue)
                                }
                            }
                        }
                    }

                    // Price Range
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(Loc.priceRange)
                                .font(.custom(Loc.fontBold, size: 17))
                            Spacer()
                            Text("$\(Int(store.priceRange.lowerBound))–$\(Int(store.priceRange.upperBound))")
                                .font(.custom(Loc.fontMedium, size: 14))
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 16) {
                            Text("$\(Int(store.priceRange.lowerBound))")
                                .font(.custom(Loc.fontMedium, size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            Slider(value: Binding(
                                get: { store.priceRange.lowerBound },
                                set: { store.priceRange = $0...store.priceRange.upperBound }
                            ), in: 0...100, step: 5)
                            .tint(theme.currentTheme.accent)
                        }
                        HStack(spacing: 16) {
                            Text("$\(Int(store.priceRange.upperBound))")
                                .font(.custom(Loc.fontMedium, size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            Slider(value: Binding(
                                get: { store.priceRange.upperBound },
                                set: { store.priceRange = store.priceRange.lowerBound...$0 }
                            ), in: 0...100, step: 5)
                            .tint(theme.currentTheme.accent)
                        }
                    }

                    // Reset
                    Button {
                        withAnimation { store.resetFilters() }
                    } label: {
                        Text(Loc.resetFilters)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.8))
                }
                .padding(20)
            }
            .navigationTitle(Loc.filters)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.done) {
                        dismiss()
                    }
                    .font(.custom(Loc.fontMedium, size: 15))
                }
            }
        }
    }

    private func genreButton(_ genre: BeatGenre?, title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                store.selectedGenre = genre
            }
        } label: {
            Text(title)
                .font(.custom(Loc.fontMedium, size: 13))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(store.selectedGenre == genre
                              ? theme.currentTheme.accent.opacity(0.3)
                              : Color(.systemGray5))
                )
                .foregroundStyle(store.selectedGenre == genre
                                 ? theme.currentTheme.accent
                                 : .primary)
        }
        .buttonStyle(.plain)
    }

    private func keyButton(_ key: MusicalKey?, title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                store.selectedKey = key
            }
        } label: {
            Text(title)
                .font(.custom(Loc.fontMedium, size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(store.selectedKey == key
                              ? theme.currentTheme.accent.opacity(0.3)
                              : Color(.systemGray5))
                )
                .foregroundStyle(store.selectedKey == key
                                 ? theme.currentTheme.accent
                                 : .primary)
        }
        .buttonStyle(.plain)
    }
}
