import BrewlyDesignSystem
import BrewlyDomain
import Observation
import PhotosUI
import SwiftUI

public struct ProfileDependencies: Sendable {
    public var profile: any ProfileRepository
    public var auth: any AuthRepository
    public var people: any PeopleRepository
    public var equipment: any EquipmentRepository
    public var catalog: any CatalogRepository

    public init(
        profile: any ProfileRepository,
        auth: any AuthRepository,
        people: any PeopleRepository,
        equipment: any EquipmentRepository,
        catalog: any CatalogRepository
    ) {
        self.profile = profile
        self.auth = auth
        self.people = people
        self.equipment = equipment
        self.catalog = catalog
    }
}

@MainActor
@Observable
final class ProfileViewModel {
    private(set) var state: LoadState<UserProfile> = .idle
    /// Follower counts, as other members see them.
    private(set) var publicProfile: MemberProfile?
    private(set) var errorMessage: String?
    private(set) var isUpdatingPhoto = false
    private(set) var violations: [RuleViolation] = []
    var displayName = ""
    var firstName = ""
    var lastName = ""
    var birthDate: CalendarDate?
    var bio = ""
    var countryCode: String?
    var city = ""

    let dependencies: ProfileDependencies

    init(user: UserProfile, dependencies: ProfileDependencies) {
        self.dependencies = dependencies
        state = .loaded(user)
    }

    func load() async {
        do {
            let user = try await dependencies.profile.currentUser()
            state = .loaded(user)
            publicProfile = try? await dependencies.people.profile(id: user.id)
        } catch {
            if state.value == nil {
                state = .failed(error as? DomainError ?? .unexpected(String(describing: error)))
            }
        }
    }

    func beginEditing() {
        guard let user = state.value else { return }
        displayName = user.displayName
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        birthDate = user.birthDate
        bio = user.bio ?? ""
        countryCode = user.countryCode
        city = user.city ?? ""
        violations = []
    }

    /// Returns `true` when the profile was saved.
    func saveProfile() async -> Bool {
        violations = AccountRules.validateProfile(
            displayName: displayName, firstName: firstName, lastName: lastName, birthDate: birthDate,
            bio: bio, countryCode: countryCode, city: city
        )
        guard violations.isEmpty else { return false }
        do {
            let user = try await dependencies.profile.updateProfile(ProfileChanges(
                displayName: displayName.trimmingWhitespace,
                firstName: firstName.trimmingWhitespace,
                lastName: lastName.trimmingWhitespace,
                birthDate: birthDate,
                bio: bio.trimmingWhitespace.isEmpty ? nil : bio.trimmingWhitespace,
                countryCode: countryCode,
                city: city.trimmingWhitespace.isEmpty ? nil : city.trimmingWhitespace
            ))
            state = .loaded(user)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.brewlyMessage
            return false
        }
    }

    /// Uploads a new profile picture (resized by the data layer).
    func updateAvatar(imageData: Data) async {
        await changingPhoto { try await self.dependencies.profile.updateAvatar(imageData: imageData) }
    }

    func removeAvatar() async {
        await changingPhoto { try await self.dependencies.profile.removeAvatar() }
    }

    private func changingPhoto(_ change: () async throws -> UserProfile) async {
        isUpdatingPhoto = true
        defer { isUpdatingPhoto = false }
        do {
            state = .loaded(try await change())
            errorMessage = nil
        } catch {
            errorMessage = error.brewlyMessage
        }
    }

    func signOut() async {
        await dependencies.auth.signOut()
    }

    /// Returns `true` when the account was deleted.
    func deleteAccount() async -> Bool {
        do {
            try await dependencies.profile.deleteAccount()
            return true
        } catch {
            errorMessage = error.brewlyMessage
            return false
        }
    }
}

public struct ProfileView: View {
    @State private var model: ProfileViewModel
    @State private var isEditing = false
    @State private var isConfirmingDeletion = false
    @State private var pickedPhoto: PhotosPickerItem?
    private let onSignedOut: @MainActor () -> Void

    public init(user: UserProfile, dependencies: ProfileDependencies, onSignedOut: @escaping @MainActor () -> Void) {
        _model = State(initialValue: ProfileViewModel(user: user, dependencies: dependencies))
        self.onSignedOut = onSignedOut
    }

    public var body: some View {
        NavigationStack {
            AsyncContentView(model.state, retry: model.load) { user in
                List {
                    Section {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            AvatarView(name: user.displayName, url: user.avatarURL, size: 72)
                                .overlay {
                                    if model.isUpdatingPhoto { ProgressView() }
                                }
                                .padding(.bottom, Spacing.xs)
                            Text(user.displayName).font(.title2.bold())
                            Text(verbatim: "@\(user.username)").foregroundStyle(.secondary)
                            if let bio = user.bio {
                                Text(bio).padding(.top, Spacing.xs)
                            }
                            if let place = memberPlace(city: user.city, countryCode: user.countryCode) {
                                Label(place, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                        if let counts = model.publicProfile {
                            FollowCountLinks(
                                memberID: user.id,
                                followers: counts.followerCount,
                                following: counts.followingCount,
                                followersTitle: Text("Followers", bundle: .module),
                                followingTitle: Text("Following", bundle: .module)
                            )
                        }
                        Button {
                            model.beginEditing()
                            isEditing = true
                        } label: {
                            Text("Edit profile", bundle: .module)
                        }
                    }

                    Section {
                        NavigationLink {
                            EquipmentListView(
                                equipment: model.dependencies.equipment, catalog: model.dependencies.catalog
                            )
                        } label: {
                            Label {
                                Text("My equipment", bundle: .module)
                            } icon: {
                                Image(systemName: "gearshape.2")
                            }
                        }
                    }

                    Section {
                        AppearancePicker()
                    }

                    Section {
                        if let firstName = user.firstName, let lastName = user.lastName {
                            LabeledContent {
                                Text(verbatim: "\(firstName) \(lastName)")
                            } label: {
                                Text("Name", bundle: .module)
                            }
                        }
                        if let birthDate = user.birthDate {
                            LabeledContent {
                                Text(birthDate.date(in: .current), format: .dateTime.day().month(.wide).year())
                            } label: {
                                Text("Birth date", bundle: .module)
                            }
                        }
                    } header: {
                        Text("Personal details", bundle: .module)
                    } footer: {
                        Text("Only you can see your name and birth date.", bundle: .module)
                    }

                    Section {
                        if let email = user.email {
                            LabeledContent {
                                Text(email)
                            } label: {
                                Text("Email", bundle: .module)
                            }
                        }
                        Button {
                            Task {
                                await model.signOut()
                                onSignedOut()
                            }
                        } label: {
                            Text("Sign out", bundle: .module)
                        }
                        Button(role: .destructive) {
                            isConfirmingDeletion = true
                        } label: {
                            Text("Delete account", bundle: .module)
                        }
                        FieldErrorText(model.errorMessage)
                    } header: {
                        Text("Account", bundle: .module)
                    }
                }
            }
            .navigationTitle(Text("Profile", bundle: .module))
            .appRouteDestinations()
            .sheet(isPresented: $isEditing) {
                editSheet
            }
            .confirmationDialog(
                Text("Delete your account?", bundle: .module),
                isPresented: $isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    Task {
                        if await model.deleteAccount() { onSignedOut() }
                    }
                } label: {
                    Text("Delete account and all my data", bundle: .module)
                }
            } message: {
                Text("Your beans, recipes and posts will be permanently deleted.", bundle: .module)
            }
            .task { await model.load() }
        }
    }

    private var editSheet: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        Label {
                            Text("Choose profile photo", bundle: .module)
                        } icon: {
                            Image(systemName: "person.crop.circle.badge.plus")
                        }
                    }
                    if model.state.value?.avatarURL != nil {
                        Button(role: .destructive) {
                            Task { await model.removeAvatar() }
                        } label: {
                            Text("Remove profile photo", bundle: .module)
                        }
                    }
                    FieldErrorText(model.errorMessage)
                }
                Section {
                    TextField(String(localized: "Display name", bundle: .module), text: $model.displayName)
                    FieldErrorText(model.violations.message(for: "displayName"))
                    TextField(String(localized: "Bio", bundle: .module), text: $model.bio, axis: .vertical)
                        .lineLimit(2...5)
                    FieldErrorText(model.violations.message(for: "bio"))
                    CountryPicker(code: $model.countryCode)
                    FieldErrorText(model.violations.message(for: "countryCode"))
                    TextField(String(localized: "City (optional)", bundle: .module), text: $model.city)
                        .textContentType(.addressCity)
                    FieldErrorText(model.violations.message(for: "city"))
                } header: {
                    Text("Public profile", bundle: .module)
                }
                Section {
                    TextField(String(localized: "First name", bundle: .module), text: $model.firstName)
                        .textContentType(.givenName)
                    FieldErrorText(model.violations.message(for: "firstName"))
                    TextField(String(localized: "Last name", bundle: .module), text: $model.lastName)
                        .textContentType(.familyName)
                    FieldErrorText(model.violations.message(for: "lastName"))
                    BirthDateField(date: $model.birthDate)
                    FieldErrorText(model.violations.message(for: "birthDate"))
                } header: {
                    Text("Personal details", bundle: .module)
                } footer: {
                    Text("Only you can see your name and birth date.", bundle: .module)
                }
            }
            .navigationTitle(Text("Edit profile", bundle: .module))
            .onChange(of: pickedPhoto) {
                guard let item = pickedPhoto else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await model.updateAvatar(imageData: data)
                    }
                    pickedPhoto = nil
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isEditing = false
                    } label: {
                        Text("Cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await model.saveProfile() { isEditing = false }
                        }
                    } label: {
                        Text("Save", bundle: .module)
                    }
                }
            }
        }
    }
}
