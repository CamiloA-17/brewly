import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Private journal of actual cups, including cups whose recipe was deleted.
struct BrewHistoryView: View {
    let sessions: any BrewSessionRepository
    @State private var items: [BrewSession] = []
    @State private var nextCursor: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if items.isEmpty && !isLoading {
                Text("Your completed cups will appear here.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { cup in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(cup.recipeTitle).font(.headline)
                        Spacer()
                        Text(cup.createdAt, style: .date).font(.footnote).foregroundStyle(.secondary)
                    }
                    Text(cup.beanName).foregroundStyle(.secondary)
                    Text("\(BrewFormat.grams(cup.doseG)) · \(BrewFormat.duration(cup.elapsedS))")
                    if let rating = cup.rating {
                        Text("Rating: \(rating)/5", bundle: .module)
                    }
                    if let notes = cup.notes { Text(notes).font(.subheadline) }
                }
                .padding(.vertical, Spacing.xs)
            }
            if nextCursor != nil {
                Button { Task { await load(replacing: false) } } label: {
                    Text("Load older cups", bundle: .module)
                }
                .disabled(isLoading)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .navigationTitle(Text("Brew history", bundle: .module))
        .refreshable { await load(replacing: true) }
        .task { await load(replacing: true) }
    }

    private func load(replacing: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await sessions.sessions(recipeID: nil, cursor: replacing ? nil : nextCursor)
            items = replacing ? page.items : items + page.items
            nextCursor = page.nextCursor
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
