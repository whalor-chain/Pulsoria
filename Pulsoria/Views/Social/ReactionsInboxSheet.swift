import SwiftUI

/// Modal showing reactions friends have sent to my recent listening.
/// Sorted newest-first. Marks all as seen on appear so the bell
/// badge in `SocialHubView` zeroes out.
struct ReactionsInboxSheet: View {
    @ObservedObject var manager = FriendsManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if manager.recentReactions.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(manager.recentReactions) { reaction in
                            ReactionRow(reaction: reaction)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(Loc.reactionsInbox)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .onAppear {
                manager.markReactionsSeen()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.secondary)
            Text(Loc.noReactionsYet)
                .font(.custom(Loc.fontBold, size: 22))
            Text(Loc.noReactionsHint)
                .font(.custom(Loc.fontMedium, size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct ReactionRow: View {
    let reaction: MusicReaction

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatarView(
                displayName: reaction.fromName,
                avatarURL: reaction.fromAvatarURL,
                size: 40,
                isLive: false
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(reaction.fromName)
                        .font(.custom(Loc.fontBold, size: 14))
                    Text(Loc.reactedTo)
                        .font(.custom(Loc.fontMedium, size: 13))
                        .foregroundStyle(.secondary)
                }

                Text("\(reaction.trackTitle) — \(reaction.trackArtist)")
                    .font(.custom(Loc.fontMedium, size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let when = reaction.createdAt {
                    Text(relativeTime(from: when))
                        .font(.custom(Loc.fontMedium, size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            Text(reaction.emoji)
                .font(.system(size: 30))
        }
        .padding(.vertical, 4)
    }

    private func relativeTime(from date: Date) -> String {
        let ru = ThemeManager.shared.language == .russian
        let bucket = FriendPresence.relativeBucket(for: date, now: Date())
        switch bucket {
        case .none: return ""
        case .justNow: return ru ? "только что" : "just now"
        case .minutes(let m): return ru ? "\(m) мин назад" : "\(m) min ago"
        case .hours(let h): return ru ? "\(h) ч назад" : "\(h) hr ago"
        case .days(let d): return ru ? "\(d) дн назад" : "\(d)d ago"
        }
    }
}
