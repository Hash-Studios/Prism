# German localisation verification

## Foundation and scope

The German locale reuses the Flutter `gen-l10n` foundation merged in [PR #519](https://github.com/Hash-Studios/Prism/pull/519), commit `bdd3e48c3543c81c007ac13d0ee896f9128c048a`.
The canonical English catalogue has 2,498 messages after the shared source-copy fixes. English remains the preferred fallback. Device German selects the generated German locale, including regional variants such as `de-DE` and `de-AT`.

The Spanish language thread owns shared source-copy fixes. Its early handoff commit `eea336def` contains documentation only and is not a prerequisite for German. This branch reuses shared commit `785403a67e469065de4d80ec56a2ae6baf0697aa`, cherry-picked as `853206c00`. That commit localizes AI preparation and remix copy, coin-gate shortages, creator ledger labels, shortcuts, tile categories, and the onboarding style chip. The PR targets master and does not depend on the Spanish PR.

The continuation reuses `0b562d29b` as `61e48d276`, `b86755b35` as `a6a06cf00`, and `133170f10` as `d1bcc0ffb`. These commits localize AI prompt pools, the share signature, sign-in feature labels, debug exports, upload number presentation, and collection preview failures. Restored user-authored prompts remain unchanged. The German prompt catalogue covers all seven styles in both main and onboarding pools.

The locale covers the app catalogue, including admin and debug UI, Android widgets and Quick Settings, native push notifications, iOS App Shortcuts, and photo and camera permission descriptions. User names, authored wallpaper titles, backend identifiers, routes, and external campaign content are not translated.

## Checks

The German coverage check is `python3 tool/check_german_localization.py`. The shared catalogue and source-copy gate is `make l10n-check`. German runtime and layout tests are in `test/l10n/german_locale_test.dart`. The complete local gate is `make ci`.

Baseline checks before integration passed five existing localisation tests and the source audit reported zero probable UI literals, with 4,870 indirect literals to classify. Static analysis reported 321 info-level findings and no errors or warnings. These baseline results are not proof for the final German tree.

`fc-query` character maps confirm German umlauts and ß in the inspected Proxima Nova regular and bold, Satoshi regular, and Fraunces fonts. Runtime layout tests check actual German messages separately.

The 2,498-message catalogue passes `python3 tool/check_german_localization.py`, including exact template metadata and native placeholder parity. The check retains an explicit key-and-value list for 145 identical messages. These are brands, technical units, valid German words, and runtime placeholder compositions, not untranslated prose.

`fvm flutter test test/l10n` passed all 12 tests after the five shared messages were added. The tests cover German regional locale resolution, English fallback, live locale changes, plurals, grouped numbers, dates, categories, and stable wire values. Three real components run at 320px and 2× text scale with bundled fonts. This sample does not prove every screen is free from overflow.

## Device limits

The T3 device inventory reports no devices. This Linux host cannot run an iOS Simulator because macOS and Xcode are absent. The Android SDK exists at `/home/ubuntu/android-sdk`, but it has no emulator package or AVD, and `/dev/kvm` is absent.

The `verify-prism doctor` attempt fails because `axe` is absent. No simulator or emulator screenshots, OAuth, live feed, purchase, or notification-delivery checks have been claimed. Native resource parity and hosted native builds are separate checks from device behaviour.

## Final gate records

The early `make native-android-check CI=true` build was cancelled with exit 143 to reduce host swap pressure while common source fixes were still in progress. It is not Android build proof.

The pre-reconciliation local gate passed formatting, catalogue generation, the source audit, audit tests, repository guards, and analytics contract tests. It was stopped at static analysis before applying the second shared source unit. That partial run is not final-tree proof.

Final local and hosted outcomes belong to the PR verification section and must identify the checked head commit. Hosted native builds do not replace simulator or emulator screenshots. Live RevenueCat marketing copy and store-provided purchase text require a configured service and signed-in device, so they are outside the proof available on this host.
