import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Asks for the private details an account is missing before showing the app.
public struct OnboardingView: View {
    @State private var model: OnboardingViewModel
    private let onCompleted: @MainActor (UserProfile) -> Void
    private let onSignOut: @MainActor () -> Void

    public init(
        user: UserProfile,
        dependencies: AuthDependencies,
        onCompleted: @escaping @MainActor (UserProfile) -> Void,
        onSignOut: @escaping @MainActor () -> Void
    ) {
        _model = State(initialValue: OnboardingViewModel(user: user, completeOnboarding: dependencies.completeOnboarding))
        self.onCompleted = onCompleted
        self.onSignOut = onSignOut
    }

    public var body: some View {
        NavigationStack {
            Form {
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
                    Text("About you", bundle: .module)
                } footer: {
                    Text("Your name and birth date are private. Others see your display name.", bundle: .module)
                }
                Section {
                    Toggle(isOn: $model.acceptedTerms) {
                        Text("I accept the terms of use and the privacy policy", bundle: .module)
                    }
                    FieldErrorText(model.violations.message(for: "acceptedTerms"))
                    Button {
                        Task {
                            if let user = await model.submit() { onCompleted(user) }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if model.isSubmitting {
                                ProgressView()
                            } else {
                                Text("Continue", bundle: .module).bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(model.isSubmitting)
                    FieldErrorText(model.errorMessage)
                }
            }
            .navigationTitle(Text("Complete your profile", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onSignOut()
                    } label: {
                        Text("Sign out", bundle: .module)
                    }
                }
            }
        }
    }
}
