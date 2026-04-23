import SwiftUI

/// Top-level "Social" tab container. Splits into two sub-surfaces — the
/// friends list with live presence (default), and the live listening-
/// rooms experience.
struct SocialHubView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var rooms = ListeningRoomManager.shared
    @ObservedObject var friendsManager = FriendsManager.shared
    @Namespace private var pickerNamespace
    @State private var segment: Segment = .friends
    @State private var showReactionsInbox = false
    @State private var showMyCode = false
    // Migrated up from FriendsListView / RoomsEntryView so the
    // toolbar items live in *one* parent body. When the segment
    // switches, all add/remove diffs happen inside SocialHubView's
    // `withAnimation` context — toolbar morphs in lockstep with the
    // picker pill instead of using iOS's default unanimated swap.
    @State private var showAddFriend = false
    @State private var showRequests = false
    @State private var showCreateRoom = false

    enum Segment: String, CaseIterable, Hashable {
        case friends, rooms

        var icon: String {
            switch self {
            case .friends: return "person.3.sequence"
            case .rooms: return "point.3.connected.trianglepath.dotted"
            }
        }

        var label: String {
            switch self {
            case .friends: return Loc.friends
            case .rooms: return Loc.rooms
            }
        }
    }

    var body: some View {
        Group {
            switch segment {
            case .friends:
                FriendsListView(
                    showAddFriend: $showAddFriend,
                    showRequests: $showRequests
                )
            case .rooms:
                RoomsEntryView(showCreate: $showCreateRoom)
            }
        }
        // Same spring as the picker pill (response 0.5, damping 0.88)
        // so pill-glide and body cross-fade share one curve — glass
        // pill and content move as a single gesture instead of two
        // animations finishing at different moments.
        .animation(.spring(response: 0.5, dampingFraction: 0.88), value: segment)
        .toolbar {
            // Two leading buttons — qrcode (my friend code) leftmost,
            // sparkles (reactions inbox) just to its right.
            // `ToolbarSpacer(.fixed)` between them is what keeps the
            // pair from merging into one combined glass pill in
            // iOS 26's grouped toolbar — without it the system fuses
            // adjacent same-placement items.
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showMyCode = true
                } label: {
                    Image(systemName: "qrcode")
                }
                .accessibilityLabel(Loc.myFriendCode)
            }
            ToolbarSpacer(.fixed, placement: .topBarLeading)
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showReactionsInbox = true
                } label: {
                    Image(systemName: "sparkles")
                        .symbolEffect(
                            .wiggle,
                            options: .repeat(.periodic(delay: 3.0)),
                            isActive: !friendsManager.unseenReactionIDs.isEmpty
                        )
                        .overlay(alignment: .topTrailing) {
                            let count = friendsManager.unseenReactionIDs.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .padding(.horizontal, 3)
                                    .background(Capsule().fill(Color.red))
                                    .offset(x: 8, y: -8)
                            }
                        }
                }
                .accessibilityLabel(Loc.reactionsInbox)
            }

            // Trailing items vary by segment. Defining them here (in
            // the same parent body as the picker's `withAnimation`)
            // means they morph in/out using the picker's spring, not
            // iOS's default toolbar fade.
            if segment == .friends {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRequests = true
                    } label: {
                        Image(systemName: "tray")
                            .symbolEffect(
                                .wiggle,
                                options: .repeat(.periodic(delay: 2.5)),
                                isActive: friendsManager.incomingRequests.count > 0
                            )
                            .overlay(alignment: .topTrailing) {
                                let count = friendsManager.incomingRequests.count
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .padding(.horizontal, 3)
                                        .background(Capsule().fill(Color.red))
                                        .offset(x: 8, y: -8)
                                }
                            }
                    }
                    .accessibilityLabel(Loc.incomingRequests)
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .symbolEffect(.bounce, value: showAddFriend)
                    }
                    .accessibilityLabel(Loc.addFriend)
                }
            } else if segment == .rooms && rooms.currentRoom == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateRoom = true
                    } label: {
                        Image(systemName: "plus")
                            .symbolEffect(.bounce, value: showCreateRoom)
                    }
                    .accessibilityLabel(Loc.startRoom)
                }
            }
        }
        .sheet(isPresented: $showReactionsInbox) {
            ReactionsInboxSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMyCode) {
            MyCodeSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet()
        }
        .sheet(isPresented: $showRequests) {
            FriendRequestsSheet()
        }
        .sheet(isPresented: $showCreateRoom) {
            CreateRoomSheet()
        }
        .safeAreaInset(edge: .top) {
            // Same placement pattern as `LibraryView.libraryModePicker`:
            // pinned as a top safe-area inset, transparent background so
            // the glass capsule floats over the content.
            if rooms.currentRoom == nil {
                VStack(spacing: 0) {
                    segmentPicker
                        .padding(.horizontal)
                }
                .padding(.vertical, 6)
            }
        }
        .onChange(of: rooms.currentRoom?.id) { _, newID in
            if newID != nil { segment = .rooms }
        }
    }

    // MARK: - Picker (matches LibraryView's glass-capsule style)

    private var segmentPicker: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(Segment.allCases, id: \.self) { seg in
                    let isSelected = segment == seg
                    let count = count(for: seg)
                    Button {
                        // Softer spring (0.5 s response, 0.88 damping)
                        // — pill morph reads as a glide rather than a
                        // snap. Matches the body cross-fade duration.
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                            segment = seg
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: seg.icon)
                                .font(.system(size: 10, weight: .medium))
                            Text(seg.label)
                                .font(.custom(
                                    isSelected ? Loc.fontBold : Loc.fontMedium,
                                    size: 12
                                ))
                                .lineLimit(1)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.custom(Loc.fontBold, size: 10))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule()
                                            .fill(
                                                isSelected
                                                    ? theme.currentTheme.accent
                                                    : Color.secondary.opacity(0.2)
                                            )
                                    )
                            }
                        }
                        .foregroundStyle(
                            isSelected ? theme.currentTheme.accent : .secondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        // Lock the tap area to the full padded rect
                        // *before* the glass modifier so the outer
                        // `.glassEffect(in: .capsule)` clipping can't
                        // shrink hit testing near the pill edges —
                        // especially the right-edge "Rooms" button
                        // whose capsule corner was eating taps.
                        .contentShape(.rect)
                        .glassEffect(
                            isSelected
                                ? .regular.tint(theme.currentTheme.accent.opacity(0.2)).interactive()
                                : .identity,
                            in: .capsule
                        )
                        .glassEffectID(seg.rawValue, in: pickerNamespace)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .glassEffect(in: .capsule)
        }
        .sensoryFeedback(.selection, trigger: segment)
    }

    /// Badge count rendered inside each segment.
    /// - Friends: total friends you've added.
    /// - Rooms: participants in the current live room (zero → hidden).
    private func count(for segment: Segment) -> Int {
        switch segment {
        case .friends:
            return friendsManager.friends.count
        case .rooms:
            return rooms.currentRoom?.participants.count ?? 0
        }
    }
}
