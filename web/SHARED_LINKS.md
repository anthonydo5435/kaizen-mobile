# Website dialog store action

The flow is:

- A tapped link can open the installed app through the existing verified deep links.
- When the link opens in a browser, including when the app is absent, the website loads normally.
- Pasting a link into the browser leaves the visitor on the website.
- Clicking the website's existing dialog button opens the official store for the device.

`shared_link_store_fallback.js` only exposes `getStoreUrl()` and `openStore()`.
It creates no dialog and performs no action when loaded. It does not try to open
the app, detect installation, inspect the referrer or start a fallback timer.
Existing mobile deep-link routes continue to handle app opening.

## Website setup and TypeScript fix

1. Replace the frontend's `public/shared_link_store_fallback.js` with this script.
   Keep one script tag before the frontend application scripts, with an updated
   version to avoid the previous cached behavior:

   ```html
   <script src="/shared_link_store_fallback.js?v=4"></script>
   ```

2. Copy `shared_link_store_fallback.d.ts` into the frontend as
   `src/types/shared_link_store_fallback.d.ts`. This declaration adds
   `KaizenSharedLinks` to TypeScript's `Window` interface, resolving
   `Property 'KaizenSharedLinks' does not exist on type 'Window & typeof globalThis'`.
   Ensure the frontend's `tsconfig.json` includes `src` (or `src/**/*.d.ts`). A
   declaration placed only in `public/` is normally outside the TypeScript source
   set. Keep `export {}` in the declaration file; no runtime import is required.
   This uses TypeScript's [global augmentation](https://www.typescriptlang.org/docs/handbook/declaration-merging.html#global-augmentation).

3. Connect the existing dialog button to this React/TypeScript click handler:

   ```tsx
   const handleDialogButtonClick = () => {
     window.KaizenSharedLinks?.openStore();
   };

   // On the existing button:
   // onClick={handleDialogButtonClick}
   ```

   Keep navigation inside the click handler. Do not call `openStore()` during
   rendering, mounting, script load or in a timer. Keep the existing dialog's
   dismiss action and its design.

4. Remove old automatic redirects, duplicate prompt scripts and earlier
   `getLinks()` / `openAppUrl` integrations. Deploy the website changes together.

`getStoreUrl()` returns the device's official store URL without navigating;
`openStore()` navigates to that URL and returns `true`. Both support Android,
iPhone, iPad (including its desktop user agent), and iPod. On desktop or an
unknown device, `getStoreUrl()` returns `null` and `openStore()` returns `false`
without navigation. If the website uses an anchor for its store action, use
`getStoreUrl()` for the `href` and set `referrerPolicy="no-referrer"`.

Store URLs are fixed:

- https://apps.apple.com/us/app/kaizenteams/id6773032580
- https://play.google.com/store/apps/details?id=com.kaizenteam

The click action is independent of the current page path, so it works for shared
paygrades, shared seat profiles, shared LMS, verification, organization and auth
pages, including after client-side navigation. Loading any of these pages never
triggers a store visit. No mobile update is needed for this website-only change.

The actual website dialog is in the separate frontend repository. This Flutter
repository supplies the script and declaration; it does not automatically bind
or deploy the existing website button.

## Android installed-app verification

Android verifies the installed app's package name and signing certificate against
`https://<link-host>/.well-known/assetlinks.json`. This happens before the website
script or Flutter route handler runs. iOS uses its separate association file.

The September 25, 2026 check of the connected Android phone found:

- Package: `com.kaizenteam`, installed using `flutter run --release`.
- Installed and local release APK SHA-256:
  `8C:84:F7:B4:50:5C:BA:9B:C2:10:B7:A2:F5:CC:6D:A1:1F:7D:A5:18:FA:97:A4:24:29:2A:C8:FC:41:E4:A4:33`.
- The dev and app domains served only the local debug certificate:
  `0D:60:F3:A0:E0:46:07:77:DB:F8:6A:C3:77:81:47:60:07:33:92:2E:0C:5A:E8:C1:DE:07:AE:69:97:5B:12:4D`.
- All three app-link domains were unverified on the phone (verifier code `1024`).
  The API domain's association endpoint returned HTTP 404.
- Android matched the shared LMS URL to `com.kaizenteam/.MainActivity` when the
  intent was explicitly restricted to that package. That check bypasses domain
  verification; it does not prove a normal link tap is verified.

`web/.well-known/assetlinks.json` now contains both observed certificates and
fixes the local package-name typo (`ccom.kaizenteam`). Copy this file to the actual
frontend's `public/.well-known/assetlinks.json` and deploy it on the dev domain to
fix the reported link. Serve a matching association on every domain used for
Android links, including app and api as applicable. Each endpoint must return
HTTP 200 with `Content-Type: application/json`, no login, and no redirect or SPA
HTML fallback. The deployed frontend is separate; this repository change alone
does not publish the file.

The bundled file supports this developer's debug, locally signed release, and
observed Play-installed builds. The October 16, 2026 check confirmed that the
Play-installed app has a different certificate; see the deployment correction
below. For production, choose the certificates for the builds you distribute.
Use the **app signing** SHA-256 from Play Console and verify it against the
installed app; the local/upload certificate does not identify Play-installed
apps. See Android's [website association requirements](https://developer.android.com/training/app-links/configure-assetlinks).

### Play-installed certificate correction — October 16, 2026

The connected phone had version `1.0.6` (version code `8`) of `com.kaizenteam`,
installed by `com.android.vending`. Android's domain status and `apksigner` on
the pulled installed `base.apk` both identified this app signer SHA-256:

```text
C0:7A:66:EE:A0:7A:8C:90:B6:83:A3:C1:65:22:A3:FB:9C:62:4E:71:3B:7A:CB:F7:28:CB:78:D6:36:3B:F0:17
```

Both live app and dev domains still listed only the debug and local release
certificates. Their Android verification state was `1024`. This also explains
why Google's HTTPS Auth Tab returned "Google sign-in could not verify this app"
for the Play build while a locally installed release worked. An earlier report
of `8C:84:…` as the Play certificate was incorrect for this installed build.

The bundled JSON now retains those existing fingerprints and adds the observed
Play signer. Deploy it as the actual frontend's `public/.well-known/assetlinks.json`
on **both app and dev domains**. No new Android release is required for this
website association update. This repository edit alone does not publish it.
After deployment, use the verification commands below and retry the Google
Login button in the Play-installed app. Use `apksigner`'s app signer certificate,
not its separate source-stamp certificate, when comparing future Play builds.

### Production domain

The production link host is `app.kaizenteams.ai`. Its live association file was
also checked on September 25, 2026: HTTP 200 JSON without a redirect, correct
package name, but only the debug certificate. Publish the corrected
`web/.well-known/assetlinks.json` at
`https://app.kaizenteams.ai/.well-known/assetlinks.json` as well to allow the locally
signed release build. Play-distributed builds still require the Play App Signing
certificate if it differs from the local release certificate.

The Android manifest and Flutter handler now accept these production paths:

- `/shared/paygrades/<id>`
- `/shared/seat-profile/<id>`
- `/shared/lms/<id>`
- `/verify_token/<token>`
- `/organization/<id>/ltc/assigned-track/<id>`
- `/auth/password-reset...` with its reset token
- `/auth/google/callback`, consumed only by an active Google sign-in attempt

Production verification and organization paths were missing from Android's
intent filters, and the Flutter resolver previously returned early for that
host. Both are corrected. Ship a new Android build for those two additional
paths. The existing shared-content paths already matched Android's manifest;
their certificate-verification failure is fixed by the website deployment.

After deploying, request fresh verification on the connected phone:

```sh
adb shell pm verify-app-links --re-verify com.kaizenteam
```

Allow verification to finish, then inspect the result:

```sh
adb shell pm get-app-links --user cur com.kaizenteam
```

The tested domain must say `verified`, and link handling must be allowed. Test
normal link resolution without specifying a package:

```sh
adb shell am start -W -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d 'https://dev.kaizenteams.ai/shared/lms/1a854021-68c8-45e4-82fe-65ccd14de182'
```

Repeat using a valid production shared link on `app.kaizenteams.ai`. Confirm that
`pm get-app-links` reports that host as `verified` before treating production
link verification as complete.

Do not force-approve domains or change the installed app's signing key to mask a
website certificate mismatch. Use Android's [verification guide](https://developer.android.com/training/app-links/verify-applinks)
when diagnosing cached verification or a user's Open supported links setting.

## Verification

```sh
node --test test/web/shared_link_store_fallback_test.cjs
```

From this repository, use an available TypeScript compiler to check the script,
declaration and strict TypeScript consumer together:

```sh
tsc --noEmit --strict --allowJs --checkJs --lib ES2020,DOM web/shared_link_store_fallback.js web/shared_link_store_fallback.d.ts test/web/shared_link_store_fallback_types_test.ts
```

After website deployment, check pasted URLs and links from email/messages with
and without the app installed. Browser visits must stay on the website, and only
the existing dialog button should navigate to the appropriate store. Keep the
verified app associations configured for direct opening of installed apps.
