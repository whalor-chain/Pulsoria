import AVFoundation
import SwiftUI

/// Modal for adding a friend by their 6-character code (manual or QR).
/// Mirrors the `JoinRoomSheet` feel so the two flows read as a pair.
struct AddFriendSheet: View {
    @ObservedObject var manager = FriendsManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var code: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showAddedConfirm = false
    @State private var showScanner = false
    @State private var showCameraDenied = false
    @FocusState private var codeFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 42))
                    .foregroundStyle(theme.currentTheme.accent)
                    .padding(.top, 24)

                Text(Loc.addFriend)
                    .font(.custom(Loc.fontBold, size: 22))

                Text(Loc.friendCodeHint)
                    .font(.custom(Loc.fontMedium, size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField(Loc.friendCodePrompt, text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.custom(Loc.fontBold, size: 22).monospaced())
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 32)
                    .focused($codeFocused)
                    .onChange(of: code) { _, new in
                        code = String(new.uppercased().prefix(RoomCode.length))
                    }
                    .submitLabel(.done)
                    .onSubmit(submit)

                Button {
                    submit()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(Loc.addFriend)
                            .font(.custom(Loc.fontBold, size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .tint(theme.currentTheme.accent)
                .disabled(code.count != RoomCode.length || isSubmitting)
                .padding(.horizontal, 32)

                Button {
                    requestCameraAndScan()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                        Text(Loc.scanQR)
                            .font(.custom(Loc.fontMedium, size: 15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.glass)
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Loc.cancel) { dismiss() }
                }
            }
            .alert(Loc.errorTitle, isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ), presenting: errorMessage) { _ in
                Button("OK", role: .cancel) { }
            } message: { msg in
                Text(msg)
            }
            .alert(Loc.requestSent, isPresented: $showAddedConfirm) {
                Button("OK") { dismiss() }
            }
            .alert(Loc.cameraPermissionTitle, isPresented: $showCameraDenied) {
                Button(Loc.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(Loc.cancel, role: .cancel) { }
            } message: {
                Text(Loc.cameraPermissionMessage)
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView(
                    onCode: { raw in
                        showScanner = false
                        if let parsed = parsePulsoriaCode(from: raw) {
                            code = parsed
                            submit()
                        } else {
                            errorMessage = Loc.notFoundQR
                        }
                    },
                    onError: { msg in
                        showScanner = false
                        errorMessage = msg
                    }
                )
                .ignoresSafeArea()
            }
            .onAppear { codeFocused = true }
        }
    }

    /// Extracts a 6-char friend code from a scanned QR payload. Expects
    /// the `pulsoria://friend?code=ABC123` scheme we generate in
    /// `MyCodeSheet`, but also accepts a bare 6-char alphanumeric so
    /// users sharing codes via other channels still work. Returns nil
    /// for anything else (random URL, Wi-Fi QR, etc.).
    private func parsePulsoriaCode(from raw: String) -> String? {
        // Try the scheme URL first.
        if let url = URL(string: raw),
           url.scheme == "pulsoria",
           url.host == "friend",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
           RoomCode.isValid(code) {
            return code
        }
        // Fall back: bare 6-char alphanumeric string, e.g. someone just
        // wrote the code on a business card.
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if RoomCode.isValid(trimmed) { return trimmed }
        return nil
    }

    private func requestCameraAndScan() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { showScanner = true } else { showCameraDenied = true }
                }
            }
        case .denied, .restricted:
            showCameraDenied = true
        @unknown default:
            showCameraDenied = true
        }
    }

    private func submit() {
        guard code.count == RoomCode.length, !isSubmitting else { return }
        isSubmitting = true
        Task {
            do {
                try await manager.sendFriendRequest(byCode: code)
                isSubmitting = false
                showAddedConfirm = true
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
