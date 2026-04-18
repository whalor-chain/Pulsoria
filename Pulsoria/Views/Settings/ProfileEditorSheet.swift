import SwiftUI
import PhotosUI

struct ProfileEditorSheet: View {
    @Binding var nickname: String
    @Binding var profileImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var theme = ThemeManager.shared

    @State private var editedNickname = ""
    @State private var editedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var showRemovePhotoConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // Photo section
                Section {
                    VStack(spacing: 16) {
                        if let editedImage {
                            Image(uiImage: editedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 100))
                                .foregroundStyle(theme.currentTheme.accent)
                        }

                        HStack(spacing: 16) {
                            let accent = theme.currentTheme.accent
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text(Loc.choosePhoto)
                                    .font(.custom(Loc.fontMedium, size: 15))
                                    .foregroundStyle(accent)
                            }

                            if editedImage != nil {
                                Button {
                                    showRemovePhotoConfirm = true
                                } label: {
                                    Text(Loc.removePhoto)
                                        .font(.custom(Loc.fontMedium, size: 15))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                // Nickname section
                Section(Loc.nickname) {
                    TextField("Pulsoria", text: $editedNickname)
                        .font(.custom(Loc.fontMedium, size: 17))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        nickname = editedNickname.trimmingCharacters(in: .whitespaces)
                        profileImage = editedImage
                        SettingsView.saveProfileImage(editedImage)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.currentTheme.accent)
                    }
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                guard let newValue else { return }
                Task { @MainActor in
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        editedImage = image
                    }
                }
            }
            .alert(Loc.removePhoto, isPresented: $showRemovePhotoConfirm) {
                Button(Loc.cancel, role: .cancel) { }
                Button(Loc.removePhoto, role: .destructive) {
                    editedImage = nil
                }
            }
        }
        .onAppear {
            editedNickname = nickname
            editedImage = profileImage
        }
    }
}
