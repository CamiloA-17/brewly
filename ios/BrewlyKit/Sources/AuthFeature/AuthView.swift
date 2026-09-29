import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

public struct AuthDependencies: Sendable {
    public var signIn: SignInUseCase
    public var signUp: SignUpUseCase
    public var completeOnboarding: CompleteOnboardingUseCase

    public init(signIn: SignInUseCase, signUp: SignUpUseCase, completeOnboarding: CompleteOnboardingUseCase) {
        self.signIn = signIn
        self.signUp = signUp
        self.completeOnboarding = completeOnboarding
    }
}

/// Sign in and sign up screens.
public struct AuthView: View {
    private enum Mode {
        case signIn
        case signUp
    }

    @State private var mode = Mode.signIn
    @State private var signInModel: SignInViewModel
    @State private var signUpModel: SignUpViewModel
    private let onAuthenticated: @MainActor (UserProfile) -> Void

    public init(dependencies: AuthDependencies, onAuthenticated: @escaping @MainActor (UserProfile) -> Void) {
        _signInModel = State(initialValue: SignInViewModel(signIn: dependencies.signIn))
        _signUpModel = State(initialValue: SignUpViewModel(signUp: dependencies.signUp))
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                }
                .listRowBackground(Color.clear)

                switch mode {
                case .signIn:
                    signInForm
                case .signUp:
                    signUpForm
                }

                Section {
                    Button {
                        withAnimation { mode = mode == .signIn ? .signUp : .signIn }
                    } label: {
                        switch mode {
                        case .signIn: Text("New to Brewly? Create an account", bundle: .module)
                        case .signUp: Text("Already have an account? Sign in", bundle: .module)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.brewlyAccent)
            Text(verbatim: "Brewly")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.brewlyEspresso)
            Text("Share your beans, recipes and brews.", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.l)
    }

    @ViewBuilder
    private var signInForm: some View {
        Section {
            TextField(String(localized: "Email", bundle: .module), text: $signInModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            FieldErrorText(signInModel.violations.message(for: "email"))
            SecureField(String(localized: "Password", bundle: .module), text: $signInModel.password)
                .textContentType(.password)
            FieldErrorText(signInModel.violations.message(for: "password"))
        }
        Section {
            submitButton(title: Text("Sign in", bundle: .module), isSubmitting: signInModel.isSubmitting) {
                if let user = await signInModel.submit() { onAuthenticated(user) }
            }
            FieldErrorText(signInModel.errorMessage)
        }
    }

    @ViewBuilder
    private var signUpForm: some View {
        Section {
            TextField(String(localized: "First name", bundle: .module), text: $signUpModel.firstName)
                .textContentType(.givenName)
            FieldErrorText(signUpModel.violations.message(for: "firstName"))
            TextField(String(localized: "Last name", bundle: .module), text: $signUpModel.lastName)
                .textContentType(.familyName)
            FieldErrorText(signUpModel.violations.message(for: "lastName"))
            BirthDateField(date: $signUpModel.birthDate)
            FieldErrorText(signUpModel.violations.message(for: "birthDate"))
        } header: {
            Text("About you", bundle: .module)
        } footer: {
            Text("Your name and birth date are private. Others see your display name.", bundle: .module)
        }
        Section {
            TextField(String(localized: "Email", bundle: .module), text: $signUpModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            FieldErrorText(signUpModel.violations.message(for: "email"))
            TextField(String(localized: "Username", bundle: .module), text: $signUpModel.username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            FieldErrorText(signUpModel.violations.message(for: "username"))
            SecureField(String(localized: "Password", bundle: .module), text: $signUpModel.password)
                .textContentType(.newPassword)
            FieldErrorText(signUpModel.violations.message(for: "password"))
        } header: {
            Text("Account", bundle: .module)
        } footer: {
            Text("Usernames use lowercase letters, numbers, dots and underscores.", bundle: .module)
        }
        Section {
            Toggle(isOn: $signUpModel.acceptedTerms) {
                Text("I accept the terms of use and the privacy policy", bundle: .module)
            }
            FieldErrorText(signUpModel.violations.message(for: "acceptedTerms"))
            submitButton(title: Text("Create account", bundle: .module), isSubmitting: signUpModel.isSubmitting) {
                if let user = await signUpModel.submit() { onAuthenticated(user) }
            }
            FieldErrorText(signUpModel.errorMessage)
        }
    }

    private func submitButton(title: Text, isSubmitting: Bool, action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Spacer()
                if isSubmitting {
                    ProgressView()
                } else {
                    title.bold()
                }
                Spacer()
            }
        }
        .disabled(isSubmitting)
    }
}
