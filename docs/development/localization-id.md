# Indonesian localisation

Indonesian uses Prism's merged localisation foundation from #519
(`bdd3e48c3543c81c007ac13d0ee896f9128c048a`). English remains the preferred
fallback. The generated delegate registers `id` and resolves `id_ID`.

## Coverage

The Indonesian ARB covers all 2,502 canonical English messages, with source
metadata, placeholder types, number formats and ICU selector values preserved.
This includes onboarding, browsing, search, categories, wallpaper actions,
creator accounts, authentication, settings, Premium, coins, streaks, referrals,
AI, notifications, moderation, errors and accessibility labels. Merged #594 adds
translated pending and unconfirmed purchase labels, including the brief delay
while Pro unlocks.

Android has a matching resource for every English string in
`android/app/src/main/res/values-in/strings.xml`. Android's native resource
qualifier uses the legacy Indonesian language code `in`, not the modern code
`id`. AOSP's [resource configuration](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/content/res/ResourcesImpl.java#659)
normalizes `id` to `in`, and the [API 24 `Locale` compatibility helper](https://android.googlesource.com/platform/libcore/+/android-7.0.0_r1/ojluni/src/main/java/java/util/Locale.java#2236)
does the same. The app's Flutter locale and iOS localization remain `id`; only
the Android native resource directory uses `values-in`. iOS has all three
permission messages and all 50 entries in the existing native string catalogue.
Identifiers, brands, creator content, storage paths and backend values remain
unchanged. Indonesian uses Anda, kreator, koin, akses and rangkaian harian.

The shared indirect-string fix `785403a67e469065de4d80ec56a2ae6baf0697aa`
is cherry-picked with provenance. It fixes AI status and remix hints, coin
warnings, quick actions, tile categories, creator ledger labels and the
onboarding AI style chip. This PR does not depend on Spanish translations or
introduce a second extraction system.

Shared follow-up `0b562d29baa5d54ea8bc2d2c3dc39ef2964e755f` is also
cherry-picked with provenance. It adds translated AI prompt pools, sign-in
feature labels and sharing copy, and localizes upload-size and slider displays
without changing persisted values. All 92 additional messages are translated.
Shared fix `133170f1023d5f730c60f3257101c33784c9b7d1` also localizes
collection-preview spend failures using the existing catalogue.
Shared fix `e6f66cd8d2a4b95f562eeda30e026564e5162d38` resolves background
messages from the full preferred-language list, strengthens the indirect-string
guard and adds the translated filter-export failure label.

Shared follow-up `cb46d861373ceac7e442d8d42100f96d708696c0` guards
asynchronous onboarding prompt loads after Back or a newer attempt. Its
regression test is reused; its three English expectation updates were already
present. This source fix is cherry-picked, so there is no runtime dependency on
unmerged PR #597. Spanish-only gift wording is not included.

Shared prompt persistence fixes `8d0498874`, `1085c5ab5` and `fef381070`
are cherry-picked with provenance. Explicit Shuffle, Scene idea and style
choices now persist through draft hydration and locale changes, like manual
edits. Untouched automatic examples remain unsaved and can follow the locale.
The portable regression selects a supported non-English locale. This adds no
catalogue messages and does not require Spanish resources or an unmerged PR.

## Reproducible checks

```sh
python3 tool/check_l10n.py
python3 tool/check_indonesian_l10n.py
fvm flutter gen-l10n
fvm flutter test test/l10n --concurrency=1
make ci ANALYZE_FLAGS=--no-fatal-infos TEST_FLAGS=--concurrency=1
make native-android-check
```

The Indonesian checker validates ARB, Android and iOS contracts and Xcode
registration. With `fonttools` installed it also checks the alphabetic glyphs
against bundled Proxima Nova, Satoshi and Fraunces. That font check passed for
all 52 alphabetic glyphs used by this catalogue.

The locale tests cover delegate loading, English fallback, Indonesian number
formatting, plurals, nested ICU selects, interpolation and a 320 by 640 sheet
at 2x text scale. They also exercise production AI suggestion and upload-size
formatting boundaries. This is an automated layout sample, not full device proof.
All 4,375 scene/lighting/mood/quality combinations are checked against the
existing 160-character generation limit. The longest Indonesian combination
is 158 characters. Every onboarding suggestion also fits that limit.

## Device proof limits

The verify-prism checks cannot run on this Linux host. iOS requires macOS,
Xcode and axe. Android has no emulator binary, QA AVD or `/dev/kvm`.
No simulator/emulator screenshots or full-screen overflow verification are
claimed. Signed-in production flows additionally need human authentication
and appropriate Firebase credentials. Hosted native builds are separate
from real-device verification.

The purchase orchestrator calls `RevenueCatUI.presentPaywall` with a remote
offering. Repository-owned Premium messages are translated here. The remote
paywall template and store product metadata cannot be inspected or verified
without RevenueCat and store access. No remote paywall or store changes are
included, and no claim is made that their Indonesian copy is configured.
