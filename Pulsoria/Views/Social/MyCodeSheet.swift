import CoreImage.CIFilterBuiltins
import SwiftUI

/// Shows the user's own shareable friend code with a copy-to-clipboard
/// action. Previously lived inline at the top of `FriendsListView`;
/// pulled into a sheet so the list is dedicated to friends.
struct MyCodeSheet: View {
    @ObservedObject var manager = FriendsManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 12)

                FriendAvatarView(
                    displayName: displayName,
                    avatarURL: manager.myAvatarURL,
                    size: 72
                )

                Text(displayName)
                    .font(.custom(Loc.fontBold, size: 18))
                    .lineLimit(1)

                qrCard
                    .padding(.horizontal, 24)

                codeCard
                    .padding(.horizontal, 24)

                Text(Loc.friendCodeHint)
                    .font(.custom(Loc.fontMedium, size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
        }
    }

    private var displayName: String {
        let nickname = UserDefaults.standard.string(forKey: UserDefaultsKey.userNickname)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if !nickname.isEmpty { return nickname }
        let appleName = AuthManager.shared.userName.trimmingCharacters(in: .whitespaces)
        return appleName.isEmpty ? "Pulsoria" : appleName
    }

    private var codeCard: some View {
        VStack(spacing: 10) {
            Text(manager.myFriendCode.isEmpty ? "——————" : manager.myFriendCode)
                .font(.custom(Loc.fontBold, size: 32).monospaced())
                .foregroundStyle(theme.currentTheme.accent)
                .tracking(2)

            Button {
                copyCode()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .symbolEffect(.bounce, value: copied)
                    Text(copied ? Loc.done : Loc.copy)
                        .font(.custom(Loc.fontBold, size: 15))
                }
                .foregroundStyle(copied ? .green : theme.currentTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.glass)
            .disabled(manager.myFriendCode.isEmpty)
            .sensoryFeedback(.success, trigger: copied)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var qrCard: some View {
        VStack {
            if let image = qrImage() {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 170, height: 170)
                    .overlay {
                        ProgressView()
                    }
            }
        }
    }

    /// Generates a QR image from the user's friend code. `.none`
    /// interpolation keeps the squares crisp at any render size.
    /// Payload is prefixed with the `pulsoria://friend?code=` scheme so
    /// the scanner can recognize it as a Pulsoria code and reject any
    /// other random QR the user might accidentally point at.
    private func qrImage() -> UIImage? {
        let code = manager.myFriendCode
        guard !code.isEmpty else { return nil }
        let payload = "pulsoria://friend?code=\(code)"

        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let ci = filter.outputImage else { return nil }
        // Upscale so the resulting bitmap is crisp at the display size.
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func copyCode() {
        guard !manager.myFriendCode.isEmpty else { return }
        UIPasteboard.general.string = manager.myFriendCode
        withAnimation(.spring(duration: 0.3)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied = false }
        }
    }
}
