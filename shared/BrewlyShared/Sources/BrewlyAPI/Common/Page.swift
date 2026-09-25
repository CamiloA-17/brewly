/// A page of results from a cursor-paginated endpoint.
public struct Page<Item: Codable & Sendable>: Codable, Sendable {
    public var items: [Item]
    /// Opaque cursor for the next page; `nil` on the last page.
    public var nextCursor: String?

    public init(items: [Item], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

extension Page: Equatable where Item: Equatable {}
