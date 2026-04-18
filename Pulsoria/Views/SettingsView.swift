import SwiftUI
import PhotosUI
import AuthenticationServices

struct SettingsView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var store = BeatStoreManager.shared
    @ObservedObject var auth = AuthManager.shared

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("userNickname") private var userNickname = ""
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
                    UserDefaults.standard.removeObject(forKey: "favoriteTrackIDs")
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

// MARK: - Profile Editor Sheet

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

// MARK: - App Icon Variants

enum AppIconVariant: String, CaseIterable, Identifiable {
    case default_ = "Default"
    case dark = "Dark"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case neon = "Neon"
    case mint = "Mint"

    var id: String { rawValue }

    var iconName: String? {
        switch self {
        case .default_: return nil
        default: return "AppIcon-\(rawValue)"
        }
    }

    var displayName: String {
        let ru = ThemeManager.shared.language == .russian
        switch self {
        case .default_: return Loc.defaultIcon
        case .dark: return ru ? "Тёмная" : "Dark"
        case .ocean: return ru ? "Океан" : "Ocean"
        case .sunset: return ru ? "Закат" : "Sunset"
        case .neon: return ru ? "Неон" : "Neon"
        case .mint: return ru ? "Мята" : "Mint"
        }
    }

    var preview: UIImage {
        let name: String
        switch self {
        case .default_: name = "AppIcon-Default"
        default: name = "AppIcon-\(rawValue)"
        }
        // Load from bundle (not asset catalog)
        if let img = UIImage(named: "\(name)@3x.png")
            ?? UIImage(named: "\(name)@3x")
            ?? UIImage(named: name) {
            return img
        }
        // Fallback: load from the bundle path directly
        if let path = Bundle.main.path(forResource: "\(name)@3x", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        return UIImage(systemName: "app.fill") ?? UIImage()
    }
}

// MARK: - Music Settings

struct MusicSettingsView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared

    var body: some View {
        List {
            crossfadeSection
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .navigationTitle(Loc.music)
    }

    private var crossfadeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    HStack {
                        Text(Loc.crossfade)
                        Spacer()
                        Text(player.crossfadeDuration > 0 ? "\(Int(player.crossfadeDuration)) \(Loc.seconds)" : Loc.off)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: player.crossfadeDuration > 0 ? "apple.haptics.and.music.note" : "apple.haptics.and.music.note.slash")
                        .foregroundStyle(theme.currentTheme.accent)
                }

                Slider(
                    value: $player.crossfadeDuration,
                    in: 0...12,
                    step: 1
                )
                .tint(theme.currentTheme.accent)

                Text(Loc.crossfadeHint)
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - TON Wallet Sheet

struct TonWalletSheet: View {
    @ObservedObject var tonWallet = TonWalletManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDisconnectAlert = false

    var body: some View {
        NavigationStack {
            List {
                if tonWallet.isConnected {
                    connectedSection
                } else if tonWallet.isConnecting {
                    connectingSection
                } else {
                    connectSection
                }
                infoSection
            }
            .navigationTitle("TON Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.currentTheme.accent)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert(Loc.disconnect, isPresented: $showDisconnectAlert) {
                Button(Loc.cancel, role: .cancel) { }
                Button(Loc.disconnect, role: .destructive) {
                    tonWallet.disconnectWallet()
                }
            } message: {
                Text(Loc.disconnectWalletMsg)
            }
        }
    }

    // MARK: - Connected

    private var connectedSection: some View {
        Section {
            HStack(spacing: 12) {
                Image("TonkeeperIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(Loc.connected)
                        .font(.custom(Loc.fontBold, size: 16))
                        .foregroundStyle(.green)

                    Text(abbreviatedAddress(tonWallet.walletAddress))
                        .font(.custom("Menlo", size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = tonWallet.walletAddress
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(theme.currentTheme.accent)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text(Loc.balance)
                    .font(.custom(Loc.fontMedium, size: 15))
                Spacer()
                if tonWallet.isLoadingBalance {
                    ProgressView()
                } else {
                    Text(tonWallet.formattedBalance)
                        .font(.custom(Loc.fontBold, size: 15))
                        .foregroundStyle(.cyan)
                }
            }

            Button {
                Task { await tonWallet.fetchBalance() }
            } label: {
                Label(Loc.refreshBalance, systemImage: "arrow.clockwise")
                    .font(.custom(Loc.fontMedium, size: 15))
            }

            Button(role: .destructive) {
                showDisconnectAlert = true
            } label: {
                Label(Loc.disconnect, systemImage: "xmark.circle")
                    .font(.custom(Loc.fontMedium, size: 15))
            }
        }
    }

    // MARK: - Connecting (waiting for wallet)

    private var connectingSection: some View {
        Section {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.cyan)

                Text(Loc.waitingForWallet)
                    .font(.custom(Loc.fontMedium, size: 16))
                    .multilineTextAlignment(.center)

                if let error = tonWallet.connectionError {
                    Text(error)
                        .font(.custom(Loc.fontMedium, size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    tonWallet.disconnectWallet()
                } label: {
                    Text(Loc.cancel)
                        .font(.custom(Loc.fontMedium, size: 15))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Connect (one-tap)

    @ViewBuilder
    private var connectSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.cyan)

                Text(Loc.connectTonWallet)
                    .font(.custom(Loc.fontBold, size: 18))

                Text(Loc.connectTonHint)
                    .font(.custom(Loc.fontMedium, size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)

        }

        Section {
            // TON Connect via Tonkeeper
            Button {
                tonWallet.connectViaTonConnect()
            } label: {
                HStack(spacing: 12) {
                    Image("TonkeeperIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Loc.connectViaTonkeeper)
                            .font(.custom(Loc.fontBold, size: 16))
                            .foregroundStyle(.primary)
                        Text(Loc.oneTapConnect)
                            .font(.custom(Loc.fontMedium, size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.cyan)
                }
            }

            // TON Connect via Telegram @wallet
            Button {
                tonWallet.connectViaTelegram()
            } label: {
                HStack(spacing: 12) {
                    Image("TelegramWalletIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Loc.connectViaTelegram)
                            .font(.custom(Loc.fontBold, size: 16))
                            .foregroundStyle(.primary)
                        Text("TON Connect")
                            .font(.custom(Loc.fontMedium, size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            Label {
                Text(Loc.tonWalletInfo)
                    .font(.custom(Loc.fontMedium, size: 13))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func abbreviatedAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))...\(address.suffix(6))"
    }
}
