import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// The brew journal tab: every cup the member prepared, grouped by day.
public struct JournalView: View {
    @State private var model: JournalViewModel
    @State private var isLogging = false
    private let dependencies: JournalDependencies

    public init(dependencies: JournalDependencies) {
        _model = State(initialValue: JournalViewModel(dependencies: dependencies))
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack {
            AsyncContentView(model.brews.state, retry: model.load) { brews in
                List {
                    if let beanName = model.filteredBeanName {
                        Section {
                            Button {
                                Task { await model.filter(beanID: nil) }
                            } label: {
                                Label {
                                    Text("Showing \(beanName). Show all", bundle: .module)
                                } icon: {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                }
                            }
                        }
                    }
                    if brews.isEmpty {
                        ContentUnavailableView {
                            Label {
                                Text("No brews yet", bundle: .module)
                            } icon: {
                                Image(systemName: "book.closed")
                            }
                        } description: {
                            Text("Log every cup you prepare to learn what works best for each bean.", bundle: .module)
                        }
                    }
                    ForEach(model.days, id: \.day) { day in
                        Section {
                            ForEach(day.brews) { brew in
                                NavigationLink(value: AppRoute.brew(brew.id)) {
                                    BrewLogRow(brew: brew, catalog: model.catalog)
                                }
                            }
                        } header: {
                            Text(day.day, format: .dateTime.weekday(.wide).day().month(.wide))
                        }
                    }
                    if model.brews.canLoadMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .task { await model.brews.loadMore() }
                    }
                }
                .refreshable { await model.load() }
            }
            .navigationTitle(Text("Journal", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            Task { await model.filter(beanID: nil) }
                        } label: {
                            Text("All beans", bundle: .module)
                        }
                        ForEach(model.beans) { bean in
                            Button(bean.name) {
                                Task { await model.filter(beanID: bean.id) }
                            }
                        }
                    } label: {
                        Label {
                            Text("Filter by bean", bundle: .module)
                        } icon: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                    .disabled(model.beans.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isLogging = true
                    } label: {
                        Label {
                            Text("Log a brew", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isLogging) {
                NavigationStack {
                    BrewLogFormView(brewLog: nil, dependencies: dependencies) { _ in
                        Task { await model.load() }
                    }
                }
            }
            .appRouteDestinations()
            .task { await model.load() }
        }
    }
}
