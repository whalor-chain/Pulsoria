import SwiftUI

/// Centralized view for incoming + outgoing friend requests. Pulled out
/// of the main friends list so the list itself stays focused on actual
/// friends, and the requests get their own navigation-title button.
struct FriendRequestsSheet: View {
    @ObservedObject var manager = FriendsManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !manager.incomingRequests.isEmpty {
                        section(title: Loc.incomingRequests) {
                            ForEach(manager.incomingRequests) { request in
                                IncomingRequestRow(request: request)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .scale(scale: 0.9).combined(with: .opacity)
                                    ))
                            }
                        }
                    }

                    if !manager.outgoingRequests.isEmpty {
                        section(title: Loc.pendingOutgoing) {
                            ForEach(manager.outgoingRequests) { request in
                                OutgoingRequestRow(request: request)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .scale(scale: 0.9).combined(with: .opacity)
                                    ))
                            }
                        }
                    }

                    if manager.incomingRequests.isEmpty && manager.outgoingRequests.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .animation(.spring(response: 0.45, dampingFraction: 0.78),
                           value: manager.incomingRequests.map(\.id) + manager.outgoingRequests.map(\.id))
            }
            .navigationTitle(Loc.incomingRequests)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.cancel) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom(Loc.fontMedium, size: 12))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
            VStack(spacing: 10) {
                content()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(Loc.noFriendsYet)
                .font(.custom(Loc.fontBold, size: 17))
        }
        .frame(maxWidth: .infinity)
    }
}
