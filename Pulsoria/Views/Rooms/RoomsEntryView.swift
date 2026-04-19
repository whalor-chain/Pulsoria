import SwiftUI

/// Top-level rooms surface. When the user is already in a room, shows the
/// live room view. Otherwise offers Start/Join actions.
struct RoomsEntryView: View {
    @ObservedObject var rooms = ListeningRoomManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        Group {
            if rooms.currentRoom != nil {
                ListeningRoomView()
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateRoomSheet()
        }
        .sheet(isPresented: $showJoin) {
            JoinRoomSheet()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.currentTheme.accent.opacity(0.5),
                                theme.currentTheme.secondary.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text(Loc.listeningRooms)
                    .font(.custom(Loc.fontBold, size: 22))
                Text(Loc.roomsHint)
                    .font(.custom(Loc.fontMedium, size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 10) {
                Button {
                    showCreate = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(Loc.startRoom)
                            .font(.custom(Loc.fontBold, size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .tint(theme.currentTheme.accent)

                Button {
                    showJoin = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle")
                        Text(Loc.joinRoom)
                            .font(.custom(Loc.fontMedium, size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}
