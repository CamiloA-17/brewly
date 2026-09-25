import BrewlyDesignSystem
import BrewlyDomain
import Observation
import SwiftUI

@MainActor
@Observable
final class MemberSearchViewModel {
    var query = ""
    private(set) var results: [UserSummary] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    private let people: any PeopleRepository

    init(people: any PeopleRepository) {
        self.people = people
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Searches for the current query. Empty queries clear the results without a request.
    func search() async {
        let text = trimmedQuery
        guard !text.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await people.search(text)
            // Ignore late answers for a query the user already changed.
            guard text == trimmedQuery else { return }
            results = found
            errorMessage = nil
        } catch {
            errorMessage = error.brewlyMessage
        }
    }
}

/// Finds other members by username or name.
public struct MemberSearchView: View {
    @State private var model: MemberSearchViewModel

    public init(dependencies: PeopleDependencies) {
        _model = State(initialValue: MemberSearchViewModel(people: dependencies.people))
    }

    public var body: some View {
        List {
            FieldErrorText(model.errorMessage)
            ForEach(model.results) { member in
                NavigationLink(value: AppRoute.member(member.id)) {
                    MemberRow(member: member)
                }
            }
        }
        .overlay {
            if model.trimmedQuery.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("Find people", bundle: .module)
                    } icon: {
                        Image(systemName: "person.crop.circle.badge.magnifyingglass")
                    }
                } description: {
                    Text("Search by username or name.", bundle: .module)
                }
            } else if model.results.isEmpty, !model.isSearching, model.errorMessage == nil {
                ContentUnavailableView.search(text: model.trimmedQuery)
            }
        }
        .searchable(
            text: $model.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Username or name", bundle: .module)
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle(Text("Find people", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.query) {
            // Wait until the user stops typing.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await model.search()
        }
    }
}
