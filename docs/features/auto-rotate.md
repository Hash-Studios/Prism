# Auto-rotate

Auto-rotate changes the wallpaper on a schedule. The user picks a source, how often to change, and where to apply it. The sources are Favourites, Downloads, a Category, the Wall of the Day archive, and History.

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
- If a user loses Pro, the bloc stops the rotation. This happens when the app starts, not only when the screen opens. `AutoRotateSessionListener` sends the session to the bloc as soon as it loads. When the rotation was on, the bloc sets `proLapsed` and the listener shows one toast: "Auto-rotate is off because your Prism Pro plan ended." Signing out or switching account does not show the toast.

## How it works

| Path | Role |
|---|---|
| `lib/features/auto_rotate/views/pages/auto_rotate_screen.dart` | Controls, progress row, battery tip, error states. |
| `lib/features/auto_rotate/views/widgets/auto_rotate_session_listener.dart` | Sends session and favourites changes to the bloc. |
| `lib/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart` | Start, stop, debounce, status polling. |
| `lib/features/auto_rotate/domain/entities/auto_rotate_config.dart` | Settings and status models. |
| `lib/features/auto_rotate/data/repositories/auto_rotate_repository_impl.dart` | Saves settings. Calls the `async_wallpaper` plugin. Lists downloads. Loads the URLs of the Category, Wall of the Day and History sources. Reads the targets the device supports. |

Data path:

```text
Screen or session listener -> AutoRotateBloc
  -> AutoRotateRepositoryImpl -> AsyncWallpaper.startWallpaperRotation
  -> status poll -> progress row and "Next change" text
```

### Settings

| Setting | Options | Default |
|---|---|---|
| Source | Favourites, Downloads, Category, Wall of the Day, History | Favourites |
| Category | The 18 classifier names (Nature, Architecture, Cars, Anime, Space, Ocean, Flowers, Neon, Dark, Abstract, 3D Render, Minimal, Gradient, AI Art, Cyberpunk, Vintage, Landscape, Galaxy) | Nature |
| Change | Every 15 min (battery heavy), 30 min, hour, 3 hours, 6 hours, 12 hours, day, 3 days, week (15, 30, 60, 180, 360, 720, 1440, 4320, 10080 min) | Every day (1440 min) |
| Apply to | Home screen, Lock screen, Both. The screen lists only the targets the device supports (`isWallpaperTargetSupported`). | Home screen |
| Shuffle | On or off | On |
| Only while charging | On or off | Off |

- Downloads come from the Pigeon call `PrismMediaHostApi().listDownloads()`. Prism keeps only files that still exist.
- Favourites must be `https` URLs. The plugin loads them as URL sources. Downloads load as file sources.
- `loadConfig` accepts every interval in `AutoRotateConfig.intervalOptions`. Any other saved value falls back to Every day.
- Rotation needs at least 2 wallpapers (`AutoRotateBloc.minWallpapers`). With fewer, the switch is off and a hint shows with a button: "Open favourites" or "Open downloads".

### Sources

| Source | Where the list comes from | Order |
|---|---|---|
| Favourites | The favourites bloc. | As the bloc gives it. |
| Downloads | `PrismMediaHostApi().listDownloads()`. | As the host gives it. |
| Category | `PrismWallpaperRepository.fetchByCategory(name, limit: 40)`. Reviewed Prism wallpapers of that category. Blocked creators are hidden. | Newest first (the query order). |
| Wall of the Day | `WallOfTheDayRepository.fetchRecent()`. The last 30 daily picks that still exist. | Newest first. |
| History | `WallpaperHistoryStore.items()`. Unique `https` URLs only. | Sorted by URL. |

- The Category chip opens a picker sheet. A pick sets the source to Category and saves the name (`autoRotate.category`).
- The lists have a stable order for the same data. This matters because the bloc restarts the rotation when the list differs from the one the plugin started with. History is sorted by URL, because its own order changes with each wallpaper that Prism sets.
- The bloc loads the Category, Wall of the Day and History lists when the screen opens, when the user picks a source, and when the session loads and rotation has stopped. It does not fetch them on every app resume.
- If a list cannot load when the user picks it, the old source and the running rotation stay as they are. The card shows "Could not load wallpapers. Check your connection." with "Try again".
- If a list cannot load when the screen opens and the rotation still runs, the bloc leaves it running with the playlist the plugin has.
- Pro users only. A free user does not load these lists.

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

After the user turns on rotation for the first time, a card "KEEP IT RUNNING" shows once. It says: "If wallpapers stop changing, set battery use for Prism to Unrestricted. Open settings, then Apps, Prism, Battery." The card has two buttons. "Copy steps" copies the steps to the clipboard and shows "Steps copied." "Got it" closes the card. The card has no button that opens the app settings. That needs a Pigeon method.

### Change now

The "Change now" button calls `AsyncWallpaper.rotateWallpaperNow()`. It is off when rotation is off. If the plugin fails, the screen shows "Could not change wallpaper." with the same button. Each press sends the analytics event `auto_rotate_run_result` with `result` set to `success` or `failure`. This is the only rotation run that the Dart side sees. The scheduled runs happen in the plugin worker, so Dart has no event for them.

### Error states

| State | Text | Button | What the button does |
|---|---|---|---|
| The plugin could not stop | "Could not stop wallpaper rotation." | Try again | Tries to stop again. |
| The plugin could not change the wallpaper | "Could not change wallpaper." | Change now | Rotates once. |
| The plugin reports an error | "Could not update auto-rotate." | Turn off | Turns rotation off. |
| Start failed | "Could not start wallpaper rotation." | Try again | Tries to start again. |

### Analytics

- `auto_rotate_enabled` has the fields `interval_minutes`, `target`, `shuffle`, `wallpaper_count`, `source` and `category`. `category` is set only for the Category source.
- `auto_rotate_disabled` has no fields.
- `auto_rotate_run_result` has the field `result`.

### Debounce and restarts

- The bloc waits 2 seconds after a favourites change before it acts (`favouritesDebounce`).
- If the list of sources did not change and rotation runs, the bloc does nothing.
- The bloc skips the stop call when rotation is already off.

## Limits

- Prism stores the source list that it last started the plugin with (`autoRotate.appliedSources`). It restarts rotation when the list differs.
- A Category, Wall of the Day or History playlist is a snapshot. It refreshes when the user opens the screen, not in the background. New wallpapers in a category reach the rotation after the next visit.
- The plugin downloads every source at full size. Keep lists short. The Category source uses 40 wallpapers and Wall of the Day uses 30.
- The plugin caps the playlist at 100 wallpapers.
- Two problems remain in the separate `async_wallpaper` plugin. They are not fixed in this repo and need a plugin release:
  - PERS-1: apply on restart.
  - PERS-2: the rotation timer after a device reboot.
- Charging rotation changes at most once per interval while the device charges (plugin 3.3.0 changelog).
- The battery tip does not open the app settings. It only copies the steps.
- Prism did not run this feature on a device for this page. Timer and charging need a device and time to confirm.

## How to test

1. Use an Android phone. Sign in as a Pro user. Favourite at least 3 wallpapers.
2. Open Settings, then "Auto-rotate wallpapers".
3. Turn on the main switch. Make sure "Preparing N wallpapers" shows, then "Downloaded X of Y wallpapers".
4. Make sure the battery tip card shows. Tap "Got it". Turn rotation off and on. Make sure the card does not show again.
5. Tap "Change now". Make sure the wallpaper changes.
6. Select Source "Downloads". Make sure the subtitle reads "N downloads in the mix".
6a. Select Source "Category". Pick "Space" in the sheet. Make sure the chip reads "Category: Space" and the subtitle reads "N Space wallpapers in the mix". Turn rotation on and make sure it starts.
6b. Select "Wall of the Day", then "History". Make sure the counts change. Close and open the screen. Make sure rotation does not restart when the lists are the same.
6c. Pick "Every 15 min (battery heavy)" and "Every week". Make sure rotation restarts with each one.
6d. Turn on airplane mode. Pick another category. Make sure "Could not load wallpapers. Check your connection." shows and the old rotation keeps running.
6e. On a device without lock screen support, make sure "Lock screen" and "Both" do not show under APPLY TO.
6f. Cancel Prism Pro in the store, restart the app, and wait for the session to load. Make sure rotation stops and the toast "Auto-rotate is off because your Prism Pro plan ended." shows once.
7. Turn on "Only while charging". Make sure rotation restarts.
8. Remove favourites until 1 is left. Select Favourites. Make sure the switch is off and the hint "Favourite at least 2 wallpapers to rotate them." shows.
9. Sign in as a free user. Open the screen. Make sure "Auto-rotate is a Prism Pro feature." shows.
10. Favourite or remove one wallpaper. Wait 2 seconds. Make sure rotation restarts only if the list changed.

Automated tests:

- `test/features/auto_rotate/auto_rotate_bloc_test.dart`
- `test/features/auto_rotate/auto_rotate_bloc_options_test.dart`
- `test/features/auto_rotate/auto_rotate_bloc_sources_test.dart`
- `test/features/auto_rotate/auto_rotate_repository_test.dart`
- `test/features/auto_rotate/auto_rotate_screen_test.dart`
- `test/features/auto_rotate/auto_rotate_screen_sources_test.dart`
- `test/features/auto_rotate/auto_rotate_session_test.dart`
- `test/features/session/settings_screen_test.dart`

Command:

```sh
fvm flutter test --no-pub test/features/auto_rotate
```
