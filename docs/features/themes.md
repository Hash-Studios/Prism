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
- `withPrismAccent` sets `onPrimary` and `onError` with `onColor(accent)`. Text on the accent is black or white, whichever has more contrast. The check is at least 4.5:1 for all 12 themes and all 22 picker colours.
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
- The top bar wordmark, caret, logo and bell use `onColor(primaryColor)` and `onSurface`. They read on all 12 themes.
- The bottom bar marks the active tab as selected for screen readers. The inactive icons use `onColor(primaryColor)` at 70%.
- The offline banner uses `errorContainer` and `onErrorContainer`. The text is 12 sp. The banner is a live region only while it shows. When the connection returns, it reads "Back online" for 2 seconds.
- Plain `Text` on a light theme is white by default (`textTheme.bodyMedium`). The not found page, the startup failure screen, the update screen and the profile nudge sheet now set their own text style and background.
- Toasts use darker green and red, so white text has at least 4.5:1. `toasts.info(msg)` shows a neutral toast. A new toast cancels the one on screen.
- The sign in, more links and changelog pop ups use `FilledButton` with `onColor(accent)`. They use sentence case labels. A cancelled sign in shows no toast.

## Limits

- Prism reads the system colour only when the Themes page opens. If the system wallpaper changes while the switch is on, the app shows the new colour after the user opens the page again.
- The Kotlin channel was not compiled or run on a device. CI compiles it.
- The 1.5 limit lets low contrast accents through. An accent can be hard to see on a theme and still pass. The text on the accent always passes.
- The migration for the black AMOLED accent runs when the app reads the theme. It was tested with an in-memory store, not on a device.
- The switch needs a device with Material You colours. Some Android 12 builds from other makers return the same colour for every wallpaper.

## How to test

1. Use an Android 12 or newer phone. Open Settings, then "Themes". Make sure the title reads "Themes" and there is no BETA badge.
2. Make sure the "Match system colour" switch shows. On iOS or Android 11, make sure it does not show.
3. Turn the switch on. Make sure the accent circle changes to a colour from the system wallpaper.
4. Change the system wallpaper. Open the page again. Make sure the accent follows.
5. Pick an accent colour by hand. Make sure the switch turns off and the colour stays.
6. Turn the switch off and on again. Make sure the accent returns to the system colour.
7. Choose the AMOLED dark theme. Make sure the active tab in the bottom bar shows a white circle with a black icon.
8. Choose Frost White as the light theme. Open Home. Make sure the "prism" wordmark, the arrow, the logo and the bell are dark and easy to read.
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

```sh
fvm flutter test --no-pub test/features/theme_mode/theme_view_page_test.dart
```
