import BrewlyDomain
import Observation

/// Loads a list page by page with an opaque cursor.
@MainActor
@Observable
public final class Paginator<Item: Sendable> {
    public private(set) var state: LoadState<[Item]> = .idle
    public private(set) var isLoadingMore = false
    private var nextCursor: String?
    private let fetch: @MainActor (String?) async throws -> PagedResult<Item>

    public init(fetch: @escaping @MainActor (String?) async throws -> PagedResult<Item>) {
        self.fetch = fetch
    }

    public var canLoadMore: Bool { nextCursor != nil }

    /// Loads the first page, keeping the current items visible while refreshing.
    public func load() async {
        if state.value == nil { state = .loading }
        do {
            let page = try await fetch(nil)
            nextCursor = page.nextCursor
            state = .loaded(page.items)
        } catch {
            if state.value == nil {
                state = .failed(error as? DomainError ?? .unexpected(String(describing: error)))
            }
        }
    }

    public func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore, let current = state.value else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await fetch(cursor)
            nextCursor = page.nextCursor
            state = .loaded(current + page.items)
        } catch {
            // Keep the loaded items; the user can pull to refresh.
            nextCursor = nil
        }
    }

    /// Changes the loaded items in place, e.g. after an optimistic update.
    public func update(_ transform: (inout [Item]) -> Void) {
        guard var items = state.value else { return }
        transform(&items)
        state = .loaded(items)
    }
}
