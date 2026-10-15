# Set wallpaper

The user sets a wallpaper on the home screen, the lock screen, or both. The app shows one clear result. On failure it says what went wrong and offers **Try again** only when a second try can work. After a set, the app offers **Undo**. On iOS, the app saves the image to Photos and shows a short guide.

## Where to find it

- Android: the **Set** button in the action bar of the wallpaper detail screen.
- Android: the Set button in the editor (`WallpaperFilterScreen`), on the downloaded wallpaper screen, in Library, and in Wallpaper history (tap a tile).
- Settings: **Default action for Set** (Android only). Options: Ask every time, Home screen, Lock screen, Home and lock screens.
- iOS: **Save** in the detail action bar. The guide sheet opens after a successful save.

## Platforms

| Platform | Behavior |
|---|---|
| Android | Full set flow: set sheet, Crop and position, Position studio, Undo, different wallpaper for the lock screen, default Set target. |
| iOS | iOS does not let apps change the wallpaper. `hideSetWallpaperUi` hides Set UI. The user saves to Photos and finishes in Photos. |

## Free and Pro

Set is free for all users. The set path has no premium or coin gate. The Position studio and its Dim control are free too. Download and premium filters have gates (see `docs/features/wallpaper-detail.md`).

## How it works (Android)

### The set sheet

The sheet has these parts, from the top:

- The wallpaper thumbnail, the title "Set Wallpaper as", and warning chips. The chips are "Low resolution for your screen" and "Landscape wallpaper: the sides will be cropped". The chips show only when they apply.
- Target buttons: Home Screen, Lock Screen, Both. The sheet hides Lock Screen and Both when `getCapabilities()` says the device cannot set them.
- **Fit** choice: Fill screen (center crop) or Fit whole image (fit center).
- **Crop and position...** switch (Android only). It uses the system cropper. When it is on, the Fit choice is disabled and the next target tap opens the system editor. Prism gives the cropper a `content://` URI, not a file path (see "Crop and position" below).
- **Adjust position and preview**: opens the Position studio (see `docs/features/position-studio.md`).
- **Different wallpaper for lock screen**: shows only when the device can set both the home screen and the lock screen. See "Different wallpaper for lock screen" below.
- **Always use this**: when on, the target the user taps becomes the saved default (`PersistenceKeys.defaultApplyTarget`). The next tap on Set skips the sheet.
- The line "Both sets it on your home screen and lock screen." It shows only when Both is on the sheet.

The editor opens the same sheet without the thumbnail, the studio row, and the pair row.

### Crop and position and the Position studio

The sheet has two ways to choose the area. They are different tools:

- **Crop and position...** opens the Android system cropper. The plugin accepts the cropper only for a `content://` source. `MainActivity` has the `prism/wallpaper_crop` channel. Its `contentUri` method copies the image to the cache folder `wallpaper_crop` and returns a `FileProvider` URI (`WallpaperCropFileProvider`, authority `${applicationId}.wallpaper_crop`). `WallpaperService.setWallpaper(useSystemCropper: true)` passes that URI with the `systemCropper` strategy. It does not retry, and a missing URI is a retryable failure.
- **Adjust position and preview** opens the Position studio (Prism's own editor with pan, zoom and dim).

### Default target

- When the setting is Home, Lock, or Both, a tap on Set applies at once to that target.
- A long press on Set opens the sheet. When a default is saved, a separate 48 by 48 tune button next to the pill also opens the sheet. It never applies a wallpaper.
- If the device cannot set the saved target, the sheet opens instead.
- Ask every time is the default value.

### Result and errors

One table of plugin error codes feeds both the static and the live paths: `lib/core/platform/wallpaper_error_messages.dart` (`wallpaperErrorMessage`, `canRetryWallpaperError`).

| Plugin result | What the user sees | Try again |
|---|---|---|
| applied | Snackbar "Wallpaper set" for 8 s. It has **Undo** and sometimes **Match accent**. A Glint shows too. | n/a |
| cancelled | Nothing. | n/a |
| previewOpened, awaitingUserConfirmation | Snackbar "Confirm the wallpaper in the system preview." | n/a |
| `image-too-large` | "This image is too large for your device to set." | No |
| `wallpaper-not-allowed` (arrives as unsupported) | "Your device or work profile does not allow wallpaper changes." | No |
| `out-of-memory` | "Not enough memory. Close other apps and try again." | Yes |
| `timeout` | "Timed out. Check your connection and try again." | Yes |
| `load_failed`, other codes | "Couldn't set the wallpaper." | Yes |
| unsupported, no code | "This device can't set that screen." | No |
| foregroundRequired | "Keep Prism open and try again." | Yes |
| `partial-apply` | "Home screen set. Lock screen failed." (or the other way round) | **Retry lock screen** or **Retry home screen**. It sets only the screen that failed. |

- On a failed direct apply, the service tries once more with `WallpaperApplyStrategy.automatic`. It skips that second try for permanent codes.
- A fetch or an apply call that takes more than 30 s returns the timeout message.
- The snackbar uses the root `ScaffoldMessenger` taken before the set starts. **Try again** and **Undo** keep working after the user leaves the screen.
- A set that finishes after the user left still shows its result.
- Every set tracks `set_wall` with `wallpaper_target`, `result`, and when they apply `error_code`, `fit`, `entry_point`, and `used_default`.

### Undo

- Before it applies, `WallpaperService.setWallpaper` reads the newest history row for each screen it will change. It returns them in `WallpaperSetResult.restore`, with the ids of the new history rows in `historyIds`.
- **Undo** sets the previous wallpaper again with `recordHistory: false`, then removes the new history rows. It tracks `set_wall_undone` with the target and the result.
- Two screens with the same previous wallpaper make one `both` entry.
- There is no Undo when Prism has no earlier history for that screen, when the earlier wallpaper is the same wallpaper, or when auto-rotate is on (`PersistenceKeys.autoRotateEnabled`).
- Undo knows only the wallpapers that Prism set and recorded. It never promises to restore the system wallpaper.

### Match accent

When the detail screen has a palette, the success snackbar also shows **Match accent**. It sets Prism's accent (light or dark, to match the current theme) to the first palette colour. It tracks `accent_matched_from_wall`.

### Different wallpaper for lock screen

1. The user taps **Different wallpaper for lock screen**. The current wallpaper goes on the home screen.
2. `PairPickerSheet` opens with the tabs Favourites, Downloads, and History. The current wallpaper is not in the lists.
3. The app sets home first, then lock, as two calls. It shows one combined result.
4. History records two rows. Undo restores both screens.
5. If the home call fails, the app does not try the lock screen. **Try again** runs both calls again.
6. If only the lock call fails, the message is "Home screen set. Lock screen failed." **Retry lock screen** runs only the lock call.
7. It tracks `set_wall_pair` with `home_source` (the screen the user came from), `lock_source` (the tab), and `result` (`success`, `partial`, or `failure`). It does not also track `set_wall` for the two calls.

### Rate prompt

After a successful set from the Set button, the app calls `RatePromptService.instance.maybePrompt` with `RatePromptTrigger.wallpaperSet`. The service decides if it asks.

## iOS save and guide

- After a successful save, `showIosSetWallpaperGuide` opens a sheet with three steps: Open Photos, Tap Share, Tap Use as Wallpaper. It has an **Open Photos** button.
- The guide opens at most once for each app session.
- If iOS denies access to Photos (`PHOTO_PERMISSION_DENIED`), a snackbar says "Allow Prism to add photos in Settings to save wallpapers." It has an **Open Settings** action (`app-settings:`).

## Editor export

- The editor caps the long side of the export at 4096 px (`maxExportLongSide`). If the device screen long side is larger, the cap is the screen size.
- The image fetch in `EditButton` stops after 30 s.
- The editor saved toast uses `wallpaperSavedMessage` ("Saved to Photos." on iOS, "Wall downloaded in Pictures/Prism!" on Android).
- The editor passes `recordHistory: false`, so an edited export has no Undo and no history row.

| Path | Role |
|---|---|
| `lib/core/platform/wallpaper_service.dart` | `WallpaperService.setWallpaper`, `WallpaperSetResult`, `WallpaperRestore`, status mapping, history record. |
| `lib/core/platform/wallpaper_error_messages.dart` | One table of error messages and retry rules. |
| `lib/core/platform/wallpaper_set_feedback.dart` | Analytics, snackbar, Undo, Match accent. |
| `lib/core/platform/ios_wallpaper_guide.dart` | iOS guide sheet and the denied-permission snackbar. |
| `lib/core/platform/wallpaper_capability.dart` | `hideSetWallpaperUi`, `wallpaperSavedMessage`. |
| `lib/core/widgets/menu_button/set_wallpaper_button.dart` | Set button, `SetWallpaperFlow` (run, apply, pair). |
| `lib/core/widgets/menu_button/set_options_panel.dart` | The set sheet. |
| `lib/core/widgets/menu_button/set_wallpaper_choice.dart` | `SetWallpaperChoice`, `isWallpaperTargetSupported`. |
| `lib/core/widgets/menu_button/pair_picker_sheet.dart` | Lock screen picker. |
| `lib/core/widgets/menu_button/edit_button.dart` | Editor entry with 30 s fetch timeout. |
| `lib/features/wallpaper_position/` | Position studio. |
| `lib/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart` | Export size cap. |
| `lib/features/session/views/pages/settings_screen.dart` | Default action for Set setting. |

Data path:

```text
Set button -> SetWallpaperFlow.run -> (default target or set sheet)
  -> apply | studio | pair
  -> WallpaperService.setWallpaper -> AsyncWallpaper.applyWallpaper
  -> mapStatus -> reportWallpaperSetResult (snackbar: Try again, Undo, Match accent)
  -> on applied: WallpaperHistoryStore.record
```

## Limits

- The plugin decides which apply strategies work on a given Android version. Device tests are needed to confirm the automatic retry.
- Some phone makers may reset the other screen when one screen changes. This is not confirmed on a device, so the pair flow is not proven there.
- `showIosSetWallpaperGuide` runs after Download or Save and after an editor save. The status of the guide on a real iPhone is not confirmed by an automated test.
- The "Open Settings" action works only where the Dart code sees `PHOTO_PERMISSION_DENIED`. These places are the Download button and the editor save.
- Undo needs history, and history clears on sign out. Quick tiles, auto-rotate, and live wallpapers do not write history, so the "previous" wallpaper can be out of date.
- **Match accent** changes only Prism's own colours. Android 12 and later already recolours the system.
- `recordWallpaperAction` needs the deployed backend and a signed-in user. The set count is best effort.

## How to test

1. On Android, set Settings > **Default action for Set** to Ask every time. Open a wallpaper. Tap **Set**. Make sure the sheet shows the thumbnail, Home Screen, Lock Screen, Both, Fit, Crop and position, Adjust position and preview, Different wallpaper for lock screen, and Always use this.
2. Pick Both with Fill screen. Make sure the snackbar says "Wallpaper set" and has **Undo**.
3. Set another wallpaper to Home. Tap **Undo**. Make sure the home screen shows the earlier wallpaper again and the history list lost the new row.
4. Change Fit to Fit whole image. Set again. Make sure the whole image shows with bars.
4a. Turn on Crop and position. Pick Home Screen. Make sure the system editor opens with the wallpaper. Confirm the crop. Make sure the home screen shows the chosen area.
5. Tick **Always use this** and pick Lock Screen. Tap Set on another wallpaper. Make sure it applies at once to the lock screen. Make sure the tune button shows next to Set.
6. Tap the tune button. Make sure the sheet opens and nothing is set. Long press Set. Make sure the sheet opens.
7. Turn on airplane mode. Tap Set on a new wallpaper. Make sure the snackbar says "Timed out. Check your connection and try again." and shows **Try again**. Press Back. Turn off airplane mode. Tap **Try again**. Make sure the wallpaper is set.
8. Open a wide wallpaper (width greater than height). Make sure the sheet shows the landscape chip.
9. Tap **Different wallpaper for lock screen**. Pick a favourite. Make sure the home screen and the lock screen show different wallpapers and the history list has two new rows.
10. Turn on auto-rotate. Set a wallpaper. Make sure the snackbar has no **Undo**.
11. On iOS, tap **Save** with Photos access allowed. Make sure the guide sheet opens once. Save again. Make sure it does not open again in the same session.
12. On iOS, deny Photos access in Settings. Tap **Save**. Make sure **Open Settings** shows.
13. Open the editor on a large image. Export. Make sure the long side is at most 4096 px (or the screen size when larger).

Automated tests:

- `test/core/platform/wallpaper_service_test.dart`
- `test/core/platform/wallpaper_error_messages_test.dart`
- `test/core/platform/wallpaper_set_feedback_test.dart`
- `test/core/platform/ios_wallpaper_guide_test.dart`
- `test/core/widgets/menu_button/set_wallpaper_button_test.dart`
- `test/core/widgets/menu_button/pair_picker_sheet_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_set_flow_test.dart`
- `test/features/wallpaper_detail/wallpaper_edit/wallpaper_edit_pipeline_test.dart`
- `test/features/wallpaper_detail/wallpaper_edit/edit_button_lifecycle_test.dart`

Command: `fvm flutter test --no-pub test/core/platform test/core/widgets/menu_button`
