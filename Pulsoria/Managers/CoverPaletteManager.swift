import SwiftUI
import Combine
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Track palette

/// Four colours pulled from the four quadrants of a cover image, in a
/// consistent order so a `MeshGradient` mounted against them reads the
/// same way between track changes. Kept as 0–1 RGB components rather
/// than `Color` so they can be interpolated / brightened cheaply at
/// render time.
struct CoverPalette: Equatable {
    /// Row-major: top-left, top-right, bottom-left, bottom-right.
    var quadrants: [RGB]

    /// Most-saturated quadrant, luminance-normalised, exposed as a
    /// SwiftUI `Color`. Used as a dynamic accent in PlayerView so
    /// controls (progress, shuffle, heart, etc.) match the current
    /// cover when the cover-gradient setting is on.
    var accentColor: Color {
        let ranked = quadrants
            .sorted { saturation(of: $0) > saturation(of: $1) }
        let pick = ranked.first ?? .fallback
        return pick.normalizedForTint.color
    }

    /// Second-most-saturated quadrant — used for two-tone gradients
    /// (lyrics card, artist card) so they don't collapse into a
    /// single-colour wash when the cover-gradient mode is on.
    var secondaryColor: Color {
        let ranked = quadrants
            .sorted { saturation(of: $0) > saturation(of: $1) }
        let pick = ranked.dropFirst().first ?? ranked.first ?? .fallback
        return pick.normalizedForTint.color
    }

    private func saturation(of rgb: RGB) -> Double {
        let maxC = max(rgb.r, rgb.g, rgb.b)
        let minC = min(rgb.r, rgb.g, rgb.b)
        return maxC == 0 ? 0 : (maxC - minC) / maxC
    }

    /// Darker, desaturated version of the four quadrant colours —
    /// used as the outer stops so the gradient has depth rather than
    /// reading as a flat wash.
    var darkened: [RGB] {
        quadrants.map { $0.mixed(with: .black, t: 0.6).saturated(by: 0.85) }
    }

    /// Full complement of control-point colours for a 3×3 MeshGradient.
    /// Puts the quadrant colours at the outer corners, their darkened
    /// versions mid-edge, and the average in the centre — gives a
    /// gradient that keeps the cover's identity but doesn't overpower
    /// the foreground UI.
    var meshColors: [Color] {
        let avg = RGB.average(of: quadrants).mixed(with: .black, t: 0.4)
        return [
            quadrants[0].color,                           dark(quadrants[0], quadrants[1]).color, quadrants[1].color,
            dark(quadrants[0], quadrants[2]).color,       avg.color,                               dark(quadrants[1], quadrants[3]).color,
            quadrants[2].color,                           dark(quadrants[2], quadrants[3]).color, quadrants[3].color
        ]
    }

    private func dark(_ a: RGB, _ b: RGB) -> RGB {
        RGB(
            r: (a.r + b.r) / 2,
            g: (a.g + b.g) / 2,
            b: (a.b + b.b) / 2
        ).mixed(with: .black, t: 0.35)
    }
}

struct RGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    static let black = RGB(r: 0, g: 0, b: 0)
    static let fallback = RGB(r: 0.18, g: 0.10, b: 0.28) // soft indigo

    var color: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    func mixed(with other: RGB, t: Double) -> RGB {
        RGB(
            r: r + (other.r - r) * t,
            g: g + (other.g - g) * t,
            b: b + (other.b - b) * t
        )
    }

    /// Pushes the colour towards / away from grey by `factor` (0 =
    /// fully desaturated, 1 = unchanged, >1 = more saturated, capped
    /// at [0,1] per channel).
    func saturated(by factor: Double) -> RGB {
        let avg = (r + g + b) / 3
        return RGB(
            r: max(0, min(1, avg + (r - avg) * factor)),
            g: max(0, min(1, avg + (g - avg) * factor)),
            b: max(0, min(1, avg + (b - avg) * factor))
        )
    }

    static func average(of values: [RGB]) -> RGB {
        guard !values.isEmpty else { return .black }
        let n = Double(values.count)
        return RGB(
            r: values.map(\.r).reduce(0, +) / n,
            g: values.map(\.g).reduce(0, +) / n,
            b: values.map(\.b).reduce(0, +) / n
        )
    }

    /// Pushes the colour into a usable tint band: near-black colours
    /// get brightened (otherwise invisible on dark UI), near-white
    /// colours get slightly darkened (otherwise they wash out buttons).
    var normalizedForTint: RGB {
        let luma = 0.299 * r + 0.587 * g + 0.114 * b
        if luma < 0.38 {
            let t = min(1, (0.38 - luma) / 0.38)
            return mixed(with: RGB(r: 1, g: 1, b: 1), t: t * 0.55)
        }
        if luma > 0.82 {
            let t = min(1, (luma - 0.82) / 0.18)
            return mixed(with: .black, t: t * 0.4)
        }
        return self
    }
}

// MARK: - Manager

/// Caches cover palettes keyed by `Track.fileName`. Extraction runs on
/// a background task (`CIAreaAverage` over four 32×32 regions), so a
/// PlayerView backed by this manager doesn't block the main thread on
/// first view of a track. Mirrors the `@MainActor class ... ObservableObject`
/// pattern used by `AudioPlayerManager` and friends so SwiftUI picks
/// up changes via `@ObservedObject` as expected.
@MainActor
final class CoverPaletteManager: ObservableObject {
    static let shared = CoverPaletteManager()

    @Published private(set) var cache: [String: CoverPalette] = [:]
    /// Filenames currently being extracted — prevents firing a second
    /// extraction job for the same cover while one is in flight.
    private var inFlight: Set<String> = []

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private init() {}

    /// Returns the cached palette if available, otherwise kicks off a
    /// background extraction and returns nil. Callers should re-read
    /// after `cache` publishes.
    func palette(for fileName: String) -> CoverPalette? {
        cache[fileName]
    }

    /// Fire-and-forget — safe to call repeatedly, dedup'd internally.
    func ensurePalette(for fileName: String, imageData: Data?) {
        guard cache[fileName] == nil, !inFlight.contains(fileName) else { return }
        guard let imageData else { return }
        inFlight.insert(fileName)

        let context = ciContext
        Task.detached(priority: .utility) {
            let palette = await Self.extract(from: imageData, context: context)
            await MainActor.run {
                Self.shared.inFlight.remove(fileName)
                if let palette {
                    Self.shared.cache[fileName] = palette
                }
            }
        }
    }

    // MARK: - Extraction

    /// Decodes the cover, downscales to 128×128, then runs
    /// `CIAreaAverage` on four 64×64 quadrants. Returns nil if the
    /// image is unreadable or CI rendering fails — the caller then
    /// keeps the static theme gradient.
    nonisolated static func extract(from data: Data, context: CIContext) async -> CoverPalette? {
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { return nil }

        let w = 128
        let h = 128
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let downsized = ctx.makeImage() else { return nil }
        let ci = CIImage(cgImage: downsized)

        let half = CGFloat(w / 2)
        let regions: [CGRect] = [
            CGRect(x: 0,    y: half, width: half, height: half), // top-left (CI origin is bottom-left)
            CGRect(x: half, y: half, width: half, height: half), // top-right
            CGRect(x: 0,    y: 0,    width: half, height: half), // bottom-left
            CGRect(x: half, y: 0,    width: half, height: half)  // bottom-right
        ]

        var quadrants: [RGB] = []
        quadrants.reserveCapacity(4)
        for region in regions {
            guard let rgb = averageColor(in: ci, region: region, context: context) else {
                return nil
            }
            // Floor saturation so near-monochrome covers still have
            // some chroma to work with; CIAreaAverage on a purely
            // grayscale album yields r≈g≈b which would flatten to a
            // grey background.
            let saturated = rgb.saturated(by: 1.25)
            let punchy = ensureMinimumLuminance(saturated, floor: 0.08, ceiling: 0.75)
            quadrants.append(punchy)
        }

        return CoverPalette(quadrants: quadrants)
    }

    private nonisolated static func averageColor(in image: CIImage, region: CGRect, context: CIContext) -> RGB? {
        let filter = CIFilter.areaAverage()
        filter.inputImage = image.cropped(to: region)
        filter.extent = region
        guard let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return RGB(
            r: Double(bitmap[0]) / 255.0,
            g: Double(bitmap[1]) / 255.0,
            b: Double(bitmap[2]) / 255.0
        )
    }

    /// Keeps colours inside a usable brightness band — very dark
    /// covers (pure black rock albums) get nudged up so the gradient
    /// doesn't disappear into the system background; near-white
    /// covers get nudged down so text stays legible against it.
    private nonisolated static func ensureMinimumLuminance(_ rgb: RGB, floor: Double, ceiling: Double) -> RGB {
        let luma = 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b
        if luma < floor {
            let t = (floor - luma) / max(floor, 0.001)
            return rgb.mixed(with: RGB(r: 0.35, g: 0.35, b: 0.50), t: min(1, t * 0.6))
        }
        if luma > ceiling {
            let t = (luma - ceiling) / max(1 - ceiling, 0.001)
            return rgb.mixed(with: .black, t: min(1, t * 0.4))
        }
        return rgb
    }
}
