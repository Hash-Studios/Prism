# Localization verification

Verified on 19 October 2026 against source commit `711b34c2`, which includes master `91d9f5ff`.

## Automated checks

- `PATH=/opt/homebrew/opt/grep/libexec/gnubin:/Users/codenameakshay/fvm/versions/3.47.5/bin:$PATH CI=true make ci` passed. The Flutter suite passed 4,877 tests and skipped 187 existing cases. Analysis had informational findings, with no errors or warnings.
- `npm run build` and `node --test 'lib/__tests__/*.test.js'` in `functions/` passed 1,074 tests with 8 skipped.
- `make file-gen` completed. Generated source is committed.
- Catalog validation passed for 2,376 English messages. The AST guard reported zero probable UI literals. Indirect values were reviewed separately, including enum labels, error presentation, report wire values, relative times, and notification copy. Protocol identifiers, diagnostic logs, brands, and user-authored content remain literal.
- A temporary copy of the complete final catalog generated successfully for English and Arabic, with English first in supported locales. This was a generation fixture, not an Arabic translation, and is not shipped.
- Widget tests cover locale changes, English fallback, ICU plurals and number grouping, RTL button ordering, and long sheet content at large text scale.
- Notification tests cover legacy text, structured copy, native resource coverage, current-token capability markers, dual-topic migration, unknown data-only push suppression, and blank-title fallbacks.

## Native builds and device scope

Both commands passed using Flutter 3.47.5:

```sh
fvm flutter build ios --debug --simulator --dart-define=SKIP_FIREBASE_INIT=true
fvm flutter build apk --debug --dart-define=SKIP_FIREBASE_INIT=true
```

The user authorized isolated QA devices because the designated shared devices were occupied. Verification used `Prism Localization QA iPhone` on iOS 27.0 and `Prism_Localization_QA_API36` on Android API 36. The existing verification helper used isolated state and lock paths. iOS interaction used the device tool when AXe taps did not change the screen.

The signed-out path covers onboarding, guest browsing, profile, settings, notification preferences on iOS, and the wallpaper-target picker on Android. Screenshots are attached to the PR. No credentials or real-account actions were used.

## Release limits

Only English ships in this PR. A new language requires a translated ARB catalog and matching native resources, as described in [Localization](localization.md).

The UI builds skip Firebase initialization. They do not prove live feeds, OAuth, purchases, or FCM delivery. The Functions update must deploy before a client release because new clients subscribe to localized notification topics. No backend deployment, store release, or live push test was performed.
