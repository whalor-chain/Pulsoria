import SwiftUI

/// Active room UI — playback header, participants, chat pane, leave button.
struct ListeningRoomView: View {
    @ObservedObject var rooms = ListeningRoomManager.shared
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var chatInput: String = ""
    @State private var showLeaveConfirm = false
    @State private var showTrackPicker = false
    @FocusState private var chatFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let room = rooms.currentRoom {
                header(for: room)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                if rooms.isHost {
                    hostControls
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                } else {
                    participantFooter(for: room)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                Divider()
                    .padding(.top, 16)

                chatPane
            } else {
                // Room vanished (host ended, network dropped) — show a
                // graceful stub while the environment transitions back.
                ContentUnavailableView(
                    Loc.roomEndedByHost,
                    systemImage: "person.2.slash.fill"
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(Loc.leaveRoom, isPresented: $showLeaveConfirm) {
            Button(Loc.cancel, role: .cancel) { }
            Button(rooms.isHost ? Loc.endRoom : Loc.leaveRoom, role: .destructive) {
                rooms.leaveRoom()
            }
        } message: {
            Text(rooms.isHost
                 ? (theme.language == .russian
                    ? "Закрыть комнату для всех участников?"
                    : "End this room for everyone?")
                 : (theme.language == .russian
                    ? "Выйти из комнаты?"
                    : "Leave this room?"))
        }
        .sheet(isPresented: $showTrackPicker) {
            HostTrackPickerSheet()
        }
        // Keep the room in sync with the host's local player — if the
        // host auto-advances (end-of-track) or manually jumps to another
        // track outside the picker, push that to Firestore so listeners
        // follow along.
        .onChange(of: player.currentTrack) { _, newTrack in
            guard rooms.isHost,
                  let newTrack,
                  let room = rooms.currentRoom,
                  newTrack.fileName != room.playback.trackFileName else { return }
            Task { try? await rooms.hostSwitchTrack(to: newTrack) }
        }
    }

    // MARK: - Header

    private func header(for room: ListeningRoom) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Loc.roomCode)
                        .font(.custom(Loc.fontMedium, size: 11))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                    Text(room.id ?? "—")
                        .font(.custom(Loc.fontBold, size: 28).monospaced())
                        .foregroundStyle(theme.currentTheme.accent)
                }

                Spacer()

                Button {
                    showLeaveConfirm = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(rooms.isHost ? Loc.endRoom : Loc.leaveRoom)
            }

            // Now-playing strip.
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [theme.currentTheme.accent.opacity(0.5), theme.currentTheme.secondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: room.playback.isPlaying ? "waveform" : "pause.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse, options: .repeating, isActive: room.playback.isPlaying)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(room.playback.trackTitle)
                        .font(.custom(Loc.fontBold, size: 16))
                        .lineLimit(1)
                    Text(room.playback.trackArtist)
                        .font(.custom(Loc.fontMedium, size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !hasMatchingLocalTrack(fileName: room.playback.trackFileName) && !rooms.isHost {
                        if room.playback.streamURL != nil {
                            Text(theme.language == .russian
                                 ? "Стрим от хоста"
                                 : "Streaming from host")
                                .font(.custom(Loc.fontMedium, size: 11))
                                .foregroundStyle(theme.currentTheme.accent)
                                .lineLimit(1)
                                .padding(.top, 2)
                        } else {
                            Text(theme.language == .russian
                                 ? "Загружается у хоста…"
                                 : "Host is uploading…")
                                .font(.custom(Loc.fontMedium, size: 11))
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }
                }
                Spacer()
            }

            // Participants pill row.
            participantsRow(for: room)
        }
    }

    private func participantsRow(for room: ListeningRoom) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("\(room.participants.count) · \(room.hostName) \(Loc.hostLabel.lowercased())")
                .font(.custom(Loc.fontMedium, size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Host controls

    private var hostControls: some View {
        HStack(spacing: 16) {
            Button {
                Task {
                    try? await rooms.hostPlay(
                        offset: player.currentTime,
                        duration: player.duration
                    )
                    player.play()
                }
            } label: {
                Image(systemName: "play.fill")
                    .frame(width: 48, height: 48)
                    .symbolEffect(.bounce, value: player.isPlaying)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(Loc.a11yPlay)

            Button {
                Task {
                    try? await rooms.hostPause(at: player.currentTime)
                    player.pause()
                }
            } label: {
                Image(systemName: "pause.fill")
                    .frame(width: 48, height: 48)
                    .symbolEffect(.bounce, value: player.isPlaying)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(Loc.a11yPause)

            Button {
                showTrackPicker = true
            } label: {
                Image(systemName: "music.note.list")
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(theme.language == .russian ? "Сменить трек" : "Change track")

            Spacer()
        }
    }

    // MARK: - Participant footer

    private func participantFooter(for room: ListeningRoom) -> some View {
        HStack {
            Image(systemName: room.playback.isPlaying ? "waveform.circle" : "pause.circle")
                .foregroundStyle(room.playback.isPlaying ? theme.currentTheme.accent : .secondary)
            Text(room.playback.isPlaying
                 ? (theme.language == .russian ? "Играет у хоста" : "Playing with host")
                 : (theme.language == .russian ? "Пауза" : "Paused"))
                .font(.custom(Loc.fontMedium, size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Chat

    private var chatPane: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if rooms.messages.isEmpty {
                            Text(Loc.noMessagesYet)
                                .font(.custom(Loc.fontMedium, size: 13))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 32)
                        } else {
                            ForEach(rooms.messages) { message in
                                chatBubble(for: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: rooms.messages.count) { _, _ in
                    if let last = rooms.messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            HStack(spacing: 10) {
                TextField(Loc.writeMessage, text: $chatInput, axis: .vertical)
                    .font(.custom(Loc.fontMedium, size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
                    .lineLimit(1...4)
                    .focused($chatFocused)
                    .submitLabel(.send)
                    .onSubmit(send)

                Button {
                    send()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(theme.currentTheme.accent)
                        )
                }
                .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel(Loc.send)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private func chatBubble(for message: RoomChatMessage) -> some View {
        let isMe = message.senderID == AuthManager.shared.appleUserID
        return VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
            if !isMe {
                Text(message.senderName)
                    .font(.custom(Loc.fontMedium, size: 11))
                    .foregroundStyle(.secondary)
            }
            Text(message.text)
                .font(.custom(Loc.fontMedium, size: 14))
                .foregroundStyle(isMe ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isMe
                              ? AnyShapeStyle(theme.currentTheme.accent)
                              : AnyShapeStyle(Color(.systemGray6)))
                )
        }
        .frame(maxWidth: .infinity, alignment: isMe ? .trailing : .leading)
    }

    private func send() {
        let text = chatInput
        chatInput = ""
        Task {
            try? await rooms.sendMessage(text)
        }
    }

    // MARK: - Helpers

    private func hasMatchingLocalTrack(fileName: String) -> Bool {
        player.tracks.contains { $0.fileName == fileName }
    }
}
