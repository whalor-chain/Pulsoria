import SwiftUI

/// Listener pastes or types a 6-char code to join a host's room.
struct JoinRoomSheet: View {
    @ObservedObject var rooms = ListeningRoomManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var code: String = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @FocusState private var codeFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.wave.2.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(theme.currentTheme.accent)
                        .padding(.top, 24)

                    Text(Loc.enterRoomCode)
                        .font(.custom(Loc.fontBold, size: 22))
                }

                TextField("ABC123", text: $code)
                    .textCase(.uppercase)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.custom(Loc.fontBold, size: 32).monospaced())
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .focused($codeFocused)
                    .onChange(of: code) { _, newValue in
                        let normalized = RoomCode.normalize(newValue)
                        // Cap length at the canonical code length so the
                        // field can't visually overflow.
                        code = String(normalized.prefix(RoomCode.length))
                    }

                Button {
                    joinTapped()
                } label: {
                    HStack(spacing: 8) {
                        if isJoining {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        Text(Loc.joinRoom)
                            .font(.custom(Loc.fontBold, size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .tint(theme.currentTheme.accent)
                .disabled(!RoomCode.isValid(code) || isJoining)

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle(Loc.joinRoom)
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
            } message: { message in
                Text(message)
            }
            .onAppear { codeFocused = true }
        }
    }

    private func joinTapped() {
        isJoining = true
        let submitted = code
        Task {
            do {
                try await rooms.joinRoom(code: submitted)
                isJoining = false
                dismiss()
            } catch {
                isJoining = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
