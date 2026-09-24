import BrewlyDomain
import PhotosUI
import SwiftUI
import UIKit

struct EditProfileView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Profile
    @State private var photo: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onSave: (Profile) -> Void

    init(profile: Profile, onSave: @escaping (Profile) -> Void) {
        _draft = State(initialValue: profile)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("Cambiar foto de perfil", systemImage: "camera")
                    }
                }
                Section("Perfil") {
                    TextField("Usuario", text: $draft.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Nombre", text: $draft.displayName.orEmpty)
                    TextField("Biografía", text: $draft.bio.orEmpty, axis: .vertical)
                        .lineLimit(2...5)
                    Picker("Rol", selection: $draft.role) {
                        ForEach(UserRole.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    TextField("Ubicación", text: $draft.location.orEmpty)
                    TextField("Sitio web", text: $draft.website.orEmpty)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Toggle("Cuenta privada", isOn: $draft.isPrivate)
                } footer: {
                    Text("Con la cuenta privada, solo tus seguidores aprobados ven tus publicaciones. Tus granos, recetas y bitácora privados nunca se comparten.")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            if let photo, let data = try await photo.loadTransferable(type: Data.self),
               let jpeg = ImageCompressor.jpeg(from: data, maxDimension: 512) {
                draft.avatarPath = try await dependencies.profiles.uploadAvatar(jpeg)
            }
            var updated = try await dependencies.profiles.updateMyProfile(ProfileUpdate(from: draft))
            updated.avatarPath = draft.avatarPath ?? updated.avatarPath
            onSave(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Binding where Value == String? {
    /// Permite enlazar un `String?` a un `TextField` (vacío → nil).
    var orEmpty: Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

enum ImageCompressor {
    /// Redimensiona y comprime a JPEG para ahorrar datos y almacenamiento.
    static func jpeg(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
