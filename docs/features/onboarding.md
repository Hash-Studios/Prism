# Onboarding

Onboarding is the first run flow. It signs the user in, learns their taste, suggests creators, makes a first AI wallpaper, and sets or saves a first wallpaper.

## Where to find it

- It opens by itself on the first launch, from the splash screen (route `OnboardingV2ShellRoute`). Code: `lib/features/onboarding_v2/`.
- It opens again after a log out. The local flag `onboarded_v2_new` is then false.
- A user whose account is marked complete on the server skips every step.

## Platforms and plans

| Item | Android | iOS |
|---|---|---|
| Sign in | Google. Required. | Google or Apple. |
| Browse without an account | Not available. | Available. See "Guest path". |
| First wallpaper action | Sets the wallpaper. | Saves to Photos and shows the set-wallpaper guide. |

All plans see the same steps. A free user also sees the paywall after the last step.

## How it works

Steps, in order:

| Step | Headline | What the user does |
|---|---|---|
| Sign in | "Your screen, reimagined." | Ticks the Terms and Privacy policy box. Then taps a sign-in button. |
| Pick your vibe | "Pick your vibe" | Picks at least 3 categories (or all, if fewer exist). Can skip. |
| Find your people | "Find your people" | Follows the 3 suggested creators, or changes the picks. Can skip. |
| Create your first wallpaper | "Create your first wallpaper" | Taps generate. The AI wallpaper is free here. The step moves on by itself when the image is ready. Can skip. |
| Make it yours | "Make it yours" | Taps the button to set (Android) or save (iOS) the wallpaper. Can skip. |

After the last step, a free user sees the paywall. The server then marks onboarding complete. If the server write fails, the app lets the user in and retries in the background.

All step copy is lowercase. This is part of the onboarding design.

### Sign in step

- The text reads "By continuing you agree to the Terms and Privacy policy". Both words are links (`OnboardingV2Config.termsUrl` and `privacyUrl`).
- The sign-in buttons stay off until the box is ticked. A tap on an off button shows a toast that names the missing step.
- A cancelled sign-in is silent. The user stays on the step.

### First wallpaper

- Android asks the device what it can set. It uses the home and lock screens together when it can. If it cannot, it uses the one screen it can. If it can set none, the step fails with the code `unsupported`.
- After success, the toast names the screens: "Wallpaper set on your home and lock screens." The toast names one screen when only one was set.
- On iOS, the app saves the image to Photos. It then shows the set-wallpaper guide sheet. The notification prompt and the paywall wait until the user closes the sheet. The guide shows once for each app session. If it showed before, the flow moves on at once.
- If the action fails, a snackbar shows "Couldn't set your wallpaper. Try again or skip." (Android) or "Couldn't save your wallpaper. Try again or skip." (iOS). The snackbar has a "Try again" button. The "skip" button stays on the screen.
- On iOS, when Photos access is off, the snackbar says "Allow Prism to add photos in Settings to save wallpapers." and has an "Open settings" button.

### Guest path (iOS only)

Apple App Review Guideline 5.1.1(v) says browsing must not need an account. So iOS has "Browse without an account" under the sign-in buttons.

1. The user ticks the box and taps "Browse without an account".
2. The app shows "Pick your vibe". The picks save on the device only, in the key `onboarding_v2_interests`. The home feed already reads this key.
3. The app sets `onboarded_v2_new` and opens the dashboard without an account.
4. Skip does the same, with no picks saved.
5. Back on "Pick your vibe" returns to the sign-in step.

When the guest signs in later, the picks should go to the account. The repository method `OnboardingV2Repository.syncLocalInterests` does this. The rule: if the account has 3 or more interests, the account wins and the device copy follows it. If not, the device picks go to the account. The sign-in code (`completeSignIn` in `lib/auth/post_sign_in.dart`) must call this method. See Limits.

### Reduced motion

When the system asks for less motion (`MediaQuery.disableAnimations`):

- Text and buttons show at once, with no staggered fade.
- The background zoom and blur jump to the final state.
- The primary button, the progress dots, the AI preview swap and the interest tiles do not animate.

### Analytics

| Event | When |
|---|---|
| `onboarding_started` | The shell opens. |
| `terms_accepted` | The user ticks the box. It does not fire when the box was already ticked in an earlier run. |
| `browse_as_guest_tapped` | The user taps "Browse without an account". |
| `onboarding_step_completed` (`step`) | A step finishes. `step` is `auth`, `interests`, `starter_pack`, `ai_generate` or `first_wallpaper`. A skip does not count. |
| `onboarding_v2_interests_completed`, `onboarding_v2_starter_pack_completed`, `onboarding_v2_first_wallpaper_shown`, `onboarding_v2_first_wallpaper_action`, `onboarding_v2_completed` | These events existed before. They are unchanged. |

### Code map

| Path | Role |
|---|---|
| `lib/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart` | Steps, guest path, analytics. |
| `lib/features/onboarding_v2/src/views/onboarding_v2_shell.dart` | Shell, listeners, snackbars, guide. |
| `lib/features/onboarding_v2/src/services/first_wallpaper_service.dart` | Picks the wallpaper. Sets or saves it. |
| `lib/features/onboarding_v2/src/data/repo/onboarding_v2_repo_impl.dart` | Firestore writes and `syncLocalInterests`. |
| `lib/features/onboarding_v2/src/views/widgets/interest_category_tile.dart` | Category tile. Uses `PrismImageCache` at the tile size. |

## Limits

- Android requires sign-in. This is an App Review decision, not a product wish. The Android guest path is off on purpose. Do not turn it on without the owner.
- The guest picks reach the server only when `completeSignIn` calls `syncLocalInterests`. Until that call exists, a guest who signs in later keeps the picks on the device only.
- The guest path has no AI step, no starter pack and no first wallpaper. These need an account.
- iOS cannot set the wallpaper from the app. The user finishes in Photos.
- The failure snackbar needs the shell `Scaffold`. Tests cover it. No device run was done.

## How to test

1. Fresh install on Android. Check that the "Continue with Google" button is off until you tick the box. Tap the off button. Check the toast.
2. Tap "Terms" and "Privacy policy". Check that each opens the right page.
3. Start Google sign-in and cancel. Check that no toast shows.
4. Finish sign-in. Pick 3 categories. Check that the step moves on.
5. On the AI step, tap generate. Check that the next step opens by itself and that the helper text does not say "tap".
6. On the last step, tap "set as wallpaper". Check the toast text. Check that the home and lock screens changed.
7. Turn on airplane mode. Tap the button again on a wallpaper that is not cached. Check the snackbar and the "Try again" button.
8. iOS: deny Photos access, then tap "save to photos". Check the "Open settings" snackbar.
9. iOS: allow access. Tap "save to photos". Check the toast "Saved to Photos!" and the guide sheet. Close the sheet and check the paywall opens.
10. iOS: tap "Browse without an account". Pick 3 categories. Check that the dashboard opens and the feed follows the picks.
11. iOS guest: sign in from the profile tab. Check that the picks are on the account (field `interestCategories`).
12. Turn on "Remove animations" in the system settings. Run steps 1 to 6. Check that nothing fades or zooms.
13. Check the three new events in the analytics debug view: `onboarding_started`, `terms_accepted`, `onboarding_step_completed`.
