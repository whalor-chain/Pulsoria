import SwiftUI

/// Cover-aware animated background for PlayerView. Pulls a 4-colour
/// palette from the current track's artwork via `CoverPaletteManager`
/// and renders it as a 3×3 `MeshGradient` whose inner control points
/// drift on a slow elliptical path — the gradient never quite sits
/// still, so the player feels alive without being distracting.
///
/// Track changes crossfade the palette (`.animation(.easeInOut)` on
/// the underlying state), so album-to-album transitions don't flash.
struct CoverGradientBackground: View {
    let fileName: String?
    let fallbackPalette: CoverPalette
    @ObservedObject private var palettes = CoverPaletteManager.shared

    /// Last palette we actually rendered. Held across track changes
    /// so the mesh doesn't snap to the theme-derived fallback between
    /// the moment the new track becomes current and the moment its
    /// palette finishes extracting — that snap read as a sharp
    /// purple flash on screen.
    @State private var lastPalette: CoverPalette?

    /// Drives the inner-point wobble. `TimelineView(.animation)` gives
    /// us a smooth ~60 Hz clock without manual `withAnimation`, and
    /// pauses automatically when the view isn't on screen.
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 40.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let palette = resolvedPalette
            let points = wobblingPoints(at: t)

            MeshGradient(
                width: 3,
                height: 3,
                points: points,
                colors: palette.meshColors,
                smoothsColors: true
            )
            .animation(.easeInOut(duration: 0.8), value: palette)
        }
        .onAppear { syncLastPalette() }
        .onChange(of: fileName) { _, _ in syncLastPalette() }
        .onChange(of: palettes.cache) { _, _ in syncLastPalette() }
    }

    // MARK: - Palette resolution

    private var resolvedPalette: CoverPalette {
        if let fn = fileName, let p = palettes.palette(for: fn) {
            return p
        }
        // Hold the previous palette during the extraction gap so the
        // mesh doesn't briefly snap to the theme-coloured fallback.
        return lastPalette ?? fallbackPalette
    }

    private func syncLastPalette() {
        guard let fn = fileName, let p = palettes.palette(for: fn) else { return }
        lastPalette = p
    }

    // MARK: - Animated control points

    /// 3×3 mesh. Corners stay nailed down (0,0) / (1,0) / (0,1) / (1,1),
    /// edge midpoints stay on their edges but drift ±0.03 along the
    /// edge, and the centre point wanders in a small ellipse. The
    /// whole thing completes a loop every ~18 s — slow enough that
    /// the eye reads it as breathing rather than motion.
    private func wobblingPoints(at t: TimeInterval) -> [SIMD2<Float>] {
        let period: Double = 18
        let phase = (t.truncatingRemainder(dividingBy: period)) / period * 2 * .pi

        let edgeWobble: Float = 0.035
        let centerWobbleX: Float = 0.07
        let centerWobbleY: Float = 0.05

        let ew = Float(sin(phase))
        let ew2 = Float(sin(phase + .pi / 2))

        return [
            SIMD2(0, 0),
            SIMD2(0.5 + edgeWobble * ew, 0),
            SIMD2(1, 0),

            SIMD2(0, 0.5 + edgeWobble * ew2),
            SIMD2(0.5 + centerWobbleX * Float(cos(phase)),
                  0.5 + centerWobbleY * Float(sin(phase * 1.3))),
            SIMD2(1, 0.5 - edgeWobble * ew2),

            SIMD2(0, 1),
            SIMD2(0.5 - edgeWobble * ew, 1),
            SIMD2(1, 1)
        ]
    }
}
