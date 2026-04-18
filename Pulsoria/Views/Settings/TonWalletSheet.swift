import SwiftUI

struct TonWalletSheet: View {
    @ObservedObject var tonWallet = TonWalletManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDisconnectAlert = false

    var body: some View {
        NavigationStack {
            List {
                if tonWallet.isConnected {
                    connectedSection
                } else if tonWallet.isConnecting {
                    connectingSection
                } else {
                    connectSection
                }
                infoSection
            }
            .navigationTitle("TON Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.currentTheme.accent)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert(Loc.disconnect, isPresented: $showDisconnectAlert) {
                Button(Loc.cancel, role: .cancel) { }
                Button(Loc.disconnect, role: .destructive) {
                    tonWallet.disconnectWallet()
                }
            } message: {
                Text(Loc.disconnectWalletMsg)
            }
        }
    }

    // MARK: - Connected

    private var connectedSection: some View {
        Section {
            HStack(spacing: 12) {
                Image("TonkeeperIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(Loc.connected)
                        .font(.custom(Loc.fontBold, size: 16))
                        .foregroundStyle(.green)

                    Text(abbreviatedAddress(tonWallet.walletAddress))
                        .font(.custom("Menlo", size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = tonWallet.walletAddress
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(theme.currentTheme.accent)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text(Loc.balance)
                    .font(.custom(Loc.fontMedium, size: 15))
                Spacer()
                if tonWallet.isLoadingBalance {
                    ProgressView()
                } else {
                    Text(tonWallet.formattedBalance)
                        .font(.custom(Loc.fontBold, size: 15))
                        .foregroundStyle(.cyan)
                }
            }

            Button {
                Task { await tonWallet.fetchBalance() }
            } label: {
                Label(Loc.refreshBalance, systemImage: "arrow.clockwise")
                    .font(.custom(Loc.fontMedium, size: 15))
            }

            Button(role: .destructive) {
                showDisconnectAlert = true
            } label: {
                Label(Loc.disconnect, systemImage: "xmark.circle")
                    .font(.custom(Loc.fontMedium, size: 15))
            }
        }
    }

    // MARK: - Connecting (waiting for wallet)

    private var connectingSection: some View {
        Section {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.cyan)

                Text(Loc.waitingForWallet)
                    .font(.custom(Loc.fontMedium, size: 16))
                    .multilineTextAlignment(.center)

                if let error = tonWallet.connectionError {
                    Text(error)
                        .font(.custom(Loc.fontMedium, size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    tonWallet.disconnectWallet()
                } label: {
                    Text(Loc.cancel)
                        .font(.custom(Loc.fontMedium, size: 15))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Connect (one-tap)

    @ViewBuilder
    private var connectSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.cyan)

                Text(Loc.connectTonWallet)
                    .font(.custom(Loc.fontBold, size: 18))

                Text(Loc.connectTonHint)
                    .font(.custom(Loc.fontMedium, size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)

        }

        Section {
            // TON Connect via Tonkeeper
            Button {
                tonWallet.connectViaTonConnect()
            } label: {
                HStack(spacing: 12) {
                    Image("TonkeeperIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Loc.connectViaTonkeeper)
                            .font(.custom(Loc.fontBold, size: 16))
                            .foregroundStyle(.primary)
                        Text(Loc.oneTapConnect)
                            .font(.custom(Loc.fontMedium, size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.cyan)
                }
            }

            // TON Connect via Telegram @wallet
            Button {
                tonWallet.connectViaTelegram()
            } label: {
                HStack(spacing: 12) {
                    Image("TelegramWalletIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Loc.connectViaTelegram)
                            .font(.custom(Loc.fontBold, size: 16))
                            .foregroundStyle(.primary)
                        Text("TON Connect")
                            .font(.custom(Loc.fontMedium, size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            Label {
                Text(Loc.tonWalletInfo)
                    .font(.custom(Loc.fontMedium, size: 13))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func abbreviatedAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))...\(address.suffix(6))"
    }
}
