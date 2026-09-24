import BrewlyDomain
import SwiftUI

/// Detalle de un post con sus comentarios (respuestas de un nivel).
struct PostDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(SessionStore.self) private var session

    let post: Post

    @State private var comments: [Comment] = []
    @State private var draft = ""
    @State private var replyingTo: Comment?
    @State private var errorMessage: String?

    private var roots: [Comment] { comments.filter { $0.parentID == nil } }

    private func replies(to comment: Comment) -> [Comment] {
        comments.filter { $0.parentID == comment.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PostCardView(post: post, showsCommentLink: false)

                Text("Comentarios").font(.headline)
                if comments.isEmpty {
                    Text("Sé el primero en comentar.").foregroundStyle(.secondary)
                }
                ForEach(roots) { comment in
                    CommentRow(comment: comment, canDelete: canDelete(comment)) {
                        replyingTo = comment
                    } onDelete: {
                        Task { await delete(comment) }
                    }
                    ForEach(replies(to: comment)) { reply in
                        CommentRow(comment: reply, canDelete: canDelete(reply), onReply: {
                            replyingTo = comment
                        }, onDelete: {
                            Task { await delete(reply) }
                        })
                        .padding(.leading, 32)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Publicación")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if post.commentsEnabled { composer }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let replyingTo {
                HStack {
                    Text("Respondiendo a @\(replyingTo.author?.username ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Cancelar") { self.replyingTo = nil }.font(.caption)
                }
            }
            HStack {
                TextField("Añade un comentario…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                Button("Enviar") { Task { await send() } }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .padding()
        .background(.bar)
    }

    private func canDelete(_ comment: Comment) -> Bool {
        comment.authorID == session.currentUserID || post.authorID == session.currentUserID
    }

    private func load() async {
        do {
            comments = try await dependencies.social.comments(postID: post.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let comment = try await dependencies.social.addComment(
                postID: post.id, body: body, parentID: replyingTo?.id
            )
            comments.append(comment)
            draft = ""
            replyingTo = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ comment: Comment) async {
        do {
            try await dependencies.social.deleteComment(id: comment.id)
            comments.removeAll { $0.id == comment.id || $0.parentID == comment.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CommentRow: View {
    @Environment(\.dependencies) private var dependencies
    let comment: Comment
    let canDelete: Bool
    var onReply: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            AvatarView(
                url: comment.author?.avatarPath.flatMap { dependencies.profiles.publicAvatarURL(path: $0) },
                size: 28
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(comment.author?.username ?? "")").font(.caption.bold())
                Text(comment.body)
                HStack {
                    Text(comment.createdAt.formatted(.relative(presentation: .named)))
                    if comment.editedAt != nil { Text("· editado") }
                    Button("Responder", action: onReply)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            if canDelete {
                Button("Eliminar", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }
}
