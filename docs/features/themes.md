# Themes

The Themes page lets the user choose the app theme mode (system, light or dark), a light theme, a dark theme, and an accent colour for each.

## Where to find it

- Settings, row "Themes" (route `ThemeViewRoute`). Code: `lib/features/theme_mode/views/pages/theme_view_page.dart`.
- The page title is "Themes". The earlier title "Theme Manager" and the BETA badge are gone.
- The check button in the top bar closes the page. Its tooltip reads "Done". Theme and accent taps apply at once, so there is nothing to apply.

## Platforms and plans

| Platform | Status |
|---|---|
| Themes, accents | Android and iOS, free |
| Match system colour | Android 12 (API 31) and newer. The switch is hidden elsewhere. |

## How it works

### Match system colour

- A switch named "Match system colour" shows under the theme chips. The subtitle reads "Use the accent colour of your phone".
- The Dart side asks the native side through the channel `prism/system_colors`, method `accent`. Code: `lib/core/platform/system_accent_channel.dart`.
- Android returns two colours: `android.R.color.system_accent1_600` for light and `system_accent1_200` for dark. Below Android 12 it returns null. iOS never calls it.
- When the user turns the switch on, Prism saves `true` under the settings key `theme.system_accent`. It then sends `ThemeEvent.lightAccentChanged` and `ThemeEvent.darkAccentChanged` with the two colours.
- When the user turns the switch off, Prism saves `false`. It does not change the stored accents.
- When the user picks an accent colour by hand, Prism turns the switch off.
- When the page opens with the switch on, Prism reads the colours again and sends the events only if they differ from the stored accents. This follows a wallpaper change in the system.
- The normal contrast guard (`withPrismAccent`) still applies. An accent that is too close to the theme background is replaced.

### Accent and contrast

- The user accent goes through `withPrismAccent` in `lib/features/theme_mode/views/theme_mode_bloc_utils.dart`. Every screen reads the result from `Theme.of(context).colorScheme`.
- `withPrismAccent` sets `onPrimary` and `onError` with `onColor(accent)`. Text on the accent is black or white, whichever has more contrast. The check is at least 4.5:1 for all themes and all 22 picker colours.
- If the accent is almost the same as the theme background, the contrast ratio is below 1.5. Prism then uses the accent of the theme itself. This only catches colours such as black on black.
- The limit is 1.5 and not 3. Four stock dark themes (Pepper, Steel, Sky, Jungle) use accents below 3:1 against their own background. The limit must keep them.
- `onColor` and `contrastRatio(a, b)` are in `lib/theme/contrast.dart`. The old import `features/wallpaper_detail/views/widgets/accent_contrast.dart` still works. It re-exports the new file.
- Do not use `PrismColors.onPrimary` (white) on `primaryColor`. In Frost White `primaryColor` is white. Use `onColor(primaryColor)`.

### AMOLED

- The default accent of the AMOLED theme is white. It was black, which is invisible on the black AMOLED background.
- Older builds stored `0xff000000` as the dark accent. The theme repository reads this value on AMOLED as "no custom accent". It returns white and writes white back once. Code: `ThemeRepositoryImpl._readDarkAccent`.
- When the user then changes the dark theme, the old black value does not carry over to the new theme.
- A custom accent on AMOLED is never changed.

### First frame

- `ThemeRepository.readSync()` reads the stored selection without waiting. `ThemeBloc` uses it in its constructor, so the first frame already has the stored theme and accent. The `started` event still reloads the selection.

### Text on the theme background

- Caption and eyebrow text (`PrismTextStyles.caption`, `eyebrow`) use 72% of `onSurface`. At 55% Rose and Cotton Blue were below 4.5:1.
- The top bar wordmark, logo and bell use `onSurface`. They read on all 12 themes.
- The bottom bar marks the active tab as selected for screen readers. The active icon uses `secondary`, on a circle of `secondary` at 15% over `primaryColor`. The inactive icons use `secondary` at 60%.
- The offline banner uses `errorContainer` and `onErrorContainer`. The text is 12 sp. The banner is a live region only while it shows. When the connection returns, it reads "Back online" for 2 seconds.
- Plain `Text` on a light theme is white by default (`textTheme.bodyMedium`). The not found page, the startup failure screen, the update screen and the profile nudge sheet now set their own text style and background.
- Toasts use darker green and red, so white text has at least 4.5:1. `toasts.info(msg)` shows a neutral toast. A new toast cancels the one on screen.
- The sign in, more links and changelog pop ups use `FilledButton` with `onColor(accent)`. They use sentence case labels. A cancelled sign in shows no toast.

### Seasonal themes

- The registry is `lib/features/theme_mode/seasonal_themes.dart`. Each `SeasonalTheme` has a dark theme, an optional light theme, a `window` (the season) and a `promo` window (the home card and the announcement). Each window is local wall-clock time, start inclusive, end exclusive.
- The seasons read `seasonNow()`. Tests set `seasonClock`. `test/flutter_test_config.dart` pins it to 1 February 2027, after every season.
- Seasonal themes are free. They have no `shopItemId`.

| Season | Theme ids | Window | Home card and announcement | At the end |
|---|---|---|---|---|
| Winter | `kLWinter`, `kDWinter` | 1 Dec 2026 to 6 Jan 2027 | 2 Dec 2026 to 6 Jan 2027 | The user goes back to the previous theme |
| Diwali | `kDDiwali` | to 11 Nov 2026 | same | The theme stays |
| Spooky | `kDSpooky` | to 2 Nov 2026 | same | The theme stays |

### Winter

- Light: background `#E8F0F7`, accent `#265D92`. Dark: background `#0A1521`, accent `#8CC4EE`, text `#E3EDF7`. Body text contrast is 17.3:1 (light) and 15.5:1 (dark).
- The user accent applies, as on every other theme with `usesAccent`. For Winter only, Prism adjusts a user accent until it reaches at least 4.5:1 against all Winter surfaces. `test/theme/winter_contrast_test.dart` checks all 22 picker colours on both variants. Other themes keep the existing 1.5:1 fallback when the accent is too close to the background.
- The home card shows from 2 December. Wrapped launches on 1 December with its own card and push, so Winter waits one day. In the carousel the Wrapped card always comes first. Where 2 or more cards show side by side (tablets), the Winter card moves to the end of the carousel. The guard includes partial cards visible during a swipe; with the current page order, Winter is hidden whenever Wrapped shows in a layout of 2 or more columns.
- A tap on the card selects the variant for the current brightness: Winter light in light mode, Winter dark in dark mode.
- An app update before 2 December keeps the Winter announcement pending. The first launch on or after 2 December writes the inbox item and shows the local push. The push payload is `{"route": "/theme", "seasonal_announcement": "winter"}`.

### Snow on Home

- `WinterSnowfall` in `lib/features/theme_mode/views/widgets/winter_decor.dart` wraps the Home feed. It shows only while a Winter variant is the active theme.
- It draws 18 small flakes over the header. The flakes fade out 96 dp below the header, so they do not cover the walls.
- It ignores taps and is not in the semantics tree.
- It stops while the feed scrolls vertically, while the Home tab is hidden, with Reduce Motion, and with Low Power Mode (iOS) or battery saver (Android). The power state comes from the `prism/power` channel, method `lowPowerMode`. Prism reads it when Home opens and when the app comes back to the front.
- From 31 December to 1 January, every third flake is a gold spark. A small "Happy New Year" pill shows below the header for 6 seconds each time Home opens.

### End of a season

- When the user selects a Winter variant, Prism saves the theme they had before in that variant's `winterThemePrevious2026Light` or `winterThemePrevious2026Dark` slot. Account sync also records these previous-theme slots.
- On the first theme load after 6 January (`ThemeRepository.load`), a user still on Winter goes back to that variant's saved theme. With no saved theme, they go to the default theme (Frost White or Material Dark). The accent follows the normal theme change rule: a default accent becomes the default of the new theme, a custom accent stays.
- `readSync` already shows the reverted theme on the first frame.
- Only a Winter choice made before the end reverts. Prism reads the last theme change time (`theme.changed_at`). A user who picks Winter after 6 January keeps it.
- `ThemeBloc` sets a timer for the end of the season, so the revert also happens while the app is open. `ThemeRepository.update` restores both selected Winter slots before applying a manually requested theme pick.
- The revert is local. It keeps the change time and uploads nothing, so a newer choice in the account still wins the next sync. If the account still holds the old Winter choice, each device reverts it again after the sync.

### Analytics

| Event | When |
|---|---|
| `seasonal_theme_applied` (`season`, `source`: `home_card`, `themes_page`) | The user selects a seasonal theme |
| `seasonal_announcement_opened` (`season`, `surface`: `home_card`, `push`, `inbox`) | The user opens the home card, the push or the inbox item |
| `seasonal_decor_disabled` (`season`, `reason`: `reduced_motion`) | Winter is active but Reduce Motion stops the snow. Once a session |

### Test clock on a device

Debug and profile builds read `PRISM_SEASON_DATE` as the season clock. The value is a local time written as `yyyyMMddHHmm`. Time still runs from that point. Release builds ignore it. It is an int define, so it is not a Doppler key. Example for 31 December 2026, 20:00:

```sh
make run RUN_ARGS="--dart-define=PRISM_SEASON_DATE=202612312000"
```

Do not change the system clock on a shared device.

## Limits

- Prism reads the system colour only when the Themes page opens. If the system wallpaper changes while the switch is on, the app shows the new colour after the user opens the page again.
- The Kotlin channel was not compiled or run on a device. CI compiles it.
- Outside Winter, the 1.5 limit lets low contrast accents through. An accent can be hard to see on a theme and still pass. The text on the accent always passes.
- The migration for the black AMOLED accent runs when the app reads the theme. It was tested with an in-memory store, not on a device.
- The switch needs a device with Material You colours. Some Android 12 builds from other makers return the same colour for every wallpaper.
- The power state is read only when Home opens and when the app comes back to the front. If the user turns on battery saver while Home is open, the snow stops at the next resume.

## How to test

1. Use an Android 12 or newer phone. Open Settings, then "Themes". Make sure the title reads "Themes" and there is no BETA badge.
2. Make sure the "Match system colour" switch shows. On iOS or Android 11, make sure it does not show.
3. Turn the switch on. Make sure the accent circle changes to a colour from the system wallpaper.
4. Change the system wallpaper. Open the page again. Make sure the accent follows.
5. Pick an accent colour by hand. Make sure the switch turns off and the colour stays.
6. Turn the switch off and on again. Make sure the accent returns to the system colour.
7. Choose the AMOLED dark theme. Make sure the active tab in the bottom bar shows a dark grey circle with a light icon.
8. Choose Frost White as the light theme. Open Home. Make sure the "prism" wordmark, the logo and the bell are dark and easy to read.
9. Turn on airplane mode in the app for a few seconds. Make sure a red tinted banner shows "No internet connection". Turn it off. Make sure the banner reads "Back online" and leaves after 2 seconds.

Automated tests:

- `test/features/theme_mode/theme_view_page_test.dart`
- `test/features/theme_mode/prism_theme_contrast_test.dart`
- `test/features/theme_mode/data/repositories/theme_repository_impl_test.dart`
- `test/features/theme_mode/biz/bloc/theme_bloc_test.dart`
- `test/theme/default_text_contrast_test.dart`
- `test/features/navigation/prism_top_app_bar_test.dart`
- `test/features/navigation/prism_bottom_nav_test.dart`
- `test/features/navigation/offline_banner_test.dart`

- `test/features/theme_mode/winter_season_test.dart`
- `test/theme/winter_contrast_test.dart`
- `test/features/theme_mode/winter_decor_test.dart`
- `test/features/personalized_feed/views/feed_carousel_test.dart`

```sh
fvm flutter test --no-pub test/features/theme_mode/theme_view_page_test.dart
```
