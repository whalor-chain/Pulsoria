import SwiftUI
import PhotosUI
import AuthenticationServices

struct SettingsView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var store = BeatStoreManager.shared
    @ObservedObject var auth = AuthManager.shared

    @AppStorage(UserDefaultsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = true
    @AppStorage(UserDefaultsKey.userNickname) private var userNickname = ""
    @State private var showResetAlert = false
    @State private var showLanguagePicker = false
    @State private var showRolePicker = false
    @State private var showProfileEditor = false
    @State private var showSignOutAlert = false
    @State private var profileImage: UIImage? = SettingsView.loadProfileImage()
    var hideTitle = false

    var body: some View {
        NavigationStack {
            List {
                profileHeader

                // Appearance & Language
                Section {
                    NavigationLink {
                        AppearanceView()
                    } label: {
                        Label {
                            HStack {
                                Text(Loc.appearance)
                                Spacer()
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [theme.currentTheme.accent, theme.currentTheme.secondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 22, height: 22)
                            }
                        } icon: {
                            Image(systemName: "paintbrush.fill")
                                .foregroundStyle(theme.currentTheme.accent)
                        }
                    }

                    Button {
                        showLanguagePicker.toggle()
                    } label: {
                        Label {
                            HStack {
                                Text(Loc.language)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(theme.language.displayName)
                                    .font(.custom(Loc.fontMedium, size: 15))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(theme.currentTheme.accent.opacity(0.3))
                                    )
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                            }
                        } icon: {
                            Image(systemName: "globe")
                                .foregroundStyle(theme.currentTheme.accent)
                        }
                    }
                    .popover(isPresented: $showLanguagePicker) {
                        GlassEffectContainer {
                            VStack(spacing: 4) {
                                ForEach(AppLanguage.allCases, id: \.self) { lang in
                                    Button {
                                        withAnimation(.smooth(duration: 0.3)) {
                                            theme.language = lang
                                        }
                                        showLanguagePicker = false
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(lang.flag)
                                                .font(.title3)
                                            Text(lang.displayName)
                                            Spacer()
                                            if theme.language == lang {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(theme.currentTheme.accent)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.glass)
                                    .sensoryFeedback(.selection, trigger: theme.language)
                                }
                            }
                            .padding(8)
                        }
                        .presentationCompactAdaptation(.popover)
                    }
                }

                Section {
                    NavigationLink {
                        MusicSettingsView()
                    } label: {
                        Label {
                            Text(Loc.music)
                        } icon: {
                            Image(systemName: "music.note")
                                .foregroundStyle(theme.currentTheme.accent)
                        }
                    }
                }

                roleSection
                if store.userRole != .listener {
                    shopSection
                }
                actionsSection
                accountSection
                aboutSection
            }
            .contentMargins(.bottom, 80, for: .scrollContent)
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("SettingsLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 52)
                        .foregroundStyle(theme.currentTheme.accent)
                }
            }
            .onAppear {
                auth.checkCredentialState()
            }
            .alert(Loc.resetFavoritesQ, isPresented: $showResetAlert) {
                Button(Loc.cancel, role: .cancel) { }
                Button(Loc.reset, role: .destructive) {
                    for i in player.tracks.indices {
                        player.tracks[i].isFavorite = false
                    }
                    UserDefaults.standard.removeObject(forKey: UserDefaultsKey.favoriteTrackIDs)
                }
            } message: {
                Text(Loc.resetFavoritesMsg)
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        Section {
            Button {
                showProfileEditor = true
            } label: {
                HStack(spacing: 16) {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(theme.currentTheme.accent)
                    }

                    Text(userNickname.isEmpty ? "Pulsoria" : userNickname)
                        .font(.custom(Loc.fontBold, size: 22))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                }
            }
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditorSheet(
                nickname: $userNickname,
                profileImage: $profileImage
            )
        }
    }

    // MARK: - Profile Image Helpers

    static func loadProfileImage() -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_photo.jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func saveProfileImage(_ image: UIImage?) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_photo.jpg")
        if let image, let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Account (Apple ID)

    @ViewBuilder
    private var accountSection: some View {
        if auth.isSignedIn {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 20))
                            .foregroundStyle(theme.currentTheme.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.userName.isEmpty ? "Apple ID" : auth.userName)
                                .font(.custom(Loc.fontBold, size: 16))
                            Text(auth.userEmail.isEmpty ? Loc.appleIdConnected : auth.userEmail)
                                .font(.custom(Loc.fontMedium, size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }

                Button(role: .destructive) {
                    showSignOutAlert = true
                } label: {
                    Label {
                        Text(Loc.signOut)
                    } icon: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }
            }
            .alert(Loc.signOutConfirm, isPresented: $showSignOutAlert) {
                Button(Loc.cancel, role: .cancel) { }
                Button(Loc.signOut, role: .destructive) {
                    auth.signOut()
                }
            }
        }
    }

    // MARK: - Library Stats

    // MARK: - Role

    private var roleSection: some View {
        Section {
            Button {
                showRolePicker.toggle()
            } label: {
                Label {
                    HStack {
                        Text(Loc.role)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(store.userRole.localizedName)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(theme.currentTheme.accent.opacity(0.3))
                            )
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(UIColor.tertiaryLabel))
                    }
                } icon: {
                    Image(systemName: "person.fill")
                        .foregroundStyle(theme.currentTheme.accent)
                }
            }
            .popover(isPresented: $showRolePicker) {
                GlassEffectContainer {
                    VStack(spacing: 4) {
                        ForEach(UserRole.allCases) { role in
                            Button {
                                withAnimation(.smooth(duration: 0.3)) {
                                    store.userRole = role
                                }
                                showRolePicker = false
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: role.icon)
                                        .font(.title3)
                                    Text(role.localizedName)
                                    Spacer()
                                    if store.userRole == role {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(theme.currentTheme.accent)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.glass)
                            .sensoryFeedback(.selection, trigger: store.userRole)
                        }
                    }
                    .padding(8)
                }
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    // MARK: - TON Wallet

    // MARK: - Shop Stats

    private var shopSection: some View {
        Section(Loc.shop) {
            NavigationLink {
                PurchaseHistoryView()
            } label: {
                Label {
                    HStack {
                        Text(Loc.purchaseHistory)
                        Spacer()
                        Text("\(store.totalPurchasesCount)")
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bag.fill")
                        .foregroundStyle(theme.currentTheme.accent)
                }
            }

            NavigationLink {
                ShopStatsView()
            } label: {
                Label {
                    HStack {
                        Text(Loc.statistics)
                        Spacer()
                    }
                } icon: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(theme.currentTheme.accent)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            Button {
                hasCompletedOnboarding = false
            } label: {
                Label(Loc.showOnboarding, systemImage: "hand.wave")
            }

            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label {
                    Text(Loc.resetFavorites)
                } icon: {
                    Image(systemName: "heart.slash")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            VStack(spacing: 12) {
                Image("NotLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("Pulsoria")
                    .font(.custom(Loc.fontBold, size: 20))

                Text("\(Loc.version) 1.0.0")
                    .font(.custom(Loc.fontMedium, size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
        .listSectionSpacing(0)
    }
}
