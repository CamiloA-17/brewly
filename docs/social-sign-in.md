# Apple and Google sign-in setup

The implementation supports native sign-in, creates new accounts when appropriate and uses
Brewly's existing onboarding and session tokens. Setup values are intentionally empty in the
tracked examples. Debug builds default to `BREWLY_APPLE_SIGN_IN = NO`, allowing a free
Personal Team to sign the app for a physical iPhone. The Apple button is hidden in these
builds; email/password and Google remain available. Release builds default to YES and
include the Apple entitlement. Paid teams can set `BREWLY_APPLE_SIGN_IN = YES` in the ignored
`ios/Config/Local.xcconfig` to test Apple in Debug.

## Apple Developer

1. Use a paid Apple Developer team. Register the app's bundle identifier (default
   `app.brewly.ios`) and enable **Sign in with Apple** for that App ID. Regenerate the
   provisioning profile after enabling it. XcodeGen uses `Brewly/Brewly.entitlements`.
2. Create a Sign in with Apple key associated with the primary App ID and download its `.p8`
   file to a secure location outside the repository. Note its key ID and your team ID.
3. Set these in the server's ignored `.env` or its deployment environment:
   `APPLE_CLIENT_ID` (the exact bundle ID), `APPLE_TEAM_ID`, `APPLE_KEY_ID`,
   `APPLE_PRIVATE_KEY_BASE64` (base64 of the complete PEM file) and
   `APPLE_TOKEN_ENCRYPTION_KEY` (base64 of 32 random bytes, generated with
   `openssl rand -base64 32`). Never commit keys or filled environment files.
4. Put `DEVELOPMENT_TEAM` and, if needed, `BREWLY_BUNDLE_IDENTIFIER` in
   `ios/Config/Local.xcconfig`, along with `BREWLY_APPLE_SIGN_IN = YES`. Run `make ios-project` and use a signed device build to
   validate the Apple sheet with an Apple Account.

Keep the encryption key stable and backed up. Losing it prevents decrypting the Apple tokens
needed for authorization revocation. JWT_SECRET rotation does not change this key. Setting
APPLE_CLIENT_ID without the remaining valid configuration intentionally fails server startup.
For native iOS, no web redirect URL or Services ID is required. If sending mail to Apple private
relay addresses later, register your sending domain with Apple separately.

References: [Apple configuration](https://developer.apple.com/documentation/authenticationservices/implementing-user-authentication-with-sign-in-with-apple),
[token validation](https://developer.apple.com/documentation/signinwithapplerestapi/verifying-a-user),
[token revocation](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens).

## Google Cloud

1. Configure an OAuth consent screen and its audience in Google Cloud. For an external app
   in testing, add the accounts used for manual tests as OAuth test users.
2. Create an **iOS OAuth client** for the exact bundle identifier and a **Web application
   OAuth client** representing the backend. Only public client IDs are needed for this ID-token
   flow; no Google client secret or service-account key is used.
3. Add these to `ios/Config/Local.xcconfig`:
   `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_SERVER_CLIENT_ID` (the Web client ID) and
   `GOOGLE_REVERSED_CLIENT_ID` (reverse the dot-separated components of the iOS client ID).
   XcodeGen emits `GIDClientID`, `GIDServerClientID` and the callback URL scheme in Info.plist.
4. Set the same Web client ID as `GOOGLE_SERVER_CLIENT_ID` in the server's `.env` or deployment
   environment, run `make ios-project`, restart the server and build the app. RootView forwards
   callback URLs to Google's SDK. No Google API access beyond sign-in is requested.

References: [Google iOS setup](https://developers.google.com/identity/sign-in/ios/start-integrating),
[backend validation](https://developers.google.com/identity/sign-in/ios/backend-auth).

## Verification

Run `make db-migrate`, `make db-test`, `make shared-test`, `make server-test` and `make ios-test`.
For server integration tests, use a separately migrated disposable database and set
`TEST_DATABASE_URL` and `JWT_SECRET`. Integration tests truncate user data and auth challenges;
never point them at development data you need to keep or at production.

With the provider setup complete, check on a device:

1. Apple and Google new accounts open onboarding. Complete names, birth date and terms, then
   confirm the brewing tabs appear. Return to the same account after logout and app restart.
2. Apple **Hide My Email** works; provider name hints survive subsequent sign-ins, where Apple
   omits the name. Google and Apple preserve existing profile changes.
3. Cancel each provider sheet: no error banner and no Brewly session are created. Disconnect
   the network and retry; controls become usable again with a localized error.
4. An email already used by a password or other-provider account produces a message to use
   the original sign-in method, preserving that account and its beans and recipes.
5. Delete an Apple account from Profile: Apple authorization is revoked and owned data is
   deleted. Retry if Apple is unavailable; the local account remains until revocation succeeds.
6. Test English and Spanish and light and dark appearance. Both official provider buttons
   localize their own labels; app-owned error messages have Spanish translations.

Deployments must receive the provider environment variables before either method can work
against that API. The Docker Compose API service forwards the optional variables; no cloud
configuration is changed by this implementation.

### Sign-in presentation

The welcome screen leads with email and password, followed by Google and Apple
(where enabled). Its decoration and field labels adapt to shorter screens so the
default sign-in controls fit without scrolling at the standard text size. Scrolling
remains available for the keyboard, validation errors and larger accessibility text.
Registration uses the same rounded fields and card, with a simple account title
instead of repeating the welcome illustration and tagline. Provider buttons share the same width and pill shape. Google
uses its official full-color logo, light/dark button colors, and Google Sans Medium
with localized English and Spanish labels. The logo comes from
[Google's branding assets](https://developers.google.com/identity/branding-guidelines).
The bundled font is a Google Fonts subset for those two labels; its OFL license
is included beside it. Expand the subset when adding other translations.
