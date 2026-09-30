# Onboarding and sign-in

Onboarding is a 5-step full-screen flow at route `/onboarding/v2` (`lib/features/onboarding_v2`). A signed-out user lands here from cold start, or gets redirected here by `_signedInGuard` (`lib/core/router/route_guards.dart`) when they try a guarded route. The shell (`onboarding_v2_shell.dart`) switches pages and owns the background and progress bar. F0 owns its welcome content, sign-in buttons, and legal row (`src/views/pages/f0_auth_page.dart`). F1-F4 own their content and pass their CTA labels/actions through the shared `OnboardingFrame` (`src/views/widgets/onboarding_frame.dart`).

## Sub-features

- `auth` (F0): logo, “Your screen, reimagined.”, “Continue with Google”, “Continue with Apple” (iOS only), and the legal row.
- `interests` (F1): “Pick your vibe”, category choices, and “Continue” (enabled after the minimum is met).
- `starter-pack` (F2): “Find your people”, suggested creators, and “Continue”.
- `ai-generate` (F3): “Create your first wallpaper”; CTA “Generate” or “Try again” after failure.
- `first-wallpaper` (F4): “Make it yours”; “Set as wallpaper” (Android) or “Save to Photos” (iOS), with “Later” when a wallpaper is available.

## How to get to it (user POV)

- Cold-start the app with no stored session (`launch --fresh`).
- Tap any guarded action while signed out (for example a setup upload button); `route_guards.dart` sends the user to `/onboarding/v2`.

## Driving it with the helper

Preconditions:

- `verify-prism launch --platform <p> --fresh` completed.
- `verify-prism doctor --platform <p>` is clean.

- **Auth screen (F0).** Snapshot `--tag onboarding-auth`. Assert “Continue with Google” (both platforms) and “Continue with Apple” (iOS only; `F0AuthPage` gates on `TargetPlatform.iOS`).
- **Do not complete OAuth.** Tapping either button opens real Google/Apple sign-in. Stop here for automated proof; ask the human to complete sign-in if a later step needs a session, then resume driving from wherever they land.
- **Interests (F1, needs a session).** Assert “Choose at least 3 to shape your feed.” Select three categories, then assert “Continue” is enabled.
- **Starter pack (F2).** Assert “We picked a few creators for you. Follow at least 3.” Following someone here follows a real account; treat it like any other real-user side effect and check with the human first if the QA account is not disposable.
- **AI generate (F3).** Assert “Generate”; on failure, assert “Try again”.
- **First wallpaper (F4).** CTA differs by platform: “Set as wallpaper” on Android, “Save to Photos” on iOS. “Later” is also available when a wallpaper is present.
- **Proof.** Snapshot each step you actually drive. A skipped step (needs sign-in) is reported as skipped with the reason, not silently omitted.

## Gotchas

- There is no anonymous/E2E sign-in shortcut anywhere in this app. Do not try to fake one; ask a human to sign in.
- Match the title-case labels above exactly. F0 sign-in buttons are in `f0_auth_page.dart`; F1-F4 labels are passed to `OnboardingFrame` by their page files.
- The AI-generate step (`f3_ai_generate_page.dart`) is onboarding's own mini flow, separate from the main AI wallpaper tab (`/ai`, see `features/ai-wallpaper.md`). Do not confuse the two when reporting proof.
