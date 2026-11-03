# Public APK download

Some Android users cannot use the Play Store. They ask where to get Prism (#573, #249). Each GitHub release now gets a
universal APK that Google Play signed, and the website has a `/download` page for it. The app shows that page only on
installs that did not come from Google Play.

## What Google Play policy allows

Source: Google Play Developer Policy, Device and Network Abuse
(<https://support.google.com/googleplay/android-developer/answer/9888379>), read on 2026-11-03.

The policy says:

> An app distributed via Google Play may not modify, replace, or update itself using any method other than Google
> Play's update mechanism. Likewise, an app may not download executable code (such as dex, JAR, .so files) from a
> source other than Google Play. This restriction does not apply to code that runs in a virtual machine or an
> interpreter where either provides indirect access to Android APIs (such as JavaScript in a webview or browser).

It also refuses apps that "link to or facilitate the distribution or installation of malicious software".

What this means for Prism:

| Rule | What Prism does |
|---|---|
| A Play install must update only through Play. | A Play install never shows the APK link. The app reads the installer and hides the link when it is `com.android.vending`. |
| No executable code from outside Play. | The app never downloads an APK. It opens `https://prismwalls.com/download` in the browser. The user downloads and installs the file. |
| Interpreted code is allowed. | Shorebird patches run in the Dart VM. They are not part of this feature. |
| No links to malicious software. | The APK is the same file that Play makes from the release bundle, signed by Play. The page shows its SHA-256. |

The rule is fail-closed. If the app cannot read the installer, it hides the link. iOS never shows the link.

## Signing

- Prism uses Play App Signing. Google keeps the app signing key. We sign the `.aab` with the upload key.
- An APK signed with the upload key has a different signature from a Play install. Android refuses to update one with
  the other. So we never publish an upload-key APK.
- The release script downloads the universal APK that Play makes from the same `.aab`
  (Play Developer API, `generatedapks`). Play signs it with the app signing key. A Play install and a sideloaded APK then
  have the same signature. Each one can update the other.
- Google Sign-In checks the signing certificate. The Play app signing certificate is already registered in Firebase
  (the Play build signs in today), so the APK signs in too.

## Shorebird

Shorebird matches an install to a release by `app_id`, platform, architecture and `release_version` (the version name
and build number). It does not use the installer or the APK signature. Its FAQ says "Patches reach side-loaded installs
the same way as store installs" (<https://docs.shorebird.dev/code-push/faq/>). `docs/development/ota.md` already tests
patches on an APK installed with `adb install`.

The Play universal APK has the same version name, version code and `libapp.so` as the `.aab` that `make
release-android` uploaded to Shorebird. Play signs the APK again, but it does not build the Dart code again. So patches
apply to it. This is inferred from the Shorebird docs and the release flow. The first real attach must confirm it on a
device: install the APK, then check that a staging patch arrives (`docs/development/ota.md`, Android steps 5 to 9).
If the patch does not arrive, do not publish more APKs.

## Google Play services

Play Billing (Premium), Firebase Cloud Messaging (notifications) and Google Sign-In need Google Play services. On a
device without them, Prism starts and you can browse and set wallpapers, but you cannot sign in, buy Premium or get
notifications (#249). The download page says this.

## Release step

`tool/public_apk.py` runs after the store upload and after `gh release create` (prism-release skill, step 11b).

```sh
make public-apk TAG='v3.18.2+359' DRY_RUN=1   # download, check, write the SHA-256 file, attach nothing
make public-apk TAG='v3.18.2+359'             # the same, then attach both files to the GitHub release
```

The script:

1. Reads the version and the version code from the tag, and checks that the GitHub release exists.
2. Gets an OAuth token for the Play service account. It uses the same file as fastlane,
   `android/google-play-console.json` (or the path in `PLAY_SERVICE_ACCOUNT_JSON`). It signs the token request with
   `openssl` and passes the private key through a pipe, so the key never goes to disk and never prints. The token is
   never printed. Error text from Google is cut to a short summary.
3. Lists the generated APKs for the version code and picks the universal APK for the pinned certificate.
4. Downloads it, then checks it with `apksigner verify --print-certs` and `aapt2 dump badging`. The APK must have
   exactly one signing certificate, its SHA-256 must equal the pinned Play app signing certificate, and the package and
   version code must match the tag. Any difference stops the script before it attaches anything.
5. Writes `prism-<version>-<code>.apk.sha256` in `sha256sum` format.
6. Uploads both files with `gh release upload` (not in dry-run mode). It does not overwrite an asset that is already
   there.

The pinned certificate is `PLAY_APP_SIGNING_CERT_SHA256` in the script. Copy it from Play Console, Test and release,
App integrity, App signing key certificate, SHA-256. Until it is set, the dry run shows the certificate of the
downloaded APK and the real attach refuses to run.

## Website

`/download` on prismwalls.com:

- The Google Play button comes first. "Download APK" comes second.
- It shows the version, the size and the SHA-256 of the latest release that has an APK, short install steps, and the
  Google Play services note.
- The browser asks the GitHub API for the last 10 releases (`/repos/Hash-Studios/Prism/releases?per_page=10`) and
  keeps the answer in `localStorage` for 1 hour. The SHA-256 comes from the asset `digest` field, so there is no
  second request.
- Read budget: the page reads no Firestore documents and does not call the links Worker, so the #780 catalogue read
  budget does not change. GitHub allows 60 unauthenticated requests an hour for each IP. The page makes at most one
  each hour for each browser.
- If GitHub fails and there is no cached copy, the page says so and links to the GitHub releases page. The Download
  APK button always works without JavaScript: it links to the latest GitHub release.

## App

- `lib/core/platform/install_source.dart` reads `PackageInfo.installerStore` (package_info_plus, already in pubspec).
  On Android 11 and later this is the initiating installer, which the app cannot change.
- The old-version screen opens `/download` instead of Play on a sideloaded install. The page has the Play button
  first, so the user can still pick Play.
- About shows a "Download APK" chip on a sideloaded install.
- Analytics: `apk_link_shown` and `apk_link_tapped`, each with `source` (`old_version` or `about`).

## Needs the owner

- The first real attach: `make public-apk TAG=...` without `DRY_RUN`. The repository is public.
- Set `PLAY_APP_SIGNING_CERT_SHA256` from Play Console before the first real attach.
- The Play service account needs "View app information and download bulk reports" in Play Console to download
  generated APKs.
- Deploy the website after the merge.
