import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct BeatUploadView: View {
    @ObservedObject var store = BeatStoreManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var auth = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var selectedGenre: BeatGenre = .trap
    @State private var bpm: Int = 120
    @State private var selectedKey: MusicalKey = .cMinor
    @State private var priceText = ""
    @State private var priceTONText = ""
    @State private var selectedCover = "waveform.circle.fill"
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isUploading = false
    @State private var showFileImporter = false
    @State private var selectedFileName: String? = nil
    @State private var selectedFileURL: URL? = nil
    @State private var coverPhotoItem: PhotosPickerItem? = nil
    @State private var coverImageData: Data? = nil
    @State private var coverUIImage: UIImage? = nil

    private let coverOptions = [
        "waveform.circle.fill", "moon.fill", "bolt.fill", "flame.fill",
        "star.fill", "sparkles", "drop.fill", "cloud.fill",
        "sun.max.fill", "leaf.fill", "crown.fill", "speaker.wave.3.fill"
    ]

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(priceText) ?? 0) > 0 &&
        selectedFileURL != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Beat Info
                Section {
                    TextField(Loc.beatTitle, text: $title)
                        .font(.custom(Loc.fontMedium, size: 15))

                    Picker(Loc.genre, selection: $selectedGenre) {
                        ForEach(BeatGenre.allCases) { genre in
                            Text(genre.rawValue).tag(genre)
                        }
                    }
                    .font(.custom(Loc.fontMedium, size: 15))

                    Stepper(value: $bpm, in: 40...300, step: 5) {
                        HStack {
                            Text(Loc.bpm)
                                .font(.custom(Loc.fontMedium, size: 15))
                            Spacer()
                            Text("\(bpm)")
                                .font(.custom(Loc.fontMedium, size: 15))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Picker(Loc.key, selection: $selectedKey) {
                        ForEach(MusicalKey.allCases) { key in
                            Text(key.rawValue).tag(key)
                        }
                    }
                    .font(.custom(Loc.fontMedium, size: 15))
                }

                // Price
                Section {
                    HStack {
                        Text("$")
                            .font(.custom(Loc.fontBold, size: 17))
                            .foregroundStyle(theme.currentTheme.accent)
                        TextField(Loc.price, text: $priceText)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.cyan)
                        TextField("TON (\(Loc.optional))", text: $priceTONText)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .keyboardType(.decimalPad)
                    }
                }

                // Cover
                Section(Loc.coverImage) {
                    let accent = theme.currentTheme.accent
                    PhotosPicker(selection: $coverPhotoItem, matching: .images) {
                        HStack(spacing: 12) {
                            if let coverUIImage {
                                Image(uiImage: coverUIImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 56, height: 56)
                                    .overlay {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 20))
                                            .foregroundStyle(accent)
                                    }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(coverUIImage != nil ? Loc.coverImage : Loc.selectCover)
                                    .font(.custom(Loc.fontMedium, size: 15))
                                if coverUIImage != nil {
                                    Button {
                                        withAnimation {
                                            coverPhotoItem = nil
                                            coverImageData = nil
                                            coverUIImage = nil
                                        }
                                    } label: {
                                        Text(Loc.removeCover)
                                            .font(.custom(Loc.fontMedium, size: 12))
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            Spacer()
                            if coverUIImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .onChange(of: coverPhotoItem) { _, newItem in
                        Task { @MainActor in
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                coverImageData = data
                                coverUIImage = UIImage(data: data)
                            }
                        }
                    }

                    if coverUIImage == nil {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(coverOptions, id: \.self) { icon in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCover = icon
                                    }
                                } label: {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedCover == icon
                                              ? theme.currentTheme.accent.opacity(0.2)
                                              : Color(.systemGray6))
                                        .frame(height: 56)
                                        .overlay {
                                            Image(systemName: icon)
                                                .font(.system(size: 22))
                                                .foregroundStyle(selectedCover == icon
                                                                 ? theme.currentTheme.accent
                                                                 : .secondary)
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedCover == icon
                                                         ? theme.currentTheme.accent
                                                         : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Audio File
                Section(Loc.audioFile) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label {
                            HStack {
                                Text(selectedFileName ?? Loc.selectFile)
                                    .font(.custom(Loc.fontMedium, size: 15))
                                    .foregroundStyle(selectedFileName != nil ? .primary : .secondary)
                                Spacer()
                                if selectedFileName != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        } icon: {
                            Image(systemName: "doc.badge.plus")
                                .foregroundStyle(theme.currentTheme.accent)
                        }
                    }
                }

                // Upload Button
                Section {
                    if isUploading {
                        VStack(spacing: 8) {
                            ProgressView(value: store.uploadProgress)
                                .tint(theme.currentTheme.accent)
                            Text("\(Int(store.uploadProgress * 100))%")
                                .font(.custom(Loc.fontMedium, size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            guard isValid else { return }
                            uploadBeat()
                        } label: {
                            Text(Loc.upload)
                                .font(.custom(Loc.fontBold, size: 17))
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(isValid ? theme.currentTheme.accent : .secondary)
                        }
                        .disabled(!isValid)
                    }
                }
            }
            .navigationTitle(Loc.uploadBeat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Loc.cancel) {
                        dismiss()
                    }
                    .font(.custom(Loc.fontMedium, size: 15))
                    .disabled(isUploading)
                }
            }
            .overlay {
                if showSuccess {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text(Loc.uploadSuccess)
                            .font(.custom(Loc.fontBold, size: 20))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showSuccess)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    selectedFileName = url.lastPathComponent
                    selectedFileURL = url
                case .failure:
                    break
                }
            }
            .disabled(isUploading)
        }
    }

    private func uploadBeat() {
        isUploading = true
        let price = Double(priceText) ?? 0
        let tonPrice = Double(priceTONText) ?? 0
        let beatTitle = title.trimmingCharacters(in: .whitespaces)
        let name = auth.userName.isEmpty ? "Anonymous" : auth.userName

        Task {
            do {
                try await store.uploadBeat(
                    title: beatTitle,
                    beatmakerName: name,
                    genre: selectedGenre,
                    bpm: bpm,
                    key: selectedKey,
                    price: price,
                    priceTON: tonPrice,
                    coverImageData: coverImageData,
                    coverImageName: selectedCover,
                    audioFileURL: selectedFileURL
                )
                showSuccess = true
                try? await Task.sleep(for: .seconds(1.2))
                dismiss()
            } catch {
                isUploading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
