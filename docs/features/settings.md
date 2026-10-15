# Settings

Settings holds the app switches, the storage tools, the account actions, the privacy tools and the help rows. Code: `lib/features/session/views/pages/settings_screen.dart`. The route is `SettingsRoute`.

## Where to find it

Profile drawer, then Settings. The sections run in this order:

1. APPEARANCE: Themes, Haptic feedback.
2. PERSONALISE (Android only): Auto-rotate wallpapers, Live wallpapers, Quick tiles, Wallpaper history, Default action for Set.
3. CONTENT FILTERS: Show anime wallpapers, Show sketchy wallpapers (Android only).
4. NOTIFICATIONS: Notification preferences.
5. STORAGE: Data saver, Clear cache, Clear all downloads.
6. ACCOUNT: Sign in (guest) or profile card, Review status, Blocked accounts, Share your profile, Clear favourite wallpapers, Log out.
7. PREMIUM: Buy premium (free users), Restore purchases (everyone), Manage subscription (Premium users).
8. PRIVACY AND DATA: Privacy policy, Terms of use, Ad privacy choices (only where required), Clear learned taste, Delete account (signed in).
9. ADMIN (admins only).
10. HELP: Report a problem, About Prism.

The Wallpaper history row shows on Android only. iOS cannot set a wallpaper from the app, so the list would stay empty.

## Platforms and plans

| Item | Android | iOS | Plan |
|---|---|---|---|
| All rows above | yes | yes, except the PERSONALISE section and Show sketchy wallpapers | Free |
| Auto-rotate wallpapers | yes | no | Premium |
| Ad privacy choices | only when the consent form allows it | same | Free |

## How it works

### Privacy and data

- **Privacy policy** and **Terms of use** open `https://prismwalls.com/privacy` and `https://prismwalls.com/terms` with `openPrismLink`. When no app can open the link, an error toast reads "Couldn't open the link. Try again."
- **Ad privacy choices** shows only when `AdConsent.instance.privacyOptionsRequired()` is true. It opens the Google consent form with `AdConsent.instance.showPrivacyOptions()`. Users in the EEA and the UK can change their choice there.
- **Clear learned taste** asks first and shows how many signals Prism holds. After the user confirms, it clears the `TasteSignalStore` and raises `personalizedFeedSettingsRevision`, so the home feed refreshes. When nothing is learned yet, it shows a neutral toast and no dialog.
- **Delete account** (signed-in users only) is in this section. See "Delete account" below.
- **Export favourites** is not in the app yet. See Limits.

### Delete account

1. The dialog says what Prism removes, that uploaded wallpapers stay visible as "Deleted Account", and "You will confirm with Google or Apple next."
2. The user taps "Delete account". A loader shows.
3. `DeleteAccountService` asks Google or Apple to confirm, calls the `deleteAccount` function (timeout 300 seconds, because the server deletes in batches), signs out, then clears the data on this device.
4. The local clean up (`LocalAccountDataCleaner`) removes the favourite id set of the user, the guest favourites, the downloaded wallpaper index, the wallpaper history and the feed cache. One failed step does not stop the others.
5. The loader closes first, then the app restarts.
- If the user closes the Google or Apple prompt, the loader closes and nothing else happens. There is no toast.
- If the user picks the wrong Google account, a toast asks for the signed-in account.
- Any other failure shows "Something went wrong. Try again."

### Log out

- The dialog reads: "Signing out clears history and learned taste on this device. Favourites, coins and profile stay with your account."
- A failed sign out shows "Couldn't log out. Try again." This is the same text as the drawer should show.
- A good sign out shows no toast. The restart is the feedback.

### Guests

- The Sign in row reads "Sign in to keep your favourites, coins and profile".
- Restore purchases is in the PREMIUM section, so guests see it too.

### Data saver

- A switch in STORAGE. The settings key is `lowDataMode`. Code: `lib/features/session/data/low_data_mode.dart`.
- `LowDataMode.enabled` is a `ValueNotifier<bool>`. Screens read `LowDataMode.enabled.value` and listen to it. `await LowDataMode.set(bool)` saves the value and tells the listeners.
- The switch text promises three effects: the wallpaper page opens the thumbnail first, the feeds do not load ahead, and carousels do not autoplay. Each screen applies them. A screen that does not read `LowDataMode.enabled` ignores the switch.

### Clear cache, downloads and favourites

- Each action asks first, with a title and the count or size: "Clear cache?" (shows the size), "Delete all downloads?" (shows the count, "This cannot be undone."), "Clear all favourites?" (shows the count, "This cannot be undone.") and "Clear learned taste?".
- The cache size counts the folders `libCachedImageData`, `prism_images` and `prism_full`.

### Content filters

- After the switch writes `WHcategories` or `WHpurity`, Settings raises `personalizedFeedSettingsRevision`. The home feed then fetches again with the new filter.

### Report a problem

- Row in HELP, and the fallback of FEEDBACK in About when no mail app opens. Code: `lib/features/session/data/report_problem_service.dart`, `lib/features/session/views/widgets/report_problem_sheet.dart`.
- The report is a text file: app version, device, OS, theme, signed in (yes or no), and the last 300 log lines from `InMemoryLogSink`. It has no email address and no user id.
- `scrubSensitive` removes email addresses, bearer tokens, JWTs, FCM tokens, values next to names such as `token`, `api_key`, `secret`, `password`, URL query strings, and long id-like strings. It runs on every line.
- The sheet shows the full text before sharing. "Share" writes `prism-problem-report.txt` to the temporary folder and opens the share sheet. The sheet also names the support address.
- Analytics: `report_problem_opened{source}`, `report_problem_shared{result}`.

### About

- A link that fails to open shows a snackbar with the address and a Copy action.
- FEEDBACK keeps the `mailto:` link. When it fails, it opens the Report a problem sheet.
- WHAT'S NEW reopens the changelog popup.
- The contributor list loads once per session. A failed load is not kept, so "Try again" loads again. Missing fields in the GitHub data do not crash the screen.

### Rate prompt

Code: `lib/core/rating/rate_prompt_service.dart`, `lib/core/rating/rate_prompt_sheet.dart`.

- Call `RatePromptService.instance.maybePrompt(context, RatePromptTrigger.wallpaperSet)` after a good set, or `RatePromptTrigger.download` after a good download. Each call counts one action.
- Prism asks only when all of these are true:
  - the user did at least 3 sets or downloads;
  - at least 5 days passed since the first launch (`AppSessionTracker.firstLaunchAt`);
  - at least 14 days passed since the last ask;
  - fewer than 3 asks were made in this app version;
  - the user did not answer "Yes" before;
  - no other startup sheet used `StartupModalSlot` in this session.
- The sheet asks "Enjoying Prism?" with "Not really" and "Yes".
- "Yes" opens the store review page. iOS: `https://apps.apple.com/app/id1405860595?action=write-review`. Android: `market://details?id=com.hash.prism`, and the Play Store web page when no store app opens. After "Yes" Prism never asks again.
- "Not really" opens the Report a problem sheet.
- Closing the sheet counts as an ask and nothing else.
- Analytics: `rate_prompt_shown{trigger}`, `rate_prompt_result{result}` where result is `yes`, `not_really` or `dismissed`.

### Profile nudge

- `ProfileCompletenessNudgeService.maybeShowNudge` waits for session 3 (`AppSessionTracker`). It also takes `StartupModalSlot`, so it never shows on top of another startup sheet. When it cannot show, it keeps the "shown" flag unset and tries at the next entry.

### Copy

- Row titles use sentence case. User text says "wallpaper", not "wall". Toasts have no trailing "!". The retry text is "Try again."
- The section title colour is the theme accent (`colorScheme.error`). The old black accent workaround is gone, because the theme now never gives a black accent on a black background.

## Limits

- Export favourites is missing. The Library hub (`LibraryRoute`) did not exist when this page was written. When it lands, add a row "Export favourites" in PRIVACY AND DATA that opens it.
- "Download my data" from the server is not built. It needs a new function and a deploy.
- The Data saver switch only saves the value. The screens that read it belong to other features. The list above is the plan.
- The session count goes up only when something reads `AppSessionTracker.instance.sessionNumber`. The profile nudge and the rate prompt do this. A session in which neither runs is not counted.
- The drawer Log out dialog still shows the old text until the drawer uses `logoutConfirmMessage` and `logoutFailedMessage` from `lib/core/account/account_copy.dart`.
- Ad privacy choices, the share sheet and the store links were not run on a device.

## How to test

1. Open Settings. Make sure each row title uses sentence case and no row says "wall".
2. Turn Data saver on and close the app. Open Settings. Make sure the switch is still on.
3. Tap Clear cache. Make sure the dialog shows the size. Tap Cancel. Make sure nothing is cleared.
4. Tap Privacy policy and Terms of use. Make sure each opens in the browser.
5. In the EEA (or with the Google debug geography), make sure "Ad privacy choices" shows and opens the consent form. Elsewhere, make sure it is hidden.
6. Tap Clear learned taste. Make sure the dialog shows a count. Confirm. Go to Home. Make sure the feed refreshes.
7. Tap Report a problem. Make sure the preview has no email address. Tap Share. Make sure the share sheet shows a `.txt` file.
8. In About, turn off all mail apps, tap FEEDBACK, and make sure the Report a problem sheet opens. Turn a link off (airplane mode) and tap GITHUB. Make sure the snackbar shows the address and Copy.
9. Sign out in Settings. Make sure the dialog text matches this page and no success toast shows.
10. Sign in as a test user. Tap Delete account, then close the Google prompt. Make sure nothing else happens. Repeat and confirm. Make sure the app restarts, and Favourites and Downloads are empty after you sign in again.
11. As a guest, make sure Restore purchases shows.
12. Do 3 sets over 5 days. Make sure "Enjoying Prism?" shows once on the third set after day 5.

Automated tests:

- `test/features/session/settings_screen_test.dart`
- `test/features/session/about_screen_test.dart`
- `test/features/session/report_problem_test.dart`
- `test/features/session/low_data_mode_test.dart`
- `test/features/session/app_session_tracker_test.dart`
- `test/core/account/delete_account_service_test.dart`
- `test/core/account/local_account_data_cleaner_test.dart`
- `test/core/rating/rate_prompt_service_test.dart`
- `test/features/profile_completeness/profile_completeness_nudge_service_test.dart`

```sh
fvm flutter test --no-pub test/features/session test/core/account test/core/rating
```
