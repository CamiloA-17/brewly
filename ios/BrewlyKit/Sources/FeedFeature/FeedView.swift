import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI
import UIKit

/// Home: posts from the people you follow, or from the whole community.
public struct FeedView: View {
    @State private var model: FeedViewModel
    @State private var isComposing = false

    public init(dependencies: FeedDependencies) {
        _model = State(initialValue: FeedViewModel(dependencies: dependencies))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Spacing.m) {
                    Picker(selection: $model.scope) {
                        Text("Following", bundle: .module).tag(FeedViewModel.Scope.following)
                        Text("Explore", bundle: .module).tag(FeedViewModel.Scope.explore)
                    } label: {
                        Text("Feed", bundle: .module)
                    }
                    .pickerStyle(.segmented)
                    FieldErrorText(model.errorMessage)
                    content
                }
                .padding(.horizontal)
                .padding(.bottom, Spacing.l)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .refreshable { await model.load() }
            .navigationTitle(Text("Home", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: AppRoute.memberSearch) {
                        Label {
                            Text("Find people", bundle: .module)
                        } icon: {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isComposing = true
                    } label: {
                        Label {
                            Text("New post", bundle: .module)
                        } icon: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $isComposing) {
                ComposePostView(dependencies: model.dependencies) { post in
                    model.insert(post)
                }
            }
            .appRouteDestinations()
            .task { await model.load() }
            .onChange(of: model.scope) {
                Task { await model.reload() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.paginator.state {
        case .idle, .loading:
            ProgressView().padding(.top, Spacing.xl)
        case let .failed(error):
            ErrorStateView(error: error, retry: model.load)
        case let .loaded(posts) where posts.isEmpty:
            emptyState
        case let .loaded(posts):
            ForEach(posts) { post in
                PostCard(post: post, catalog: model.catalog) {
                    Task { await model.toggleLike(post) }
                }
            }
            if model.paginator.canLoadMore {
                ProgressView()
                    .task { await model.paginator.loadMore() }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch model.scope {
        case .following:
            ContentUnavailableView {
                Label {
                    Text("Your feed is empty", bundle: .module)
                } icon: {
                    Image(systemName: "text.bubble")
                }
            } description: {
                Text("Follow people or share your first post.", bundle: .module)
            } actions: {
                Button {
                    isComposing = true
                } label: {
                    Text("New post", bundle: .module)
                }
                .buttonStyle(.borderedProminent)
            }
        case .explore:
            ContentUnavailableView {
                Label {
                    Text("No posts yet", bundle: .module)
                } icon: {
                    Image(systemName: "globe")
                }
            } description: {
                Text("Public posts from the community will show up here.", bundle: .module)
            }
        }
    }
}
