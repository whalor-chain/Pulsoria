import SwiftUI
import AVFoundation
import Network

struct ContentView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var store = BeatStoreManager.shared
    @State private var showPlayer = false
    @State private var showSharedImport = false
    @State private var sharedStagedImports: [StagedImport] = []
    @State private var isOffline = false

    @ObservedObject var theme = ThemeManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                Tab(Loc.home, systemImage: "music.note.house") {
                    HomeView()
                }

                Tab(Loc.library, systemImage: "music.note.square.stack") {
                    LibraryView()
                }

                if store.userRole != .listener {
                    Tab(Loc.shop, systemImage: "bag.fill") {
                        ShopView()
                    }
                }
            }

            VStack(spacing: 8) {
                if isOffline {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 12, weight: .semibold))
                        Text(ThemeManager.shared.language == .russian ? "Нет связи" : "No Connection")
                            .font(.custom(Loc.fontMedium, size: 13))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(in: .capsule)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if player.currentTrack != nil {
                    MiniPlayerView(onTap: {
                        showPlayer = true
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Color.clear
                    .frame(height: 62)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showPlayer) {
            PlayerView()
                .presentationDragIndicator(.hidden)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showSharedImport) {
            ImportReviewSheet(stagedImports: $sharedStagedImports) {
                for item in sharedStagedImports {
                    player.importTrack(
                        from: item.sourceURL,
                        title: item.title,
                        artist: item.artist,
                        artworkData: item.artworkData
                    )
                }
                sharedStagedImports.removeAll()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sharedAudioImport)) { _ in
            Task { await processSharedFiles() }
        }
        .animation(.easeInOut(duration: 0.3), value: player.currentTrack?.id)
        .animation(.easeInOut(duration: 0.3), value: isOffline)
        .animation(.smooth(duration: 0.3), value: theme.language)
        .animation(.smooth(duration: 0.3), value: store.userRole)
        .onAppear {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                DispatchQueue.main.async {
                    isOffline = path.status != .satisfied
                }
            }
            monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
        }
    }

    @MainActor
    private func processSharedFiles() async {
        let urls = player.getSharedFiles()
        guard !urls.isEmpty else { return }

        var staged: [StagedImport] = []
        for url in urls {
            staged.append(await Self.stageImport(from: url))
        }

        guard !staged.isEmpty else { return }
        sharedStagedImports = staged
        showSharedImport = true
    }

    nonisolated private static func stageImport(from url: URL) async -> StagedImport {
        let rawName = url.deletingPathExtension().lastPathComponent
        var cleaned = rawName.replacingOccurrences(of: "_", with: " ")
        if let range = cleaned.range(of: #"\s+\d{8,}$"#, options: .regularExpression) {
            cleaned.removeSubrange(range)
        }
        cleaned = cleaned.replacingOccurrences(of: #"\s*[\(\[].*?[\)\]]"#, with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = cleaned.components(separatedBy: " - ")
        let artistGuess = parts.count > 1 ? parts[0].trimmingCharacters(in: .whitespaces) : ""
        let titleGuess = parts.count > 1
            ? parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
            : cleaned

        let fileSize: String
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSize = String(format: "%.1f MB", Double(size) / 1_048_576)
        } else {
            fileSize = "—"
        }

        let asset = AVURLAsset(url: url)
        var fileDuration = "0:00"
        var artworkData: Data? = nil
        var metaTitle: String? = nil
        var metaArtist: String? = nil

        if let dur = try? await asset.load(.duration) {
            let sec = CMTimeGetSeconds(dur)
            fileDuration = String(format: "%d:%02d", Int(sec) / 60, Int(sec) % 60)
        }
        if let meta = try? await asset.load(.commonMetadata) {
            let titleItems = AVMetadataItem.metadataItems(from: meta, filteredByIdentifier: .commonIdentifierTitle)
            if let item = titleItems.first, let str = try? await item.load(.stringValue), !str.isEmpty {
                metaTitle = str
            }
            let artistItems = AVMetadataItem.metadataItems(from: meta, filteredByIdentifier: .commonIdentifierArtist)
            if let item = artistItems.first, let str = try? await item.load(.stringValue), !str.isEmpty {
                metaArtist = str.replacingOccurrences(of: "/", with: ", ")
            }
            let artItems = AVMetadataItem.metadataItems(from: meta, filteredByIdentifier: .commonIdentifierArtwork)
            if let item = artItems.first, let data = try? await item.load(.dataValue) {
                artworkData = data
            }
        }

        let finalTitle = metaTitle ?? titleGuess
        let finalArtist = metaArtist ?? artistGuess
        if artworkData == nil && !finalTitle.isEmpty {
            artworkData = await GeniusManager.shared.fetchSongArtworkData(title: finalTitle, artist: finalArtist)
        }

        let foundTitle = metaTitle != nil || parts.count > 1
        let foundArtist = metaArtist != nil || (parts.count > 1 && !artistGuess.isEmpty)

        return StagedImport(
            sourceURL: url,
            title: finalTitle,
            artist: finalArtist,
            fileExtension: url.pathExtension,
            fileSize: fileSize,
            fileDuration: fileDuration,
            artworkData: artworkData,
            foundTitle: foundTitle,
            foundArtist: foundArtist,
            suggestedTitle: nil,
            suggestedArtist: nil
        )
    }
}

#Preview {
    ContentView()
}
