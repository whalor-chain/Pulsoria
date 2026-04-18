import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ImportReviewSheet: View {
    @Binding var stagedImports: [StagedImport]
    let onConfirm: () -> Void
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var editingIndex: Int = 0

    var body: some View {
        NavigationStack {
            List {
                ForEach(stagedImports.indices, id: \.self) { index in
                    importRow(index: index)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Loc.reviewImport)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        // Clean up temp files
                        for item in stagedImports {
                            try? FileManager.default.removeItem(at: item.sourceURL)
                        }
                        stagedImports.removeAll()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onConfirm()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.currentTheme.accent)
                    }
                    .disabled(stagedImports.contains {
                        $0.title.trimmingCharacters(in: .whitespaces).isEmpty ||
                        $0.artist.trimmingCharacters(in: .whitespaces).isEmpty
                    })
                }
            }
            .onChange(of: selectedPhoto) {
                guard let item = selectedPhoto else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        stagedImports[editingIndex].artworkData = data
                    }
                    selectedPhoto = nil
                }
            }
        }
    }

    @ViewBuilder
    private func importRow(index: Int) -> some View {
        // Artwork section
        Section {
            HStack {
                Spacer()
                let accent = theme.currentTheme.accent
                PhotosPicker(selection: Binding(
                    get: { selectedPhoto },
                    set: { newItem in
                        editingIndex = index
                        selectedPhoto = newItem
                    }
                ), matching: .images) {
                    if let data = stagedImports[index].artworkData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            )
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 4)
                                    .padding(6)
                            }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36, weight: .thin))
                                .foregroundStyle(.secondary)
                            Text(Loc.addCover)
                                .font(.custom(Loc.fontMedium, size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 140, height: 140)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(accent.opacity(0.1))
                                .strokeBorder(accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                        )
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .padding(.vertical, 8)
        }

        // Fields section with rounded corners
        Section {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(Loc.trackTitle)
                        .font(.custom(Loc.fontMedium, size: 15))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                    TextField(Loc.trackTitle, text: $stagedImports[index].title)
                        .font(.custom(Loc.fontMedium, size: 16))
                        .textInputAutocapitalization(.words)
                }
                HStack(spacing: 4) {
                    Image(systemName: stagedImports[index].foundTitle ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(stagedImports[index].foundTitle ? .green : .orange)
                    Text(stagedImports[index].foundTitle
                         ? (ThemeManager.shared.language == .russian ? "Найдено из метаданных" : "Found in metadata")
                         : (ThemeManager.shared.language == .russian ? "Не найдено, введите вручную" : "Not found, enter manually"))
                        .font(.custom(Loc.fontMedium, size: 11))
                        .foregroundStyle(stagedImports[index].foundTitle ? .green : .orange)
                }
            }

            // Artist
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(Loc.artist)
                        .font(.custom(Loc.fontMedium, size: 15))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                    TextField(Loc.artist, text: $stagedImports[index].artist)
                        .font(.custom(Loc.fontMedium, size: 16))
                        .textInputAutocapitalization(.words)
                }
                HStack(spacing: 4) {
                    Image(systemName: stagedImports[index].foundArtist ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(stagedImports[index].foundArtist ? .green : .orange)
                    Text(stagedImports[index].foundArtist
                         ? (ThemeManager.shared.language == .russian ? "Найдено из метаданных" : "Found in metadata")
                         : (ThemeManager.shared.language == .russian ? "Не найдено, введите вручную" : "Not found, enter manually"))
                        .font(.custom(Loc.fontMedium, size: 11))
                        .foregroundStyle(stagedImports[index].foundArtist ? .green : .orange)
                }
            }

            // Suggestion
            if stagedImports[index].suggestedTitle != nil || stagedImports[index].suggestedArtist != nil {
                let isRu = ThemeManager.shared.language == .russian
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.currentTheme.accent)
                        Text(isRu ? "Возможно, вы имели в виду:" : "Did you mean:")
                            .font(.custom(Loc.fontMedium, size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if let sTitle = stagedImports[index].suggestedTitle {
                                stagedImports[index].title = sTitle
                                stagedImports[index].suggestedTitle = nil
                            }
                            if let sArtist = stagedImports[index].suggestedArtist {
                                stagedImports[index].artist = sArtist
                                stagedImports[index].suggestedArtist = nil
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                if let sTitle = stagedImports[index].suggestedTitle {
                                    Text(sTitle)
                                        .font(.custom(Loc.fontBold, size: 14))
                                        .foregroundStyle(.primary)
                                }
                                if let sArtist = stagedImports[index].suggestedArtist {
                                    Text(sArtist)
                                        .font(.custom(Loc.fontMedium, size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(theme.currentTheme.accent)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme.currentTheme.accent.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // File info
            HStack {
                Text(Loc.fileInfo)
                    .font(.custom(Loc.fontMedium, size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .leading)
                Spacer()
                Text(stagedImports[index].fileExtension.uppercased())
                    .font(.custom(Loc.fontMedium, size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.secondary.opacity(0.15)))
                Text(stagedImports[index].fileSize)
                    .font(.custom(Loc.fontMedium, size: 13))
                    .foregroundStyle(.secondary)
                Text(stagedImports[index].fileDuration)
                    .font(.custom(Loc.fontMedium, size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .listSectionSpacing(8)
    }
}


