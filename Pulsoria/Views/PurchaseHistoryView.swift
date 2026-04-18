import SwiftUI

struct PurchaseHistoryView: View {
    @ObservedObject var store = BeatStoreManager.shared
    @ObservedObject var theme = ThemeManager.shared

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }

    var body: some View {
        Group {
            if store.purchasedBeats.isEmpty {
                emptyState
            } else {
                beatList
            }
        }
        .navigationTitle(Loc.purchaseHistory)
    }

    // MARK: - Beat List

    private var beatList: some View {
        List {
            ForEach(store.purchasedBeats) { beat in
                NavigationLink(value: beat) {
                    purchaseRow(beat)
                }
            }

            // Total
            Section {
                HStack {
                    Text(Loc.totalSpent)
                        .font(.custom(Loc.fontBold, size: 15))
                    Spacer()
                    Text(String(format: "$%.2f", store.totalSpentAmount))
                        .font(.custom(Loc.fontBold, size: 15))
                        .foregroundStyle(theme.currentTheme.accent)
                }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 80, for: .scrollContent)
        .navigationDestination(for: Beat.self) { beat in
            BeatDetailView(beat: beat)
        }
    }

    private func purchaseRow(_ beat: Beat) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [theme.currentTheme.accent.opacity(0.4), theme.currentTheme.secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: beat.coverImageName)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.8))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(beat.title)
                    .font(.custom(Loc.fontMedium, size: 15))
                    .lineLimit(1)
                Text(beat.beatmakerName)
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(beat.formattedPrice)
                    .font(.custom(Loc.fontBold, size: 14))
                    .foregroundStyle(theme.currentTheme.accent)
                Text(dateFormatter.string(from: beat.dateAdded))
                    .font(.custom(Loc.fontMedium, size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bag")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.secondary)
            Text(Loc.noPurchases)
                .font(.custom(Loc.fontBold, size: 22))
            Text(Loc.noPurchasesHint)
                .font(.custom(Loc.fontMedium, size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
