import SwiftUI

struct PlaylistRowView: View {
    let name: String
    let trackCount: Int
    let iconName: String
    let iconColor: Color
    @ObservedObject var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.currentTheme.accent.opacity(0.4),
                            theme.currentTheme.secondary.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: iconName)
                        .font(.body)
                        .foregroundStyle(iconColor)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.custom(Loc.fontMedium, size: 17))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(trackCount) \(Loc.trackCount)")
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 0)
    }
}

