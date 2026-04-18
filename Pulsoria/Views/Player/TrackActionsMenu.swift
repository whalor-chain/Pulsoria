import SwiftUI

// MARK: - Track Actions Menu (isolated from player observation)

struct TrackActionsMenu: View {
    @Binding var showAddToPlaylist: Bool
    var onShare: () -> Void = {}

    var body: some View {
        Menu {
            Section {
                Button {
                    AudioPlayerManager.shared.addCurrentTrackToQueue()
                } label: {
                    Label(Loc.addToQueue, systemImage: "text.line.last.and.arrowtriangle.forward")
                        .imageScale(.large)
                }

                Button {
                    showAddToPlaylist = true
                } label: {
                    Label(Loc.addToPlaylist, systemImage: "text.badge.plus")
                        .imageScale(.large)
                }

                Button {
                    onShare()
                } label: {
                    Label(Loc.share, systemImage: "square.and.arrow.up")
                        .imageScale(.large)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .glassEffect(.regular, in: .circle)
        }
    }
}

