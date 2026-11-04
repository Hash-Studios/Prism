# Auto-rotate

Auto-rotate changes the wallpaper on a schedule. The user picks a source, how often to change, and where to apply it. The sources are Favourites, Downloads, a Category, the Wall of the Day archive, and History. Day and night is a separate mode with two walls. See [Day and night](#day-and-night).

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

## Folder source

Folder is an Android only source. The user can rotate the walls of one of their own private folders.

- In the Source row, tap the chip "Folder". The sheet "Pick a folder" opens. Each row shows the cover, the name and the wall count. Pick a folder. The chip then reads "Folder: <name>".
- On the folder page, open the menu and tap "Rotate this folder". This item shows on Android only. Auto-rotate opens with the offer card "Rotate <name>?". Tap "Rotate this folder" on the card. Prism picks the folder and turns on auto-rotate. Tap "Not now" to close the card.
- Pro or the 7-day coin pass is still required. This is the same rule as the other sources.
- The folder page shows a "Rotating" tag when auto-rotate uses the folder.

### Safety

- The folder list goes through the same rules as every other source. `_safeWallSources` runs first. Then `_safeSources` runs in `start`.
- Only local files, Wallhaven URLs and Pexels URLs go to the native rotation.
- A Prism original goes to the rotation only if the user downloaded it.
- Prism uses up to 100 of the newest walls.

### Freshness

- Prism loads the folder again when the screen opens. It also loads the folder on app start or resume. Checks on app start or resume run at most once in 15 minutes.
- Prism loads the folder 2 seconds after the folder changes in the app. A change is an add, a remove, a rename or a delete.
- Prism restarts the native rotation only when the list differs from `autoRotate.appliedSources`, the list that the platform runs. The same list never restarts it.

### Stop

- If the folder is deleted, or it has fewer than 2 usable walls, Prism turns auto-rotate off. It shows one toast:
  - "Auto-rotate is off because the folder <name> was deleted."
  - "Auto-rotate is off because the folder <name> has fewer than 2 wallpapers."
- A deleted folder also resets the source to Favourites.
- The interval, target, shuffle and charging-only settings stay.
- If the folder fails to load, the running rotation keeps running.

### Saved config

- New keys: `autoRotate.folderId` and `autoRotate.folderName`.
- Old configs load with no folder.
- A saved source `folder` with no folder id loads as Favourites.

### Analytics

- `auto_rotate_folder_set` has the field `item_count_bucket`.
- `auto_rotate_folder_tapped` has the field `item_count_bucket`.
- `auto_rotate_stopped` has the field `reason`. The value is `folderDeleted` or `folderEmpty`.
- The buckets are 0, 1, 2-5, 6-20, 21-50 and 51+.

### Limits of the folder source

- Own folders only. Followed public folders are not a source yet. They come with public folders (PR #734).

## Day and night

Day and night is a mode of auto-rotate. The user picks a day wall and a night wall. The wallpaper changes to the day wall at the day start time and to the night wall at the night start time.

### Platforms

| Platform | Status |
|---|---|
| iOS 16 or later | Supported through Shortcuts. Prism prepares both walls. Two Shortcuts automations set the wallpaper. |
| Android | Not available. The `async_wallpaper` plugin cannot change the wallpaper at two times of day. All entry points are hidden on Android. See "Android: what the plugin needs" below. |

`dayNightSupported()` in `lib/features/day_night/day_night_support.dart` decides this. It is true only on iOS 16 or later.

### Where to find it

- Settings, section PERSONALISE, row "Day and night".
- Hold a wallpaper in a grid or on the wallpaper card. Tap the round "Day and night" action. A sheet opens with "Use as day wall" and "Use as night wall".
- If the wall has colour variants, the sheet also shows "Use the lightest and darkest variant".
- Route `DayNightRoute`, path `/day-night`. Screen: `lib/features/day_night/views/pages/day_night_screen.dart`.

The hold menu holds at most 6 actions, so Day and night uses one action that opens a sheet. The Set screen "More" menu shows on Android only, so it has no Day and night item.

### The pair

`DayNightPair` in `lib/features/day_night/domain/entities/day_night_pair.dart`:

| Field | Meaning | Default |
|---|---|---|
| `day`, `night` | The two walls (`DayNightWall`: id, source, full URL, thumbnail URL, main colour). | None |
| `times` | `DayNightTimes`: the day start and the night start, in minutes after local midnight. The two times are never equal. | 07:00 and 19:00 |
| `target` | Home screen, lock screen, or both. | Both |
| `enabled` | The mode is on. | Off |
| `fromVariants` | Both walls came from the variant pick. | False |

- Day runs from the day start up to the night start. When the night start is earlier than the day start, day runs past midnight.
- Prism uses the local wall clock of the device. When the time zone changes, the slot follows the new local time.
- On a DST change day, a missing local time (for example 02:30) is not a problem: the next minute that exists is past the start, so the slot is correct.
- Equal times are refused. The screen shows "Pick two different times." and keeps the old times.

The pair is stored in the settings box at `dayNight.pair` as one JSON value with the owner id. A pair saved by another account loads as an empty pair.

### Variant pick

`dayNightFromVariants` in `lib/features/day_night/domain/day_night_variants.dart` reads the main colour of each variant: a Prism palette id or a hex value. It takes the relative luminance. The lightest variant is the day wall and the darkest is the night wall. The item does not show when fewer than 2 variants have a main colour, or when all have the same luminance.

### Free and Pro

Day and night uses the same gate as auto-rotate: Prism Pro or an active 7-day auto-rotate pass (`autoRotateEntitled`).

- Any signed-in user can pick the walls.
- A free user sees "Day and night is a Prism Pro feature." and "See Prism Pro" in place of the switch.
- When Pro or the pass ends, the same lapse rule as auto-rotate applies. `DayNightSessionListener` sends the session to `DayNightBloc` when the app starts, on resume, and when the session or the passes change. If the mode was on, the bloc turns it off, removes the Shortcuts snapshot and shows one toast: "Day and night is off because your Prism Pro plan or pass ended." Signing out or switching account turns it off with no toast.

### iOS: how it works

| Path | Role |
|---|---|
| `lib/features/day_night/biz/bloc/day_night_bloc.j.dart` | Loads, saves and publishes the pair. Owns the Pro gate and the lapse rule. |
| `lib/features/day_night/data/repositories/day_night_repository_impl.dart` | Saves the pair. Keeps offline copies of both walls. Writes and removes the Shortcuts snapshot. |
| `lib/features/day_night/views/widgets/day_night_guide_sheet.dart` | The guide that builds the two automations. |
| `ios/Runner/Shortcuts/Core/PrismDayNight.swift` | Parses the snapshot and picks the slot for a date. |
| `ios/Runner/Shortcuts/GetPrismWallpaperIntent.swift` | The source "Day and night" and its option "Time" (Now, Day or Night). |

Data path:

```text
Day and night screen -> DayNightBloc -> DayNightRepositoryImpl.publish
  -> OfflineAssetStore.retain (https walls) or the downloaded original (protected walls)
  -> NativeAssetPathsStore group "daynight"
  -> shared_preferences "shortcuts.day_night" -> UserDefaults "flutter.shortcuts.day_night"
  -> Get Prism Wallpaper (source Day and night) -> Set Wallpaper Photo
```

- Turn on the switch. Prism copies both walls for offline use first. Then it writes the snapshot. The action then works without the app and without the network.
- A protected Prism original has no public URL. Prism uses it only if the user downloaded it. If not, the wall card shows "Download this wall in Prism first." and the mode stays off.
- If the copy fails, the screen shows "Could not save the walls for offline use. Check your connection." with "Try again".
- A change to a wall, the times or the target while the mode is on publishes again. If that fails, the mode turns off and the screen shows the reason.
- Each app start publishes again, so the offline copies stay. A wall that was deleted or made protected after the pick still works from its offline copy.
- Turning the mode off, a lapse, sign-out and account deletion remove the snapshot. The action then fails with "Day and night is off. Open Prism and turn it on."

Snapshot value:

```json
{"dayStart": 420, "nightStart": 1140,
 "day": {"id": "<wall id>", "url": "https://..."},
 "night": {"id": "<wall id>", "asset": "original:prism_<wall id>"}}
```

### iOS: the automations

"Set up in Shortcuts" opens the guide sheet. The user makes 2 automations, one for each start time:

1. In Shortcuts, tap Automation, then tap +.
2. Tap Time of Day. Choose the time, then Daily.
3. On iOS 17 or later, choose Run Immediately, tap Next, then tap New Blank Automation. On iOS 16, there is no Run Immediately or New Blank Automation step.
4. Add "Get Prism Wallpaper". Set Source to Day and night.
5. Add "Set Wallpaper Photo". Choose the screens that match the target. Turn off Show Preview.
6. On iOS 16, turn off Ask Before Running after adding the actions.

With Sunrise or Sunset in place of a fixed time, set Time to Day for the sunrise automation and Night for the sunset one. With Time set to Now, the action uses Prism's times.

### Android: what the plugin needs

`async_wallpaper` 3.6.0 has these triggers. None can change the wallpaper at two times of day:

- `timeOfDay` sets one inexact alarm each day, on the hour only. Each run moves to the next wall in the playlist. It does not look at the time.
- `interval` is WorkManager periodic work. It does not follow the clock, and it starts its count again after each reboot.
- The boot receiver schedules the triggers again. It does not apply a wallpaper.

The plugin needs a daily schedule API: a list of `{minute of day, source}` entries, one inexact `setAndAllowWhileIdle` alarm for the next entry, and a run that applies the entry for the current local time. Boot, time change and time zone change must apply the current entry and set the next alarm. Starting a daily schedule must stop rotation, and the reverse. A plugin release needs the owner's OK.

### Analytics

- `day_night_enabled` has the fields `target` and `from_variants`.
- `day_night_disabled` has no fields.
- `day_night_ios_guide_opened` has no fields.
- There is no `day_night_switched` event. On iOS, Shortcuts sets the wallpaper and Prism does not see it. Android has no switch yet.

### How to test

1. Use an iPhone with iOS 16 or later. Sign in as a Pro user.
2. Hold a wallpaper. Tap "Day and night", then "Use as day wall". Make sure the toast "Day wall set." shows.
3. Hold another wallpaper. Tap "Day and night", then "Use as night wall".
4. Open Settings, then "Day and night". Make sure both walls show with "From 07:00" and "From 19:00".
5. Set both times to the same value. Make sure "Pick two different times." shows.
6. Turn on "Switch walls at these times". Tap "Set up in Shortcuts" and follow the guide.
7. Turn on airplane mode. Run each automation. Make sure the day wall and the night wall are set.
8. Open a wall with colour variants. Hold it. Make sure "Use the lightest and darkest variant" shows and sets both walls.
9. On Android, make sure no Day and night item shows.

Automated tests:

- `test/features/day_night/`
- `ios/RunnerTests/PrismDayNightTests.swift`

Command:

```sh
fvm flutter test --no-pub test/features/day_night
```

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
