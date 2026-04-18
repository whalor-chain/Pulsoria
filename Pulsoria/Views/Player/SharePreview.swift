import SwiftUI
import UIKit

// MARK: - Share Preview Sheet

struct SharePreviewSheet: View {
    let track: Track
    let artwork: UIImage?
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false
    @State private var copied = false
    @State private var showActivitySheet = false
    @State private var selectedPalette: SharePalette = .sunset
    @State private var renderedImage: UIImage?

    private var currentImage: UIImage {
        renderedImage ?? ShareCardRenderer.render(track: track, artwork: artwork, palette: selectedPalette)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Preview
                Image(uiImage: currentImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.35), value: selectedPalette)
                    .id(selectedPalette)

                // Palette picker
                HStack(spacing: 12) {
                    ForEach(SharePalette.allCases) { palette in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPalette = palette
                                }
                                renderedImage = ShareCardRenderer.render(track: track, artwork: artwork, palette: palette)
                            } label: {
                                let colors = palette.swiftUIColors
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [colors.0, colors.1],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        if selectedPalette == palette {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 3)
                                        }
                                    }
                            }
                            .sensoryFeedback(.selection, trigger: selectedPalette)
                        }
                    }

                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(currentImage, nil, nil, nil)
                        withAnimation(.spring(duration: 0.3)) { saved = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { saved = false }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: saved ? "checkmark.circle.fill" : "photo.on.rectangle.angled")
                                .font(.system(size: 22))
                                .symbolEffect(.bounce, value: saved)
                            Text(saved ? Loc.done : Loc.save)
                                .font(.custom(Loc.fontMedium, size: 12))
                        }
                        .foregroundStyle(saved ? .green : theme.currentTheme.accent)
                        .frame(width: 80, height: 70)
                    }
                    .buttonStyle(.glass)
                    .sensoryFeedback(.success, trigger: saved)

                    Button {
                        showActivitySheet = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.up.message")
                                .font(.system(size: 22))
                            Text(Loc.share)
                                .font(.custom(Loc.fontMedium, size: 12))
                        }
                        .foregroundStyle(theme.currentTheme.accent)
                        .frame(width: 80, height: 70)
                    }
                    .buttonStyle(.glass)

                    Button {
                        UIPasteboard.general.image = currentImage
                        withAnimation(.spring(duration: 0.3)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 22))
                                .symbolEffect(.bounce, value: copied)
                            Text(copied ? Loc.done : Loc.copy)
                                .font(.custom(Loc.fontMedium, size: 12))
                        }
                        .foregroundStyle(copied ? .green : theme.currentTheme.accent)
                        .frame(width: 80, height: 70)
                    }
                    .buttonStyle(.glass)
                    .sensoryFeedback(.success, trigger: copied)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("ShareLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 52)
                        .foregroundStyle(theme.currentTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.currentTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                ActivitySheet(items: [currentImage])
            }
            .onAppear {
                renderedImage = ShareCardRenderer.render(track: track, artwork: artwork, palette: selectedPalette)
            }
        }
    }
}

// MARK: - Activity Sheet (UIActivityViewController)

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Share Palette

enum SharePalette: String, CaseIterable, Identifiable {
    case sunset
    case ocean
    case forest
    case neon
    case lavender
    case ember
    case arctic

    var id: String { rawValue }

    var colors: (top: UIColor, mid: UIColor, bottom: UIColor) {
        switch self {
        case .sunset:   return (UIColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1), UIColor(red: 0.8, green: 0.5, blue: 0.1, alpha: 1), UIColor(red: 0.15, green: 0.05, blue: 0.1, alpha: 1))
        case .ocean:    return (UIColor(red: 0.0, green: 0.4, blue: 0.7, alpha: 1), UIColor(red: 0.0, green: 0.2, blue: 0.5, alpha: 1), UIColor(red: 0.0, green: 0.05, blue: 0.15, alpha: 1))
        case .forest:   return (UIColor(red: 0.1, green: 0.5, blue: 0.3, alpha: 1), UIColor(red: 0.05, green: 0.3, blue: 0.2, alpha: 1), UIColor(red: 0.02, green: 0.1, blue: 0.08, alpha: 1))
        case .neon:     return (UIColor(red: 0.9, green: 0.0, blue: 0.6, alpha: 1), UIColor(red: 0.3, green: 0.0, blue: 0.8, alpha: 1), UIColor(red: 0.05, green: 0.0, blue: 0.15, alpha: 1))
        case .lavender: return (UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1), UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1), UIColor(red: 0.1, green: 0.05, blue: 0.2, alpha: 1))
        case .ember:    return (UIColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 1), UIColor(red: 0.5, green: 0.1, blue: 0.05, alpha: 1), UIColor(red: 0.1, green: 0.02, blue: 0.02, alpha: 1))
        case .arctic:   return (UIColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 1), UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1), UIColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1))
        }
    }

    var swiftUIColors: (Color, Color) {
        (Color(colors.top), Color(colors.mid))
    }
}

// MARK: - Share Card Renderer

enum ShareCardRenderer {
    static func render(track: Track, artwork: UIImage?, palette: SharePalette) -> UIImage {
        let width: CGFloat = 1080
        let height: CGFloat = 1920
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { ctx in
            let context = ctx.cgContext

            // Background gradient from palette
            let pal = palette.colors
            let colors = [pal.top.cgColor, pal.mid.cgColor, pal.bottom.cgColor]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.5, 1]
            ) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: width, y: height),
                    options: []
                )
            }

            // Artwork with rounded corners and shadow
            let artSize: CGFloat = 640
            let artX = (width - artSize) / 2
            let artY: CGFloat = 360
            let artRect = CGRect(x: artX, y: artY, width: artSize, height: artSize)

            // Shadow
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 20), blur: 60, color: UIColor.black.withAlphaComponent(0.5).cgColor)
            let artPath = UIBezierPath(roundedRect: artRect, cornerRadius: 40)
            UIColor.black.setFill()
            artPath.fill()
            context.restoreGState()

            // Artwork image clipped
            context.saveGState()
            artPath.addClip()
            if let artwork {
                artwork.draw(in: artRect)
            } else {
                // Placeholder gradient
                let placeholderColors = [
                    pal.top.withAlphaComponent(0.6).cgColor,
                    pal.mid.withAlphaComponent(0.4).cgColor
                ]
                if let placeholderGradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: placeholderColors as CFArray,
                    locations: [0, 1]
                ) {
                    context.drawLinearGradient(
                        placeholderGradient,
                        start: artRect.origin,
                        end: CGPoint(x: artRect.maxX, y: artRect.maxY),
                        options: []
                    )
                }

                // Music note
                let noteFont = UIFont.systemFont(ofSize: 160, weight: .ultraLight)
                let noteStr = NSAttributedString(
                    string: "\u{266B}",
                    attributes: [
                        .font: noteFont,
                        .foregroundColor: UIColor.white.withAlphaComponent(0.5)
                    ]
                )
                let noteSize = noteStr.size()
                noteStr.draw(at: CGPoint(
                    x: artRect.midX - noteSize.width / 2,
                    y: artRect.midY - noteSize.height / 2
                ))
            }
            context.restoreGState()

            // "Now Listening" logo
            if let nowLogo = UIImage(named: "NowListeningLogo") {
                let nowHeight: CGFloat = 160
                let nowWidth = nowLogo.size.width / nowLogo.size.height * nowHeight
                let nowRect = CGRect(
                    x: (width - nowWidth) / 2,
                    y: artY - nowHeight - 30,
                    width: nowWidth,
                    height: nowHeight
                )
                context.saveGState()
                context.setAlpha(0.5)
                nowLogo.draw(in: nowRect)
                context.restoreGState()
            }

            // Track title
            let titleFont = UIFont(name: "Futura-Bold", size: 56) ?? UIFont.boldSystemFont(ofSize: 56)
            let titleParagraph = NSMutableParagraphStyle()
            titleParagraph.alignment = .center
            titleParagraph.lineBreakMode = .byTruncatingTail
            let titleStr = NSAttributedString(
                string: track.title,
                attributes: [
                    .font: titleFont,
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: titleParagraph
                ]
            )
            let titleRect = CGRect(x: 60, y: artY + artSize + 60, width: width - 120, height: 80)
            titleStr.draw(in: titleRect)

            // Artist name
            let artistFont = UIFont(name: "Futura-Medium", size: 38) ?? UIFont.systemFont(ofSize: 38, weight: .medium)
            let artistStr = NSAttributedString(
                string: track.artist,
                attributes: [
                    .font: artistFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.7),
                    .paragraphStyle: titleParagraph
                ]
            )
            let artistRect = CGRect(x: 60, y: artY + artSize + 150, width: width - 120, height: 60)
            artistStr.draw(in: artistRect)

            // Decorative line
            let lineY = artY + artSize + 240
            context.setFillColor(UIColor.white.withAlphaComponent(0.15).cgColor)
            context.fill(CGRect(x: width / 2 - 80, y: lineY, width: 160, height: 3))

            // NotLogo below the line
            if let notLogo = UIImage(named: "NotLogo") {
                let notLogoHeight: CGFloat = 80
                let notLogoWidth = notLogo.size.width / notLogo.size.height * notLogoHeight
                let notLogoRect = CGRect(
                    x: (width - notLogoWidth) / 2,
                    y: lineY + 24,
                    width: notLogoWidth,
                    height: notLogoHeight
                )
                context.saveGState()
                context.setAlpha(0.5)
                notLogo.draw(in: notLogoRect)
                context.restoreGState()
            }

            // FullLogo at the bottom
            if let fullLogo = UIImage(named: "FullLogo") {
                let logoHeight: CGFloat = 120
                let logoWidth = fullLogo.size.width / fullLogo.size.height * logoHeight
                let logoRect = CGRect(
                    x: (width - logoWidth) / 2,
                    y: height - 160,
                    width: logoWidth,
                    height: logoHeight
                )
                context.saveGState()
                context.setAlpha(0.4)
                fullLogo.draw(in: logoRect)
                context.restoreGState()
            }
        }
    }
}
