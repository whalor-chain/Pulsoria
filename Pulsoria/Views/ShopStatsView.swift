import SwiftUI

struct ShopStatsView: View {
    @ObservedObject var store = BeatStoreManager.shared
    @ObservedObject var theme = ThemeManager.shared

    var body: some View {
        List {
            // Purchases (all roles)
            Section(Loc.totalPurchases) {
                statRow(icon: "bag.fill", iconColor: theme.currentTheme.accent,
                        title: Loc.totalPurchases, value: "\(store.totalPurchasesCount)")

                statRow(icon: "creditcard.fill", iconColor: .orange,
                        title: Loc.totalSpent, value: String(format: "$%.2f", store.totalSpentAmount))
            }

            // Sales (beatmaker only)
            if store.userRole.canViewSales {
                Section(Loc.totalSales) {
                    statRow(icon: "chart.line.uptrend.xyaxis", iconColor: .green,
                            title: Loc.totalSales, value: "\(store.totalSalesCount)")

                    statRow(icon: "dollarsign.circle.fill", iconColor: .green,
                            title: Loc.totalEarned, value: String(format: "$%.2f", store.totalEarnedAmount))

                    statRow(icon: "arrow.up.circle.fill", iconColor: theme.currentTheme.accent,
                            title: Loc.beatsUploaded, value: "\(store.uploadedBeatsCount)")
                }
            }

            // Recent purchases
            if !store.purchasedBeats.isEmpty {
                Section(Loc.purchaseHistory) {
                    ForEach(store.purchasedBeats.prefix(5)) { beat in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [theme.currentTheme.accent.opacity(0.4), theme.currentTheme.secondary.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Image(systemName: beat.coverImageName)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.8))
                                }

                            Text(beat.title)
                                .font(.custom(Loc.fontMedium, size: 14))
                                .lineLimit(1)

                            Spacer()

                            Text(beat.formattedPrice)
                                .font(.custom(Loc.fontMedium, size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .navigationTitle(Loc.statistics)
    }

    private func statRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        Label {
            HStack {
                Text(title)
                    .font(.custom(Loc.fontMedium, size: 15))
                Spacer()
                Text(value)
                    .font(.custom(Loc.fontBold, size: 15))
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
        }
    }
}
