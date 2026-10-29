# Onboarding and sign-in

Onboarding is a full-screen flow at route `/onboarding/v2` (`lib/features/onboarding_v2`). A signed-out user lands here from cold start. A guarded route sends them here too. `SignedInGuard` (`lib/core/router/route_guards.dart`, used as `_signedInGuard` in `app_router.dart`) saves the target, and `auth_navigation_continuation.dart` pushes `/onboarding/v2` and resumes the target after sign-in. `OnboardingV2Step` has 6 values: `auth`, `interests`, `tasteQuiz` (optional), `starterPack`, `aiGenerate`, `firstWallpaper`. The progress bar shows 4 steps (`totalSteps: 4` in `onboarding_v2_shell.dart`). F0 owns its buttons (`src/views/pages/f0_auth_page.dart`). F1 to F4 pass their CTA label to `OnboardingFrame`.

## Sub-features

- `auth` (F0): `Your screen, reimagined.`, `Continue with Apple` (iOS only), `Continue with Google`, `Browse without an account`, and a terms checkbox (`onboarding_terms_row.dart`).
- `interests` (F1): `Pick your vibe`, category tiles, hint `select at least {count} categories to personalize your feed`, CTA `continue ({count} selected)` then `continue`.
- `taste-quiz`: optional step between interests and starter pack. It has its own buttons.
- `starter-pack` (F2): `Find your people`, `we are suggesting you follow these {count} creators`, CTA `continue`, `reload` if creators are short.
- `ai-generate` (F3): `Create your first wallpaper`, CTA `generate my wallpaper`, `try again` after a failure.
- `first-wallpaper` (F4): `Make it yours`, CTA `set as wallpaper` (Android) or `save to photos` (iOS).
- `skip`: F1 to F4 show a skip button (Semantics `Skip`, text `skip`). There is no `Later`.
- `recovery`: CTA `sign in again` (session expired) or `try again` (save failed).

## How to get to it (user POV)

- Cold-start the app with no stored session (`launch --fresh`).
- Tap a guarded action while signed out (for example the upload button). The guard sends the user here.
- Guest path: `Browse without an account`, then interests, then the signed-out dashboard.

## Driving it with the helper

Preconditions:

- `verify-prism launch --platform <p> --fresh` completed.
- `verify-prism doctor --platform <p>` is clean.

- **Auth screen (F0).** Snapshot `--tag onboarding-auth`. Assert `Continue with Google`, `Browse without an account`, and `Continue with Apple` on iOS only.
- **Terms gate.** Tap a button with the checkbox off. Assert the toast `Please agree to the Terms and Privacy policy first.` The checkbox label is `By continuing you agree to the Terms and Privacy policy`.
- **Do not complete OAuth.** Both provider buttons open real Google/Apple sign-in. Ask the human to sign in if a later step needs a session.
- **Guest path.** Check the terms box, tap `Browse without an account`. Assert `Pick your vibe`. This works without OAuth.
- **Interests, starter pack, AI, first wallpaper.** Assert the headline and CTA text above. Following a creator in F2 follows a real account; ask the human first.
- **Proof.** Snapshot each step you drive. Report a skipped step with the reason.

## Gotchas

- There is no anonymous sign-in shortcut. Do not fake one.
- `launch --fresh` signs out the shared QA account (iOS keychain reset, Android `pm clear`). Only the human can sign back in. Ask before you use it. The 2026-10-29 maintenance run did not drive this flow for that reason.
- CTA labels are lowercase (`app_en.arb`: `onboardingContinue`, `onboardingGenerateWallpaper`, `onboardingSetWallpaper`, `onboardingSavePhotos`). Match them exactly. Welcome labels keep sentence case.
- The F0 buttons stay tappable without the terms box, but they only shake the row and show the toast.
- The F3 step (`f3_ai_generate_page.dart`) is separate from the main AI tab (`/ai`, see `features/ai-wallpaper.md`).
