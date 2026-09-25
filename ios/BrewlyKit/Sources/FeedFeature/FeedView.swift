import BrewlyDesignSystem
import SwiftUI

/// Home feed. Posts, likes and comments arrive in the next phase; the database
/// schema (posts, post_likes, comments, follows) is already in place.
public struct FeedView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label {
                    Text("Your feed is coming soon", bundle: .module)
                } icon: {
                    Image(systemName: "text.bubble")
                }
            } description: {
                Text("Soon you'll see posts, recipes and tips from the people you follow.", bundle: .module)
            }
            .navigationTitle(Text("Home", bundle: .module))
        }
    }
}
