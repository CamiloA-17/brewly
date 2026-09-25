import BrewlyDesignSystem
import BrewlyDomain
import PhotosUI
import SwiftUI
import UIKit

/// Writes a post: text, up to four photos, and optionally one of your recipes or beans.
struct ComposePostView: View {
    @State private var model: ComposePostViewModel
    @State private var pickedItems: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss
    private let onPublished: @MainActor (Post) -> Void

    init(dependencies: FeedDependencies, onPublished: @escaping @MainActor (Post) -> Void) {
        _model = State(initialValue: ComposePostViewModel(dependencies: dependencies))
        self.onPublished = onPublished
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "What are you brewing?", bundle: .module), text: $model.draft.body, axis: .vertical)
                        .lineLimit(3...10)
                    FieldErrorText(model.violations.message(for: "body"))
                }

                Section {
                    if !model.draft.photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.s) {
                                ForEach(Array(model.draft.photos.enumerated()), id: \.offset) { index, data in
                                    thumbnail(data, index: index)
                                }
                            }
                        }
                    }
                    PhotosPicker(
                        selection: $pickedItems,
                        maxSelectionCount: PostRules.maxPhotos,
                        matching: .images
                    ) {
                        Label {
                            Text("Choose photos", bundle: .module)
                        } icon: {
                            Image(systemName: "photo.on.rectangle")
                        }
                    }
                    FieldErrorText(model.violations.message(for: "mediaIds") ?? model.violations.message(for: "photos"))
                } header: {
                    Text("Photos", bundle: .module)
                } footer: {
                    Text("Up to \(PostRules.maxPhotos) photos.", bundle: .module)
                }

                Section {
                    Picker(selection: Binding(get: { model.attachment }, set: { model.select($0) })) {
                        Text("Nothing", bundle: .module).tag(ComposePostViewModel.Attachment.none)
                        Text("A recipe", bundle: .module).tag(ComposePostViewModel.Attachment.recipe)
                        Text("A bean", bundle: .module).tag(ComposePostViewModel.Attachment.bean)
                    } label: {
                        Text("Share", bundle: .module)
                    }
                    switch model.attachment {
                    case .none:
                        EmptyView()
                    case .recipe:
                        Picker(selection: $model.draft.recipeID) {
                            ForEach(model.myRecipes) { recipe in
                                Text(recipe.title).tag(Optional(recipe.id))
                            }
                        } label: {
                            Text("Recipe", bundle: .module)
                        }
                        FieldErrorText(model.violations.message(for: "recipeId"))
                    case .bean:
                        Picker(selection: $model.draft.beanID) {
                            ForEach(model.myBeans) { bean in
                                Text(bean.name).tag(Optional(bean.id))
                            }
                        } label: {
                            Text("Bean", bundle: .module)
                        }
                        FieldErrorText(model.violations.message(for: "beanId"))
                    }
                }

                Section {
                    Picker(selection: $model.draft.visibility) {
                        ForEach(Visibility.allCases, id: \.self) { visibility in
                            Text(visibility.localizedName).tag(visibility)
                        }
                    } label: {
                        Text("Who can see it", bundle: .module)
                    }
                    FieldErrorText(model.errorMessage)
                }
            }
            .navigationTitle(Text("New post", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isPublishing {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                if let post = await model.publish() {
                                    onPublished(post)
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Publish", bundle: .module)
                        }
                        .disabled(!model.canPublish)
                    }
                }
            }
            .task { await model.load() }
            .onChange(of: pickedItems) {
                Task { await loadPickedPhotos() }
            }
        }
    }

    private func thumbnail(_ data: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Color.brewlyCrema
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Button {
                pickedItems.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel(Text("Remove photo", bundle: .module))
        }
    }

    /// Reads the picked photos in order; the data layer resizes them before uploading.
    private func loadPickedPhotos() async {
        var photos: [Data] = []
        for item in pickedItems {
            if let data = try? await item.loadTransferable(type: Data.self) {
                photos.append(data)
            }
        }
        model.setPhotos(photos)
    }
}
