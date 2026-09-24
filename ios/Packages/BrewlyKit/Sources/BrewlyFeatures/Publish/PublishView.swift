import BrewlyDomain
import PhotosUI
import SwiftUI

/// Publica una receta, preparación, café o nota en el feed.
struct PublishView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var kind: PostKind
    @State private var contentID: UUID?
    @State private var caption = ""
    @State private var visibility: Visibility = .public
    @State private var commentsEnabled = true
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isPublishing = false
    @State private var errorMessage: String?

    @State private var recipes: [Recipe] = []
    @State private var brews: [Brew] = []
    @State private var beans: [CoffeeBean] = []

    let onPublished: (Post) -> Void

    init(
        initialKind: PostKind = .recipe,
        initialContentID: UUID? = nil,
        onPublished: @escaping (Post) -> Void = { _ in }
    ) {
        _kind = State(initialValue: initialKind)
        _contentID = State(initialValue: initialContentID)
        self.onPublished = onPublished
    }

    private var canPublish: Bool {
        !isPublishing && (kind == .note
            ? !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : contentID != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $kind) {
                        Text("Receta").tag(PostKind.recipe)
                        Text("Preparación").tag(PostKind.brew)
                        Text("Café").tag(PostKind.bean)
                        Text("Nota").tag(PostKind.note)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { contentID = nil }

                    contentPicker
                }

                Section("Descripción") {
                    TextField("Cuenta algo sobre esta taza…", text: $caption, axis: .vertical)
                        .lineLimit(3...8)
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                        Label(photoItems.isEmpty ? "Añadir fotos" : "\(photoItems.count) fotos seleccionadas",
                              systemImage: "photo.on.rectangle")
                    }
                }

                Section {
                    VisibilityPicker(selection: $visibility, allowed: [.followers, .public])
                    Toggle("Permitir comentarios", isOn: $commentsEnabled)
                } header: {
                    Text("Audiencia")
                } footer: {
                    Text("Si el contenido es privado, se compartirá con esta misma audiencia al publicarlo. Tu inventario nunca se comparte.")
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Publicar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isPublishing {
                        ProgressView()
                    } else {
                        Button("Publicar") { Task { await publish() } }.disabled(!canPublish)
                    }
                }
            }
            .task { await loadContent() }
        }
    }

    @ViewBuilder
    private var contentPicker: some View {
        switch kind {
        case .recipe:
            Picker("Receta", selection: $contentID) {
                Text("Elige…").tag(UUID?.none)
                ForEach(recipes) { Text($0.title).tag(UUID?.some($0.id)) }
            }
        case .brew:
            Picker("Preparación", selection: $contentID) {
                Text("Elige…").tag(UUID?.none)
                ForEach(brews) { brew in
                    Text(brew.brewedAt.formatted(date: .abbreviated, time: .shortened)).tag(UUID?.some(brew.id))
                }
            }
        case .bean:
            Picker("Café", selection: $contentID) {
                Text("Elige…").tag(UUID?.none)
                ForEach(beans) { Text($0.name).tag(UUID?.some($0.id)) }
            }
        case .note:
            EmptyView()
        }
    }

    private func loadContent() async {
        async let recipes = dependencies.recipes.myRecipes()
        async let brews = dependencies.brews.myBrews(limit: 30)
        async let beans = dependencies.coffee.beans(includeArchived: false)
        self.recipes = (try? await recipes) ?? []
        self.brews = (try? await brews) ?? []
        self.beans = (try? await beans) ?? []
    }

    private func publish() async {
        isPublishing = true
        defer { isPublishing = false }
        do {
            var images: [Data] = []
            for item in photoItems {
                if let data = try await item.loadTransferable(type: Data.self),
                   let jpeg = ImageCompressor.jpeg(from: data) {
                    images.append(jpeg)
                }
            }
            let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            let post = try await dependencies.social.publish(PublishRequest(
                kind: kind,
                contentID: kind == .note ? nil : contentID,
                caption: trimmed.isEmpty ? nil : trimmed,
                visibility: visibility,
                commentsEnabled: commentsEnabled,
                images: images
            ))
            onPublished(post)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
