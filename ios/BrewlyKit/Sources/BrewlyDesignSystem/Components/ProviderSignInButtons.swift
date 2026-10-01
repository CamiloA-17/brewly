import AuthenticationServices
import BrewlyDomain
import CoreText
import SwiftUI

/// Provider controls share the auth layout while preserving their brand identities.
public struct ProviderSignInButtons: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    private let appleSignInEnabled: Bool
    private let action: @MainActor (IdentityProvider) -> Void
    public init(appleSignInEnabled: Bool = true, action: @escaping @MainActor (IdentityProvider) -> Void) {
        self.appleSignInEnabled = appleSignInEnabled
        self.action = action
    }
    public var body: some View {
        VStack(spacing: Spacing.m) {
            Button { action(.google) } label: {
                HStack(spacing: Spacing.m) {
                    Image("GoogleSignInLogo", bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text("Continue with Google", bundle: .module)
                        .font(Self.googleFont)
                }
                .padding(.horizontal, Spacing.l)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .foregroundStyle(Color(light: 0x1F1F1F, dark: 0xE3E3E3))
                .background(Color(light: 0xFFFFFF, dark: 0x131314), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color(light: 0x747775, dark: 0x8E918F), lineWidth: 1)
                }
                .opacity(isEnabled ? 1 : 0.5)
            }
            .buttonStyle(.plain)

            if appleSignInEnabled {
                AppleButton(style: colorScheme == .dark ? .white : .black) { action(.apple) }
                    .frame(height: 52)
                    .id(colorScheme)
            }
        }
    }

    private static let googleFont: Font = {
        if let url = Bundle.module.url(forResource: "GoogleSans-Medium", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
               let descriptor = descriptors.first {
                let font = CTFontCreateWithFontDescriptor(descriptor, 14, nil)
                return .custom(CTFontCopyPostScriptName(font) as String, size: 14, relativeTo: .subheadline)
            }
        }
        return .system(.subheadline, design: .default).weight(.medium)
    }()
}

private struct AppleButton: UIViewRepresentable {
    let style: ASAuthorizationAppleIDButton.Style
    let action: @MainActor () -> Void
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .continue, style: style)
        button.cornerRadius = 26
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
    func updateUIView(_ view: ASAuthorizationAppleIDButton, context: Context) {
        view.isEnabled = context.environment.isEnabled
    }
}
