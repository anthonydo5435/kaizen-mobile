# Google sign-in

The Login button uses the existing Google browser OAuth code flow on both platforms.
On iOS it opens the external browser using `url_launcher`, and
`GoogleAuthorizationDataSource` listens through `app_links` for the verified HTTPS
callback. On Android, `GoogleBrowserAuthorizationBridge` opens a browser Auth Tab
and returns its captured HTTPS callback directly through a method channel, without
loading the website callback page. Both paths validate a fresh random `state` and
return the single-use code.
Cancel, denied consent, timeout, and callbacks from older attempts do not create a session.
Browser-added callback fragments (including an empty trailing `#`) are ignored.
The callback must still match the configured scheme, host, port, and path, with
the current `state` and authorization `code` read exclusively from query parameters.
The configured redirect URI remains fragment-free when exchanging the code.

### Android browser return behavior

Android requires a browser with Auth Tab support (Chrome 137 or newer supports it).
The bridge checks support and targets that browser explicitly. An unsupported
browser shows an error on Login instead of opening a regular browser or falling
back to the website. The AndroidX Browser 1.9.0 library already shipped by
`url_launcher_android` is also referenced directly by the bridge.

OAuth success, denied consent, returned OAuth errors, browser dismissal, and
callback-domain verification failures all return to the app. Cancel and the
three-minute timeout finish the browser activity. Request IDs and distinct native
request codes prevent delayed results or cancellation from affecting a retry.
Errors that Google displays without redirecting remain in the Auth Tab until the
user closes it or the attempt times out; the app cannot read Google's browser page.

HTTPS Auth Tab callbacks still require the live domain's `assetlinks.json` to list
the installed app's signing certificate. For Play builds, compare the **App signing
key certificate**, rather than assuming it differs from the local release key.
The Play certificate supplied for this investigation was
`8C:84:F7:B4:50:5C:BA:9B:C2:10:B7:A2:F5:CC:6D:A1:1F:7D:A5:18:FA:97:A4:24:29:2A:C8:FC:41:E4:A4:33`;
it was present on both production and development domains on 2026-10-15.

`GoogleLoginUseCase` sends the code through `AuthRepository` to:

```http
POST /api/v1/accounts/google/login/
Content-Type: application/json

{"code":"<fresh authorization code>","redirect_uri":"https://app.kaizenteams.ai/auth/google/callback"}
```

The response must include nonempty string `access` and `refresh` app tokens.
The shared `LoginSessionUseCase` persists those tokens, fetches the user profile,
and initializes company/organization data exactly as password login does.
If profile initialization fails, the partial app session is cleared.
Existing authenticated deep-link navigation runs after successful login.

## Configuration

The browser flow selects a Web/backend client and its registered callback together
in `data/datasources/google_oauth_configuration.dart`, based on `ApiEndPoints.baseUrl`.
Production uses client `273718420607-q4dcl17i18nql3s6n7hr31o7m5rvsjkf.apps.googleusercontent.com`
with `https://app.kaizenteams.ai/auth/google/callback`, matching the working web app.
The OAuth client ID is public; the Google client secret remains on the backend.
Only `openid email profile` is requested; this does not request Gmail access.

### Platform OAuth configuration

The supplied `android-client.json` and `ios-client.plist` belong to OAuth project
`kaizen-teams` (`273718420607`). Their public client IDs are configured separately
from Firebase Messaging, which uses project `kaizenteams` (`417334653237`). Do not
replace `google-services.json` or `GoogleService-Info.plist` with these OAuth exports.

| Purpose | Client ID | Configuration location |
| --- | --- | --- |
| Android registration | `273718420607-hlfcopqref984gkjpedid02h1cl05sgi.apps.googleusercontent.com` | Google Cloud Android client for `com.kaizenteam` and its signing certificate; recorded in `android/app/src/main/res/values/google_sign_in.xml` |
| iOS client | `273718420607-ome8m3n16fs468u05dbettnmts6n7om9.apps.googleusercontent.com` | `GIDClientID` in `ios/Runner/Info.plist` |
| Production Web/backend client | `273718420607-q4dcl17i18nql3s6n7hr31o7m5rvsjkf.apps.googleusercontent.com` | `GoogleOAuthConfiguration.production`; also recorded in Android `default_web_client_id` and iOS `GIDServerClientID` |
| Development Web/backend client | `273718420607-sma08mj14celj9c4dshthl3nbeqttb12.apps.googleusercontent.com` | `GoogleOAuthConfiguration.development` |

The iOS `REVERSED_CLIENT_ID` is registered as an additional URL scheme in
`ios/Runner/Info.plist`, alongside the existing `kaizenteams` scheme. Its bundle ID
matches `com.kaizenteam`.

Android resolves its native OAuth registration by package name and signing
certificate; the Android client ID is not a `serverClientId` or a replacement for
the browser's Web client ID. The supplied Android export does not include a package
name or signing fingerprint, so these must be checked in Google Cloud. Android
`default_web_client_id` uses the existing Web client because the current Firebase
configuration contains no Web OAuth entry. If an updated `google-services.json`
generates this resource later, remove the manual resource to avoid a duplicate.

The browser flow uses the selected Web/backend environment pair; the Android
and iOS native client IDs are not used in its authorization request. The project
does not include `google_sign_in`. Switching to native sign-in requires SDK integration and
verification that the backend accepts the resulting credentials. These settings
do not replace the HTTPS app-link associations required by the current flow.

### Browser configuration

`https://api.kaizenteams.ai` selects the production pair; the development backend
`https://dev-api.kaizenteams.ai` selects the development pair automatically.
Do not edit separate fallback strings in `GoogleAuthorizationDataSource`.
For an explicit build override, supply both `GOOGLE_OAUTH_CLIENT_ID` and
`GOOGLE_OAUTH_REDIRECT_URI` using Dart defines as a registered pair.
An explicit constructor value takes precedence over the build configuration.
Blank client IDs and mixed production/development pairs fail before opening Google.

The production callback is `https://app.kaizenteams.ai/auth/google/callback`;
the development callback is `https://dev.kaizenteams.ai/auth/google/callback`.
Both are covered by the Android callback intent filters and iOS associated domains.
Xcode Debug and Profile use `ios/Runner/RunnerTesting.entitlements`; Release uses
`ios/Runner/Runner.entitlements`. Keep the production callback domain in both
files. Check `CODE_SIGN_ENTITLEMENTS` for each Runner configuration and inspect
the built app's signed entitlements when debugging a return to the website.
Updating only the Release file does not update builds run from Flutter or Xcode.
The callback is separate from `ApiEndPoints.baseUrl`; never construct it by
appending a path to the REST API host. The code exchange forwards the exact
`redirectUri` returned by authorization, including any explicit override.
The backend and Google's registered redirect must use that exact URI.
Update the Android callback intent filter and
iOS associated domain when changing the callback host/path.

The production domain publishes Android app links and an iOS association covering
`/auth/*`. The installed Android signing certificate must match its published
`/.well-known/assetlinks.json`; additional debug/release signing certificates need
to be registered there. The iOS app ID must match its published association.
The web callback should not exchange a mobile attempt's code before the app receives it.

If the browser reports `redirect_uri_mismatch`, inspect `authorization.config` and
`browser.launch` in the current device log. Google's validation happens before
the app calls the backend. Native Android/iOS credentials and mismatched Web client
and callback pairs both fail this HTTPS browser flow. Backend acceptance of a
redirect URI does not register it for an OAuth client in Google Cloud.

Always start at `https://accounts.google.com/o/oauth2/v2/auth` with a newly
generated state. Google's `/v3/signin/accountchooser` URL is a later step; do not
copy its session parameters (`continue`, `dsh`, or `part`) into the mobile request.
`[REDACTED]` is only the diagnostics display of state, never the transmitted value.

Validate real Google login on an associated Android/iOS build, including return
from the browser, cancel, wrong-account rejection, and the post-login destination.
For Android, also verify the Auth Tab's verification failure and unsupported-browser
errors return to Login without a website fallback.
If the OS kills the app while the browser is open, restart sign-in: the previous
in-memory state is intentionally not accepted by a new app instance.

## Debugging a stalled sign-in

Run a debug build and filter the Flutter console or Android Studio Logcat for
`[GoogleSignIn]`. Each line includes a timestamp and event name. Long response
bodies are split into chunks with the same event name. Authorization codes are
visible in the callback URL, callback parameters, and backend request for debugging.
Tokens, OAuth state, cookies, and email addresses remain masked. These diagnostics
are disabled in release and profile builds.

The expected iOS sequence is `button.pressed` → `authorization.start` →
`browser.launch_result` → `callback.received` → `callback.accepted` →
`backend.request` → `backend.response` → `session_initialization.complete` →
`login.result` → `button.loading_cleared`.
Android uses `auth_tab.launch` instead of `browser.launch_result`, followed by
`callback.received` on a captured callback, `auth_tab.cancelled` on dismissal, or
`auth_tab.error` on a platform/browser verification failure.

- `authorization.waiting` repeats every 15 seconds while awaiting a valid callback.
  If no `callback.received` appears, the browser has not delivered a link to the
  running app. Verify the redirect URL and Android App Links / iOS Universal Links.
  Browser-only Google errors cannot appear in Flutter logs unless Google returns
  an error callback to the app.
- `callback.ignored` records why a received URL or OAuth state was rejected.
- `callback.fragment_ignored` records browser-added fragment metadata without
  rejecting an otherwise valid query callback or reading fragment credentials.
- `google.error` includes returned OAuth error parameters and descriptions.
- `callback.timeout` records the existing three-minute authorization timeout.
- `backend.response` includes HTTP status, headers, and the masked body before
  error handling or JSON decoding, including non-JSON server failures.
- `backend_exchange.waiting` and `session_initialization.waiting` distinguish a
  pending code exchange from loading the user's profile/workspace.
- Failures log the exception type, message, and stack trace. Cancel, completion,
  and failure all stop the corresponding waiting diagnostics.

References:
- https://developers.google.com/identity/protocols/oauth2/web-server
- https://developer.chrome.com/docs/android/custom-tabs/guide-auth-tab
- https://pub.dev/packages/google_sign_in_android
- https://pub.dev/packages/google_sign_in_ios
- https://app.kaizenteams.ai/.well-known/apple-app-site-association
- https://app.kaizenteams.ai/.well-known/assetlinks.json
