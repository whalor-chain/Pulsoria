import SwiftUI

// MARK: - Shimmer

/// A diagonal "shine" that slides across the view in a repeating
/// loop, signalling loading content. Paired with flat `Skeleton`
/// rectangles, it turns otherwise empty placeholders into living
/// UI — hands down more modern than a `ProgressView` spinner.
///
/// Driven by `TimelineView(.animation)` rather than `withAnimation +
/// onAppear` so the loop survives view re-renders and doesn't need
/// to be manually kicked off.
struct ShimmerModifier: ViewModifier {
    var duration: Double = 1.4

    func body(content: Content) -> some View {
        content.overlay(
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
                GeometryReader { geo in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let phase = (t.truncatingRemainder(dividingBy: duration)) / duration
                    let width = geo.size.width

                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0),    location: 0.35),
                            .init(color: .white.opacity(0.55), location: 0.50),
                            .init(color: .white.opacity(0),    location: 0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: width * 3)
                    // Runs the shine from far-left to far-right each
                    // cycle — offset in multiples of width so the band
                    // fully exits before the next pass begins.
                    .offset(x: (CGFloat(phase) * 3 - 1.5) * width)
                    .blendMode(.plusLighter)
                }
            }
            .mask(content)
            .allowsHitTesting(false)
        )
    }
}

extension View {
    /// Adds a travelling shine overlay masked by the view's own
    /// shape. Use on solid-filled skeleton shapes; real UI doesn't
    /// need it.
    func shimmering(duration: Double = 1.4) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
}

// MARK: - Skeleton

/// Tinted, shimmering rounded rectangle — the atom of all skeleton
/// layouts. Pick a height/width that matches the real content that
/// will replace it so the swap is visually stable.
struct Skeleton: View {
    var cornerRadius: CGFloat = 8
    /// Override when the surrounding surface is already tinted (e.g.
    /// a coloured card background) so the skeleton doesn't blend in.
    var fill: Color = Color(.tertiarySystemFill)

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(fill)
            .shimmering()
    }
}

/// Circular skeleton — avatars, artist photos, round buttons.
struct SkeletonCircle: View {
    var fill: Color = Color(.tertiarySystemFill)

    var body: some View {
        Circle()
            .fill(fill)
            .shimmering()
    }
}
