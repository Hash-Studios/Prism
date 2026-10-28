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
| This or that | "Pick the one you like more" | Picks 1 of 2 walls, 6 times. Then sees "Tuning your feed" with the first walls of the real feed. Can skip. See "This or that". |
| Find your people | "Find your people" | Follows the 3 suggested creators, or changes the picks. Can skip. |
| Create your first wallpaper | "Create your first wallpaper" | Taps generate. The AI wallpaper is free here. The step moves on by itself when the image is ready. Can skip. |
| Make it yours | "Make it yours" | Taps the button to set (Android) or save (iOS) the wallpaper. Can skip. |

After the last step, a free user sees the paywall. The server then marks onboarding complete. If the server write fails, the app lets the user in and retries in the background.

All step copy is lowercase. This is part of the onboarding design.

### This or that

The quiz shows the user their taste before the first feed. It comes after "Pick your vibe" and only for a signed-in user who confirmed their picks. A skip on "Pick your vibe" and the guest path do not show it.

1. While the interests save, the app loads walls for the quiz (`TasteQuizRepository.loadPlan`). It reads up to 3 of the picked categories and 2 other categories.
2. The app chooses all 12 walls before round 1 (`planTasteQuiz`). If the walls do not load in 3 s, or there are fewer than 12, the step does not show. No error shows. The user goes to the next step.
3. Each round shows 2 walls side by side, edge to edge. The thumbnail shows first. The full-quality preview (the same one the wallpaper screen shows) fades in over it. The app loads the next pair while the user looks at this one.
4. The two walls of a round differ on purpose: light or dark, minimal or busy, warm or cool colour, and category. The app reads these from the tags and the palette colours of the wall.
5. Rounds 3 and 5 are wild cards: both walls come from categories the user did not pick. The label "Wild card" shows above the headline. With few walls from other categories, there is 1 wild card round or none.
6. A tap picks a wall. The phone gives a light haptic. The other wall dims, and a tick shows on the pick. Then the next pair fades in.
7. "Skip" is always on screen. It stores the picks so far and goes straight to the next step. No "Tuning your feed" screen shows after a skip.
8. After round 6, "Tuning your feed" shows. The app builds page 1 of the For you feed with the new picks, and the screen shows its first 6 walls. The feed then opens with that same page. The screen waits up to 4 s for the page and up to 0.8 s for the thumbnails, with placeholder tiles, then holds for 1.5 s. If the page or fewer than 4 thumbnails do not load, it shows the line alone. With Data saver on, the quiz loads thumbnails only.
   The line under the title sums up the picks, for example "Dark, minimal, a bit of neon". Light or dark and minimal or busy come from the pixels of each shown thumbnail (brightness and edge contrast at 48 px), then from tags. When the picks do not agree, the line is "Your feed is ready". Then the next step opens.
9. Back on the quiz returns to "Pick your vibe". The quiz shows only once in an onboarding run, so back and forward never store the picks twice.

The picks go to the taste signals on the device. See "Taste signals" in [home-feed.md](home-feed.md).

Accessibility: each wall is a button with the label "Pick this wallpaper, 1 of 2" (or "2 of 2"). The progress reads "Round 1 of 6". With reduced motion, the dim, the tick and the pair change are instant, and the "Tuning your feed" walls do not fade in.

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
| `onboarding_step_completed` (`step`) | A step finishes. `step` is `auth`, `interests`, `taste_quiz`, `starter_pack`, `ai_generate` or `first_wallpaper`. A skip does not count. |
| `taste_quiz_started` (`source`) | The quiz shows. `source` is `onboarding` or `retake`. |
| `taste_quiz_round_picked` (`source`, `round_index`, `side`, `wild_card`) | The user picks a wall. `round_index` starts at 0. `side` is `left` or `right`. |
| `taste_quiz_skipped` (`source`, `round_index`) | The user taps "Skip". `round_index` is the round on screen. |
| `taste_quiz_completed` (`source`) | The user picks in all 6 rounds. |
| `taste_quiz_retake_opened` | The user taps "Retake This or that" in the Tune sheet. |
| `onboarding_v2_interests_completed`, `onboarding_v2_starter_pack_completed`, `onboarding_v2_first_wallpaper_shown`, `onboarding_v2_first_wallpaper_action`, `onboarding_v2_completed` | These events existed before. They are unchanged. |

### Code map

| Path | Role |
|---|---|
| `lib/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart` | Steps, guest path, analytics. |
| `lib/features/onboarding_v2/src/views/onboarding_v2_shell.dart` | Shell, listeners, snackbars, guide. |
| `lib/features/onboarding_v2/src/services/first_wallpaper_service.dart` | Picks the wallpaper. Sets or saves it. |
| `lib/features/onboarding_v2/src/data/repo/onboarding_v2_repo_impl.dart` | Firestore writes and `syncLocalInterests`. |
| `lib/features/onboarding_v2/src/views/widgets/interest_category_tile.dart` | Category tile. Uses `PrismImageCache` at the tile size. |
| `lib/features/taste_quiz/domain/taste_quiz_rules.dart` | Wall traits, pair choice (`planTasteQuiz`) and the summary line (`summarizeTaste`). |
| `lib/features/taste_quiz/data/repositories/taste_quiz_repository_impl.dart` | Loads the quiz walls in 3 s or gives up. |
| `lib/features/taste_quiz/biz/bloc/taste_quiz_bloc.j.dart` | Rounds, skip, the one write of the signals, the "Tuning your feed" walls. |
| `lib/features/taste_quiz/views/widgets/taste_quiz_view.dart` | The rounds. `tuning_feed_view.dart` is the screen after them. |

## Limits

- Android requires sign-in. This is an App Review decision, not a product wish. The Android guest path is off on purpose. Do not turn it on without the owner.
- The guest picks reach the server only when `completeSignIn` calls `syncLocalInterests`. Until that call exists, a guest who signs in later keeps the picks on the device only.
- The guest path has no AI step, no starter pack and no first wallpaper. These need an account.
- iOS cannot set the wallpaper from the app. The user finishes in Photos.
- The failure snackbar needs the shell `Scaffold`. Tests cover it. No device run was done.
- The quiz pairs walls by tags and palette colours, before any image loads. A Pexels wall has neither, so its pairs contrast on category only. The summary line reads the pixels, so it covers Pexels walls too.
- On For you, the carousel takes the first 4 Prism walls of the page and the grid shows the rest. So the "Tuning your feed" walls all show at the top, but not in the same order.
- The brightness and edge cut-offs come from 120 cached thumbnails on one device (2026-10-28).

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
14. With a new account, pick 3 categories. Check that "This or that" shows "1 of 6" and two walls side by side. Pick 6 times. Check "Tuning your feed" and that the starter pack opens after it.
15. Run 14 again and tap "Skip" in round 2. Check that the starter pack opens at once.
16. Turn on airplane mode, confirm the categories, wait 5 s, then turn airplane mode off. The interests save waits for the network, and the quiz walls give up after 3 s. Check that the starter pack opens and no quiz or error shows.
