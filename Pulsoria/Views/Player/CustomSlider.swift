import SwiftUI

// MARK: - Custom Slider with Icon Thumb

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let sliderIcon: SliderIcon
    let accentColor: Color
    var onDragStarted: (() -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil
    @State private var isDragging = false

    private var progress: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (value - range.lowerBound) / span
    }

    var body: some View {
        GeometryReader { geo in
            let trackHeight: CGFloat = 6
            let thumbSize: CGFloat = sliderIcon == .defaultCircle ? 20 : 32
            let usableWidth = geo.size.width - thumbSize
            let thumbX = thumbSize / 2 + usableWidth * progress

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(accentColor.opacity(0.2))
                    .frame(height: trackHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, thumbSize / 2 - trackHeight / 2)

                // Filled track
                Capsule()
                    .fill(accentColor)
                    .frame(width: max(0, thumbX), height: trackHeight)
                    .padding(.leading, 0)

                // Thumb icon
                Group {
                    if sliderIcon == .defaultCircle {
                        Circle()
                            .fill(accentColor)
                            .frame(width: thumbSize, height: thumbSize)
                            .shadow(color: accentColor.opacity(0.4), radius: 4, y: 2)
                    } else {
                        Image(systemName: ThemeManager.shared.activeSliderSymbol)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(accentColor)
                            .frame(width: thumbSize, height: thumbSize)
                            .scaleEffect(isDragging ? 1.25 : 1.0)
                            .animation(.spring(response: 0.3), value: isDragging)
                    }
                }
                .position(x: thumbX, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onDragStarted?()
                        }
                        let fraction = (gesture.location.x - thumbSize / 2) / usableWidth
                        let clamped = min(max(fraction, 0), 1)
                        let span = range.upperBound - range.lowerBound
                        value = range.lowerBound + span * clamped
                    }
                    .onEnded { _ in
                        isDragging = false
                        onDragEnded?()
                    }
            )
        }
    }
}

