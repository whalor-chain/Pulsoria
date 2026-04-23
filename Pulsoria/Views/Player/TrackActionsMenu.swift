import SwiftUI

// MARK: - Track Actions Menu (isolated from player observation)

struct TrackActionsMenu: View {
    @Binding var showAddToPlaylist: Bool
    var onShare: () -> Void = {}
    /// Tint for the ellipsis button. PlayerView passes its
    /// palette-aware `activeAccent` so the menu trigger matches the
    /// current cover; callers that don't care can omit and get
    /// `.primary`.
    var tint: Color = .primary

    var body: some View {
        Menu {
            // Dispatch all actions to the next main-runloop tick. When
            // a Menu item is tapped the Menu starts its dismiss
            // transition, and SwiftUI loses any state mutation or
            // sheet-presentation that happens *inside* that window —
            // the buttons visually "flashed" but nothing happened
            // downstream. Queuing to `main.async` lets the Menu
            // finish unwinding first, then our state change fires
            // and the sheet reliably presents.
            Button(Loc.addToQueue, systemImage: "text.line.last.and.arrowtriangle.forward") {
                DispatchQueue.main.async {
                    AudioPlayerManager.shared.addCurrentTrackToQueue()
                }
            }

            Button(Loc.addToPlaylist, systemImage: "text.badge.plus") {
                DispatchQueue.main.async {
                    showAddToPlaylist = true
                }
            }

            Button(Loc.share, systemImage: "square.and.arrow.up") {
                DispatchQueue.main.async {
                    onShare()
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }
}

