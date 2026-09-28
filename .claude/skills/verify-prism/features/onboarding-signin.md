# Onboarding and sign-in

Onboarding is a 5-step full-screen shell at route `/onboarding/v2` (`lib/features/onboarding_v2`). A signed-out user lands here from cold start, or gets redirected here by `_signedInGuard` (`lib/core/router/route_guards.dart`) when they try a guarded route. Each step swaps its center content (`lib/features/onboarding_v2/src/views/pages/f0_auth_page.dart` through `f3_first_wallpaper_page.dart`); the background, headline, CTA button, and legal text are owned by the shell (`onboarding_v2_shell.dart`) and stay in place across steps.

## Sub-features

- `auth` (F0): logo + tagline, `continue with Google` CTA, `continue with Apple` CTA (iOS only), legal text.
- `interests` (F1): pick categories, CTA reads `continue (<n> selected)` until the minimum is met, then `continue`.
- `starter-pack` (F2): suggested creators to follow, CTA `continue`.
- `ai-generate` (F3a): generate a first AI wallpaper, CTA `generate my wallpaper`.
- `first-wallpaper` (F3b): CTA `set as wallpaper` (Android) or `save to photos` (iOS).

## How to get to it (user POV)

- Cold-start the app with no stored session (`launch --fresh`).
- Tap any guarded action while signed out (for example a setup upload button); `route_guards.dart` sends the user to `/onboarding/v2`.

## Driving it with the helper

Preconditions:

- `verify-prism launch --platform <p> --fresh` completed.
- `verify-prism doctor --platform <p>` is clean.

- **Auth screen.** Snapshot `--tag onboarding-auth`. Assert the label `continue with Google` (both platforms) and `continue with Apple` (iOS only; `showApple` in `_CtaButton` gates on `TargetPlatform.iOS`).
- **Do not complete OAuth.** Tapping either button opens real Google/Apple sign-in. Stop here for automated proof; ask the human to complete sign-in if a later step needs a session, then resume driving from wherever they land.
- **Interests (needs a session).** Assert the helper text `select at least 3 categories to personalize your feed` and that the CTA label changes from `continue (0 selected)` toward `continue` as the human (or a scripted tap sequence, once signed in) selects categories.
- **Starter pack.** Assert helper text `we are suggesting you follow these 3 creators`. Following someone here follows a real account; treat it like any other real-user side effect and check with the human first if the QA account is not disposable.
- **AI generate.** CTA `generate my wallpaper`; on success the helper text becomes `looking good! tap "use this wallpaper" to continue`, on failure a `something went wrong` message that ends in `tap generate to try again` (the app string has a dash character between the two parts, so match on `tap generate to try again`).
- **First wallpaper.** CTA differs by platform: `set as wallpaper` on Android, `save to photos` on iOS.
- **Proof.** Snapshot each step you actually drive. A skipped step (needs sign-in) is reported as skipped with the reason, not silently omitted.

## Gotchas

- There is no anonymous/E2E sign-in shortcut anywhere in this app. Do not try to fake one; ask a human to sign in.
- All onboarding copy is intentionally lowercase (`'continue with Google'`, not `'Continue with Google'`). Match case exactly when asserting.
- `f0_auth_page.dart` itself renders only the logo and tagline; the actual CTA buttons live in the shell (`onboarding_v2_shell.dart`, `_CtaButton`). Do not go looking for `Continue with Google` inside the page file.
- The AI-generate step here (`f3_ai_generate_page.dart`) is onboarding's own mini flow, separate from the main AI wallpaper tab (`/ai`, see `features/ai-wallpaper.md`). Do not confuse the two when reporting proof.
