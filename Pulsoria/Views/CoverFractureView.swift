import SwiftUI
import UIKit

/// Diagonal brush-wipe transition between album covers. Old cover is
/// "painted over" with progressive blur as a soft-edged gradient sweeps
/// from the top-leading to the bottom-trailing corner; new cover is
/// revealed sharp under that same sweep. Feels like a hand brushing
/// water onto paint.
///
/// Usage:
///
///     .overlay { CoverBrushTransitionView(snapshot: brushSnapshot) }
///
/// Where `brushSnapshot` is a `CoverBrushSnapshot` the parent view
/// builds at the moment of track change and clears once the animation
/// finishes (~0.85 s).
struct CoverBrushTransitionView: View {
    let snapshot: CoverBrushSnapshot
    let size: CGFloat
    let cornerRadius: CGFloat

    /// Width of the soft gradient feather that is the brush tip.
    /// Larger = softer transition, smaller = crisper.
    private let band: CGFloat = 0.32

    /// Progress range extends past [0,1] by half the band on each side
    /// so the feather fully enters and fully exits the frame —
    /// otherwise the top-leading corner starts half-swept and a
    /// bottom-trailing strip never gets swept at all, leaving visible
    /// fragments of the old cover on the new.
    private var start: CGFloat { -band / 2 }
    private var end: CGFloat { 1 + band / 2 }

    @State private var progress: CGFloat

    init(snapshot: CoverBrushSnapshot, size: CGFloat, cornerRadius: CGFloat) {
        self.snapshot = snapshot
        self.size = size
        self.cornerRadius = cornerRadius
        // Seed the state at the "before" edge so the view starts with
        // the old cover fully visible — no matter what @State leftover
        // a previous instance carried (belt + the `.id(token)` braces).
        self._progress = State(initialValue: -0.16)
    }

    var body: some View {
        ZStack {
            // New cover — revealed as the brush passes.
            Image(uiImage: snapshot.newImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .mask(revealMask)

            // Old cover — progressively blurred while the brush sweeps
            // across, and its visibility retreats along the same axis.
            Image(uiImage: snapshot.oldImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .blur(radius: max(0, progress) * 22)
                .mask(fadeOutMask)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            // Force the "before" state on the current tick, then fire
            // the animation on the next runloop iteration. SwiftUI
            // occasionally coalesces a same-tick `progress = x;
            // withAnimation { progress = y }` pair into a single
            // non-animated jump, which would skip the brush entirely.
            progress = start
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.9)) {
                    progress = end
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Mask for the **new** cover. At `progress ≤ 0` the whole mask is
    /// clear (new hidden); at `progress ≥ 1` the whole mask is black
    /// (new fully visible). Feather in between is the brush tip.
    private var revealMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: clamp(progress - band / 2)),
                .init(color: .clear, location: clamp(progress + band / 2)),
                .init(color: .clear, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Mask for the **old** cover. Mirror of `revealMask` — black
    /// everywhere at `progress ≤ 0` (old visible), clear everywhere at
    /// `progress ≥ 1` (old fully wiped).
    private var fadeOutMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: clamp(progress - band / 2)),
                .init(color: .black, location: clamp(progress + band / 2)),
                .init(color: .black, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func clamp(_ v: CGFloat) -> CGFloat { min(1, max(0, v)) }
}

/// A pair of images (outgoing + incoming cover) plus a token so we can
/// force a re-play of the animation even if the two images are the same.
struct CoverBrushSnapshot: Equatable {
    let oldImage: UIImage
    let newImage: UIImage
    let token: UUID

    static func == (lhs: CoverBrushSnapshot, rhs: CoverBrushSnapshot) -> Bool {
        lhs.token == rhs.token
    }

    static func make(old: UIImage, new: UIImage) -> CoverBrushSnapshot {
        CoverBrushSnapshot(oldImage: old, newImage: new, token: UUID())
    }
}
