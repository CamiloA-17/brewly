import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// The followers of a member, or the people a member follows.
public struct FollowListView: View {
    public enum Kind: Sendable {
        case followers
        case following
    }

    private let kind: Kind
    @State private var paginator: Paginator<UserSummary>

    public init(memberID: UUID, kind: Kind, dependencies: PeopleDependencies) {
        self.kind = kind
        let people = dependencies.people
        _paginator = State(initialValue: Paginator { cursor in
            switch kind {
            case .followers: return try await people.followers(of: memberID, cursor: cursor)
            case .following: return try await people.following(of: memberID, cursor: cursor)
            }
        })
    }

    public var body: some View {
        AsyncContentView(paginator.state, retry: paginator.load) { members in
            if members.isEmpty {
                ContentUnavailableView {
                    Label {
                        switch kind {
                        case .followers: Text("No followers yet", bundle: .module)
                        case .following: Text("Not following anyone yet", bundle: .module)
                        }
                    } icon: {
                        Image(systemName: "person.2")
                    }
                }
            } else {
                List {
                    ForEach(members) { member in
                        NavigationLink(value: AppRoute.member(member.id)) {
                            MemberRow(member: member)
                        }
                    }
                    if paginator.canLoadMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .task { await paginator.loadMore() }
                    }
                }
                .refreshable { await paginator.load() }
            }
        }
        .navigationTitle(kind == .followers ? Text("Followers", bundle: .module) : Text("Following", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .task { await paginator.load() }
    }
}
