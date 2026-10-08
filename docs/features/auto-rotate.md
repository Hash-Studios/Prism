# Auto-rotate

Auto-rotate changes the wallpaper on a schedule. The user picks a source (Favourites or Downloads), how often to change, and where to apply it.

## Where to find it

- Settings, section PERSONALISE, row "Auto-rotate wallpapers". Code: `lib/features/session/views/pages/settings_screen.dart`.
- Route `AutoRotateRoute`. Screen: `lib/features/auto_rotate/views/pages/auto_rotate_screen.dart`.

## Platforms

| Platform | Status |
|---|---|
| Android | Supported. The plugin runs the schedule with WorkManager. |
| iOS | Not available. The Settings row shows on Android only. The screen shows "Auto-rotate is only available on Android." |

## Free and Pro

Auto-rotate is a Prism Pro feature.

- A free user who taps the Settings row sees the paywall (`PaywallPlacement.autoRotate`, source `settings_auto_rotate`).
- A free user who opens the screen sees "Auto-rotate is a Prism Pro feature." and the button "See Prism Pro".
- If the user is signed out, the button asks them to sign in first.
- If a user loses Pro, the bloc stops the rotation.

## How it works

| Path | Role |
|---|---|
| `lib/features/auto_rotate/views/pages/auto_rotate_screen.dart` | Controls, progress row, battery tip, error states. |
| `lib/features/auto_rotate/views/widgets/auto_rotate_session_listener.dart` | Sends session and favourites changes to the bloc. |
| `lib/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart` | Start, stop, debounce, status polling. |
| `lib/features/auto_rotate/domain/entities/auto_rotate_config.dart` | Settings and status models. |
| `lib/features/auto_rotate/data/repositories/auto_rotate_repository_impl.dart` | Saves settings. Calls the `async_wallpaper` plugin. Lists downloads. |

Data path:

```text
Screen or session listener -> AutoRotateBloc
  -> AutoRotateRepositoryImpl -> AsyncWallpaper.startWallpaperRotation
  -> status poll -> progress row and "Next change" text
```

### Settings

| Setting | Options | Default |
|---|---|---|
| Source | Favourites, Downloads | Favourites |
| Change | Every hour (60 min), Every 6 hours, Every 12 hours, Every day | Every day (1440 min) |
| Apply to | Home screen, Lock screen, Both | Home screen |
| Shuffle | On or off | On |
| Only while charging | On or off | Off |

- Downloads come from the Pigeon call `PrismMediaHostApi().listDownloads()`. Prism keeps only files that still exist.
- Favourites must be `https` URLs. The plugin loads them as URL sources. Downloads load as file sources.
- Rotation needs at least 2 wallpapers (`AutoRotateBloc.minWallpapers`). With fewer, the switch is off and a hint shows with a button: "Open favourites" or "Open downloads".

### Triggers

`AutoRotateRepositoryImpl.triggersFor` picks the plugin triggers.

| Settings | Plugin triggers |
|---|---|
| Neither option on | `interval` |
| Only while charging | `charging` |

With "Only while charging", the plugin runs periodic work that needs a charging device, so wallpapers change every interval while the device charges.

Prism has no active hours option. Plugin 3.3.0 `timeOfDay` sets one daily alarm at the start hour (`WallpaperRotationScheduler.scheduleTimeOfDay`). It does not limit interval rotation to a window, so Prism does not use it.

### Starting state and progress row

- While the bloc starts the rotation, the switch shows on and the card shows "Preparing N wallpapers" with a progress bar.
- After the start, the plugin reports `cachedCount` of `totalCount`. The card shows "Downloaded X of Y wallpapers" until all are ready.
- The bloc polls the status every 3 seconds, up to 40 times, while caching is not done.
- The status card shows "Off", "Starting", "Scheduled", or "Next change around <time>". When all wallpapers are ready, it also shows "X of Y wallpapers ready".

### Using your first 100

The plugin accepts at most 100 sources (`_maxRotationSources` in `async_wallpaper` `lib/async_wallpaper.dart`). The bloc drops the extra ones. The switch text then ends with "Using your first 100."

### Battery tip

After the user turns on rotation for the first time, a card "KEEP IT RUNNING" shows once. It says: "If wallpapers stop changing, set battery use for Prism to Unrestricted. Open Settings, then Apps, Prism, Battery." The only button is "Got it". The card has no button that opens the app settings.

### Change now

The "Change now" button calls `AsyncWallpaper.rotateWallpaperNow()`. It is off when rotation is off. If the plugin fails, the screen shows "Could not change wallpaper." with the same button.

### Debounce and restarts

- The bloc waits 2 seconds after a favourites change before it acts (`favouritesDebounce`).
- If the list of sources did not change and rotation runs, the bloc does nothing.
- The bloc skips the stop call when rotation is already off.

## Limits

- Prism stores the source list that it last started the plugin with (`autoRotate.appliedSources`). It restarts rotation when the list differs.
- The plugin caps the playlist at 100 wallpapers.
- Two problems remain in the separate `async_wallpaper` plugin. They are not fixed in this repo and need a plugin release:
  - PERS-1: apply on restart.
  - PERS-2: the rotation timer after a device reboot.
- Charging rotation changes at most once per interval while the device charges (plugin 3.3.0 changelog).
- The battery tip is text only.
- Prism did not run this feature on a device for this page. Timer and charging need a device and time to confirm.

## How to test

1. Use an Android phone. Sign in as a Pro user. Favourite at least 3 wallpapers.
2. Open Settings, then "Auto-rotate wallpapers".
3. Turn on the main switch. Make sure "Preparing N wallpapers" shows, then "Downloaded X of Y wallpapers".
4. Make sure the battery tip card shows. Tap "Got it". Turn rotation off and on. Make sure the card does not show again.
5. Tap "Change now". Make sure the wallpaper changes.
6. Select Source "Downloads". Make sure the subtitle reads "N downloads in the mix".
7. Turn on "Only while charging". Make sure rotation restarts.
8. Remove favourites until 1 is left. Select Favourites. Make sure the switch is off and the hint "Favourite at least 2 wallpapers to rotate them." shows.
9. Sign in as a free user. Open the screen. Make sure "Auto-rotate is a Prism Pro feature." shows.
10. Favourite or remove one wallpaper. Wait 2 seconds. Make sure rotation restarts only if the list changed.

Automated tests:

- `test/features/auto_rotate/auto_rotate_bloc_test.dart`
- `test/features/auto_rotate/auto_rotate_bloc_options_test.dart`
- `test/features/auto_rotate/auto_rotate_repository_test.dart`
- `test/features/auto_rotate/auto_rotate_screen_test.dart`
- `test/features/auto_rotate/auto_rotate_session_test.dart`
- `test/features/session/settings_screen_test.dart`

Command:

```sh
fvm flutter test --no-pub test/features/auto_rotate
```
