import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI
import UIKit

/// A post with its comments and a field to add one.
public struct PostDetailView: View {
    @State private var model: PostDetailViewModel
    @State private var isConfirmingDelete = false
    @FocusState private var isComposerFocused: Bool
    @Environment(\.dismiss) private var dismiss

    public init(postID: UUID, dependencies: FeedDependencies) {
        _model = State(initialValue: PostDetailViewModel(postID: postID, dependencies: dependencies))
    }

    public var body: some View {
        AsyncContentView(model.state, retry: model.load) { post in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    PostCard(post: post, catalog: model.catalog) {
                        Task { await model.toggleLike() }
                    }
                    FieldErrorText(model.errorMessage)
                    comments
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .refreshable { await model.load() }
            .safeAreaInset(edge: .bottom) { composer }
        }
        .navigationTitle(Text("Post", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.isAuthor {
                Menu {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label {
                            Text("Delete post", bundle: .module)
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            Text("Delete this post?", bundle: .module),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task {
                    if await model.deletePost() { dismiss() }
                }
            } label: {
                Text("Delete post", bundle: .module)
            }
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private var comments: some View {
        Text("Comments", bundle: .module).font(.headline).padding(.top, Spacing.s)
        switch model.comments.state {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .failed:
            Text("Couldn't load the comments.", bundle: .module).foregroundStyle(.secondary)
        case let .loaded(list) where list.isEmpty:
            Text("No comments yet. Start the conversation.", bundle: .module).foregroundStyle(.secondary)
        case .loaded:
            ForEach(model.threadedComments) { comment in
                CommentRow(comment: comment) {
                    model.reply(to: comment)
                    isComposerFocused = true
                } onDelete: {
                    Task { await model.delete(comment) }
                }
                .padding(.leading, comment.parentID == nil ? 0 : Spacing.xl)
            }
            if model.comments.canLoadMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .task { await model.comments.loadMore() }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let replyingTo = model.replyingTo {
                HStack {
                    Text("Replying to @\(replyingTo.author.username)", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        model.reply(to: nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(Text("Cancel reply", bundle: .module))
                }
            }
            HStack(alignment: .bottom, spacing: Spacing.s) {
                TextField(String(localized: "Add a comment", bundle: .module), text: $model.newComment, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($isComposerFocused)
                Button {
                    Task { await model.send() }
                } label: {
                    if model.isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                }
                .disabled(!model.canSend)
                .accessibilityLabel(Text("Send", bundle: .module))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.s)
        .background(.bar)
    }
}

private struct CommentRow: View {
    let comment: PostComment
    let onReply: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            NavigationLink(value: AppRoute.member(comment.author.id)) {
                AvatarView(name: comment.author.displayName, url: comment.author.avatarURL, size: 32)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(comment.author.displayName).font(.subheadline.bold())
                    Text(comment.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(comment.body)
                HStack(spacing: Spacing.l) {
                    Button(action: onReply) {
                        Text("Reply", bundle: .module)
                    }
                    if comment.canDelete {
                        Button(role: .destructive, action: onDelete) {
                            Text("Delete", bundle: .module)
                        }
                    }
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }
}
