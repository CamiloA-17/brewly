import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

public struct AuthDependencies: Sendable {
    public var appleSignInEnabled: Bool
    public var federatedSignIn: FederatedSignInUseCase
    public var signIn: SignInUseCase
    public var signUp: SignUpUseCase
    public var completeOnboarding: CompleteOnboardingUseCase

    public init(
        federatedSignIn: FederatedSignInUseCase,
        signIn: SignInUseCase,
        signUp: SignUpUseCase,
        completeOnboarding: CompleteOnboardingUseCase,
        appleSignInEnabled: Bool = true
    ) {
        self.appleSignInEnabled = appleSignInEnabled
        self.federatedSignIn = federatedSignIn
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

    @State private var federatedModel: FederatedSignInViewModel
    @State private var mode = Mode.signIn
    @State private var signInModel: SignInViewModel
    @State private var signUpModel: SignUpViewModel
    private let appleSignInEnabled: Bool
    private let onAuthenticated: @MainActor (UserProfile) -> Void

    public init(dependencies: AuthDependencies, onAuthenticated: @escaping @MainActor (UserProfile) -> Void) {
        _federatedModel = State(initialValue: FederatedSignInViewModel(signIn: dependencies.federatedSignIn))
        _signInModel = State(initialValue: SignInViewModel(signIn: dependencies.signIn))
        _signUpModel = State(initialValue: SignUpViewModel(signUp: dependencies.signUp))
        appleSignInEnabled = dependencies.appleSignInEnabled
        self.onAuthenticated = onAuthenticated
    }

    @FocusState private var focusedField: AuthField?

    private enum AuthField: Hashable {
        case email
        case password
        case firstName
        case lastName
        case signUpEmail
        case username
        case newPassword
    }

    private var isSubmitting: Bool {
        federatedModel.isSubmitting || signInModel.isSubmitting || signUpModel.isSubmitting
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: Spacing.l) {
                        if mode == .signIn {
                            header(compact: geometry.size.height < 740)
                            signInForm(compact: geometry.size.height < 740)
                        } else {
                            Text("Create account", bundle: .module)
                                .font(.system(.largeTitle, design: .serif, weight: .medium))
                                .foregroundStyle(Color.brewlyEspresso)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            signUpForm
                        }
                        modeButton
                    }
                    .frame(maxWidth: 440)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.l)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
            }
            .background {
                LinearGradient(
                    colors: [.brewlyCard, .brewlyCrema.opacity(0.35), .brewlyCard],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .tint(.brewlyAccent)
            .disabled(isSubmitting)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func header(compact: Bool) -> some View {
        VStack(spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(Color.brewlyAccent)
                Text(verbatim: "Brewly")
                    .foregroundStyle(Color.brewlyEspresso)
            }
            .font(.title3.weight(.semibold))

            if !compact {
                ZStack {
                    Circle()
                        .fill(Color.brewlyCrema.opacity(0.5))
                        .frame(width: 68, height: 68)
                    Circle()
                        .strokeBorder(Color.brewlyAccent.opacity(0.18), lineWidth: 1)
                        .frame(width: 84, height: 84)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.brewlyAccent)
                }
                .accessibilityHidden(true)
            }

            VStack(spacing: Spacing.s) {
                Text("A better cup starts here.", bundle: .module)
                    .font(.system(compact ? .title2 : .title, design: .serif, weight: .medium))
                    .foregroundStyle(Color.brewlyEspresso)
                if !compact {
                    Text("Your beans, your recipes, your daily ritual.", bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func signInForm(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Welcome back", bundle: .module)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.brewlyEspresso)
                if !compact {
                    Text("Sign in to your brewing routine.", bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                if !compact {
                    Text("Email", bundle: .module)
                        .font(.subheadline.weight(.medium))
                }
                HStack(spacing: Spacing.m) {
                    Image(systemName: "envelope")
                        .foregroundStyle(Color.brewlyAccent)
                        .accessibilityHidden(true)
                    TextField(String(localized: "Email", bundle: .module), text: $signInModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }
                .modifier(AuthFieldStyle(isFocused: focusedField == .email))
                FieldErrorText(signInModel.violations.message(for: "email"))
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                if !compact {
                    Text("Password", bundle: .module)
                        .font(.subheadline.weight(.medium))
                }
                HStack(spacing: Spacing.m) {
                    Image(systemName: "lock")
                        .foregroundStyle(Color.brewlyAccent)
                        .accessibilityHidden(true)
                    SecureField(String(localized: "Password", bundle: .module), text: $signInModel.password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { submitSignIn() }
                }
                .modifier(AuthFieldStyle(isFocused: focusedField == .password))
                FieldErrorText(signInModel.violations.message(for: "password"))
            }

            Button(action: submitSignIn) {
                HStack(spacing: Spacing.s) {
                    if signInModel.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Sign in", bundle: .module)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .foregroundStyle(.white)
                .background(Color(light: 0x3B241A, dark: 0x70472F), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Sign in", bundle: .module))
            FieldErrorText(signInModel.errorMessage)
            providerSignIn
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.l)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.brewlyAccent.opacity(0.12), lineWidth: 1)
        }
    }

    private func submitSignIn() {
        guard !isSubmitting else { return }
        focusedField = nil
        Task {
            if let user = await signInModel.submit() { onAuthenticated(user) }
        }
    }

    private var providerSignIn: some View {
        VStack(spacing: Spacing.m) {
            HStack(spacing: Spacing.m) {
                Rectangle().fill(Color.brewlyAccent.opacity(0.2)).frame(height: 1)
                Text("or continue with", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                Rectangle().fill(Color.brewlyAccent.opacity(0.2)).frame(height: 1)
            }
            ProviderSignInButtons(appleSignInEnabled: appleSignInEnabled) { provider in
                focusedField = nil
                Task {
                    if let user = await federatedModel.submit(provider) { onAuthenticated(user) }
                }
            }
            if federatedModel.isSubmitting { ProgressView() }
            FieldErrorText(federatedModel.errorMessage)
        }
    }

    private var modeButton: some View {
        Button {
            focusedField = nil
            withAnimation { mode = mode == .signIn ? .signUp : .signIn }
        } label: {
            switch mode {
            case .signIn: Text("New to Brewly? Create an account", bundle: .module)
            case .signUp: Text("Already have an account? Sign in", bundle: .module)
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Color.brewlyEspresso)
        .multilineTextAlignment(.center)
        .padding(.vertical, Spacing.s)
    }

    private var signUpForm: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("About you", bundle: .module)
                .font(.title3.weight(.semibold))
            signUpField("First name", icon: "person", field: .firstName,
                        error: signUpModel.violations.message(for: "firstName")) {
                TextField(String(localized: "First name", bundle: .module), text: $signUpModel.firstName)
                    .textContentType(.givenName)
                    .focused($focusedField, equals: .firstName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .lastName }
            }
            signUpField("Last name", icon: "person", field: .lastName,
                        error: signUpModel.violations.message(for: "lastName")) {
                TextField(String(localized: "Last name", bundle: .module), text: $signUpModel.lastName)
                    .textContentType(.familyName)
                    .focused($focusedField, equals: .lastName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .signUpEmail }
            }
            HStack(spacing: Spacing.m) {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.brewlyAccent)
                    .accessibilityHidden(true)
                BirthDateField(date: $signUpModel.birthDate)
            }
            .modifier(AuthFieldStyle(isFocused: false))
            FieldErrorText(signUpModel.violations.message(for: "birthDate"))
            Text("Your name and birth date are private. Others see your display name.", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Account", bundle: .module)
                .font(.title3.weight(.semibold))
                .padding(.top, Spacing.s)
            signUpField("Email", icon: "envelope", field: .signUpEmail,
                        error: signUpModel.violations.message(for: "email")) {
                TextField(String(localized: "Email", bundle: .module), text: $signUpModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .signUpEmail)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .username }
            }
            signUpField("Username", icon: "at", field: .username,
                        error: signUpModel.violations.message(for: "username")) {
                TextField(String(localized: "Username", bundle: .module), text: $signUpModel.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .newPassword }
            }
            Text("Usernames use lowercase letters, numbers, dots and underscores.", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)
            signUpField("Password", icon: "lock", field: .newPassword,
                        error: signUpModel.violations.message(for: "password")) {
                SecureField(String(localized: "Password", bundle: .module), text: $signUpModel.password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .newPassword)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
            Toggle(isOn: $signUpModel.acceptedTerms) {
                Text("I accept the terms of use and the privacy policy", bundle: .module)
                    .font(.subheadline)
            }
            FieldErrorText(signUpModel.violations.message(for: "acceptedTerms"))
            Button {
                focusedField = nil
                Task {
                    if let user = await signUpModel.submit() { onAuthenticated(user) }
                }
            } label: {
                HStack(spacing: Spacing.s) {
                    if signUpModel.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create account", bundle: .module).fontWeight(.semibold)
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .foregroundStyle(.white)
                .background(Color(light: 0x3B241A, dark: 0x70472F), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Create account", bundle: .module))
            FieldErrorText(signUpModel.errorMessage)
            providerSignIn
        }
        .padding(Spacing.l)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.brewlyAccent.opacity(0.12), lineWidth: 1)
        }
    }

    private func signUpField<Content: View>(
        _ title: String, icon: String, field: AuthField, error: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(String(localized: String.LocalizationValue(title), bundle: .module))
                .font(.subheadline.weight(.medium))
            HStack(spacing: Spacing.m) {
                Image(systemName: icon)
                    .foregroundStyle(Color.brewlyAccent)
                    .accessibilityHidden(true)
                content()
            }
            .modifier(AuthFieldStyle(isFocused: focusedField == field))
            FieldErrorText(error)
        }
    }

}

private struct AuthFieldStyle: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(Spacing.l)
            .frame(minHeight: 52)
            .background(Color.brewlyCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.brewlyAccent.opacity(isFocused ? 0.8 : 0.15), lineWidth: 1)
            }
    }
}
