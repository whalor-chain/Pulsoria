import SwiftUI

/// Horizontally-scrolling text that auto-ticks left when the string
/// doesn't fit in the container. Mirrors the iTunes / Apple Music
/// pattern — short strings render statically, long ones cycle with a
/// pause at the start of each loop.
///
/// Usage:
///
///     MarqueeText(text: track.title, font: .custom(Loc.fontBold, size: 22))
///
/// Fades the leading & trailing edges so the text doesn't pop in / out
/// sharply at the clip boundary.
struct MarqueeText: View {
    let text: String
    let font: Font
    /// Horizontal alignment when the text fits in the container and
    /// doesn't need to scroll. Defaults to leading to match typical
    /// list-row usage; pass `.center` for headline-style layouts.
    var alignment: Alignment = .leading
    /// Pixels per second the text scrolls at once it gets moving.
    var speed: CGFloat = 30
    /// Pause applied at the start of every loop so the first characters
    /// are readable before the animation begins.
    var pauseSeconds: Double = 2.0
    /// Gap between the two looping copies of the string.
    var gap: CGFloat = 40

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    private var needsScroll: Bool {
        textWidth > containerWidth && containerWidth > 0
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: needsScroll ? .leading : alignment)
            .background(containerProbe)
            .onPreferenceChange(ContainerWidthKey.self) { containerWidth = $0 }
            // The invisible measurer lives as an overlay so it matches
            // the text's natural size without forcing a container.
            .overlay(textMeasurer.hidden())
            .onPreferenceChange(TextWidthKey.self) { textWidth = $0 }
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        if needsScroll {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
                let loopWidth = textWidth + gap
                let scrollTime = Double(loopWidth) / Double(speed)
                let cycle = scrollTime + pauseSeconds
                let t = ctx.date.timeIntervalSinceReferenceDate
                let phase = t.truncatingRemainder(dividingBy: cycle)
                let offset: CGFloat = phase < pauseSeconds
                    ? 0
                    : -CGFloat((phase - pauseSeconds) * Double(speed))

                HStack(spacing: gap) {
                    textView
                    textView
                }
                .offset(x: offset)
            }
            .mask(edgeFade)
        } else {
            textView
        }
    }

    private var textView: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// Invisible copy of the label used just to measure its natural
    /// width. Without `.fixedSize` it would otherwise adopt the
    /// container width and we'd never know if it actually fit.
    private var textMeasurer: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: TextWidthKey.self, value: geo.size.width)
                }
            )
    }

    private var containerProbe: some View {
        GeometryReader { geo in
            Color.clear.preference(key: ContainerWidthKey.self, value: geo.size.width)
        }
    }

    /// Soft gradient mask so the leading/trailing characters fade into
    /// the clip edge rather than being chopped off mid-stroke.
    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.05),
                .init(color: .black, location: 0.95),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
