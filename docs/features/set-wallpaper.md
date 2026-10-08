# Set wallpaper

The user sets a wallpaper on the home screen, the lock screen, or both. The app shows one clear result and offers a Retry action on failure. On iOS, the app saves the image to Photos and shows a short guide.

## Where to find it

- Android: the **Set** button in the action bar of the wallpaper detail screen.
- Android: the Set button in the editor (`WallpaperFilterScreen`) and on the downloaded wallpaper screen.
- Settings: **Default action for Set** (Android only). Options: Ask every time, Home screen, Lock screen, Home and lock screens.
- iOS: **Save** in the detail action bar. The guide sheet opens after a successful save.

## Platforms

| Platform | Behavior |
|---|---|
| Android | Full set flow, set sheet, Crop and position, default Set target. |
| iOS | iOS does not let apps change the wallpaper. `hideSetWallpaperUi` hides Set UI. The user saves to Photos and finishes in Photos. |

## Free and Pro

Set is free for all users. The set path has no premium or coin gate. Download and premium filters have gates (see `docs/features/wallpaper-detail.md`).

## How it works

The set sheet has three parts:

- Target buttons: Home Screen, Lock Screen, Both. The sheet hides Lock Screen and Both when `getCapabilities()` says the device cannot set them.
- **Fit** choice: Fill screen (center crop) or Fit whole image (fit center).
- **Crop and position...** switch (Android only). It uses the system cropper. When it is on, the Fit choice is disabled.

Default target:

- When the setting is Home, Lock, or Both, a tap on Set applies at once to that target.
- A long press on Set opens the sheet. A small tune badge on the button also opens the sheet.
- If the device cannot set the saved target, the sheet opens instead.
- Ask every time is the default value.

Result mapping (`WallpaperService.mapStatus`):

| Plugin status | App status | What the user sees |
|---|---|---|
| applied | applied | Success toast "Wallpaper set successfully!" and glint toast. |
| cancelled | cancelled | Nothing. |
| previewOpened, awaitingUserConfirmation | pending | Snackbar "Confirm the wallpaper in the system preview." |
| unsupported | unsupported | Error toast "This device can't set that screen." |
| foregroundRequired | foregroundRequired | Snackbar "Keep Prism open and try again." with **Retry**. |
| failed | failed | Snackbar "Couldn't set the wallpaper." with **Retry**. |

Retry and errors:

- On a `failed` direct apply, the service tries once more with `WallpaperApplyStrategy.automatic`. It does not retry when Crop and position is on.
- A network fetch or an apply call that takes more than 30 s returns `failed` with the message "Timed out. Check your connection and try again."
- The **Retry** action runs the same choice again.
- `reportWallpaperSetResult` tracks `SetWallEvent` (success or failure) and shows one piece of feedback.

iOS save and guide:

- After a successful save, `showIosSetWallpaperGuide` opens a sheet with three steps: Open Photos, Tap Share, Tap Use as Wallpaper. It has an **Open Photos** button.
- The guide opens at most once for each app session.
- If iOS denies access to Photos (`PHOTO_PERMISSION_DENIED`), a snackbar says "Allow Prism to add photos in Settings to save wallpapers." It has an **Open Settings** action (`app-settings:`).

Editor export:

- The editor caps the long side of the export at 4096 px (`maxExportLongSide`). If the device screen long side is larger, the cap is the screen size.
- The image fetch in `EditButton` stops after 30 s.
- The editor saved toast uses `wallpaperSavedMessage` ("Saved to Photos." on iOS, "Wall downloaded in Pictures/Prism!" on Android).

| Path | Role |
|---|---|
| `lib/core/platform/wallpaper_service.dart` | `WallpaperService.setWallpaper`, typed `WallpaperSetResult`, status mapping, retry, history record. |
| `lib/core/platform/wallpaper_set_feedback.dart` | Analytics and toast or snackbar for a result. |
| `lib/core/platform/ios_wallpaper_guide.dart` | iOS guide sheet and the denied-permission snackbar. |
| `lib/core/platform/wallpaper_capability.dart` | `hideSetWallpaperUi`, `wallpaperSavedMessage`. |
| `lib/core/widgets/menu_button/set_wallpaper_button.dart` | Set button, `SetWallpaperFlow`, set sheet (`SetOptionsPanel`). |
| `lib/core/widgets/menu_button/edit_button.dart` | Editor entry with 30 s fetch timeout. |
| `lib/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart` | Export size cap. |
| `lib/features/session/views/pages/settings_screen.dart` | Default action for Set setting. |

Data path:

```text
Set button -> SetWallpaperFlow.run -> (default target or set sheet)
  -> WallpaperService.setWallpaper -> AsyncWallpaper.applyWallpaper
  -> mapStatus -> reportWallpaperSetResult (toast, Retry)
  -> on applied: WallpaperHistoryStore.record
```

## Limits

- The set sheet copy "Both sets it on your home screen and lock screen." shows on all devices that open the sheet.
- The plugin decides which apply strategies work on a given Android version. Device tests are needed to confirm Crop and position and the automatic retry.
- `showIosSetWallpaperGuide` runs after Download or Save and after an editor save. The status of the guide on a real iPhone is not confirmed by an automated test.
- The "Open Settings" action works only where the Dart code sees `PHOTO_PERMISSION_DENIED`. These places are the Download button and the editor save.
- Retry is not offered for `unsupported`.

## How to test

1. On Android, set Settings > **Default action for Set** to Ask every time. Open a wallpaper. Tap **Set**. Make sure the sheet shows Home Screen, Lock Screen, Both, Fit, and Crop and position.
2. Pick Both with Fill screen. Make sure the toast says "Wallpaper set successfully!".
3. Change Fit to Fit whole image. Set again. Make sure the whole image shows with bars.
4. Turn on Crop and position. Pick Home Screen. Make sure the system editor opens.
5. Set **Default action for Set** to Lock screen. Tap Set. Make sure the app applies at once. Long press Set. Make sure the sheet opens.
6. Turn on airplane mode. Tap Set on a new wallpaper. Make sure the error snackbar shows **Retry**.
7. On iOS, tap **Save** with Photos access allowed. Make sure the guide sheet opens once. Save again. Make sure it does not open again in the same session.
8. On iOS, deny Photos access in Settings. Tap **Save**. Make sure **Open Settings** shows.
9. Open the editor on a large image. Export. Make sure the long side is at most 4096 px (or the screen size when larger).

Automated tests:

- `test/core/platform/wallpaper_service_test.dart`
- `test/core/platform/ios_wallpaper_guide_test.dart`
- `test/core/widgets/menu_button/set_wallpaper_button_test.dart`
- `test/features/wallpaper_detail/wallpaper_edit/wallpaper_edit_pipeline_test.dart`
- `test/features/wallpaper_detail/wallpaper_edit/edit_button_lifecycle_test.dart`

Command: `fvm flutter test --no-pub test/core/platform/wallpaper_service_test.dart`
