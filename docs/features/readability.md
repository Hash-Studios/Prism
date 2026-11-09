# Readability tips

Before the user sets a wallpaper, Prism checks if the lock screen clock or the home screen icons will be hard to read on it. If a zone is hard to read, a small chip shows next to that zone. The chip offers a one-tap fix: a soft dim or a small blur behind the zone.

The tip is a quiet hint. It never blocks Set or Save. The wall stays the hero.

- App: `lib/features/readability/`.
- Platforms: Android and iOS.
- Plans: all plans. The fix is free.

## Where it shows

| Surface | Platform | What the fix changes |
|---|---|---|
| Set screen (`ClockOverlay` with a `SetScreenRequest`) | Android | The file that Set sets. |
| Phone preview with **Save to Photos** | iOS | The copy that Save stores in Photos. |
| AI tab preview with **Save to Photos** | iOS | The copy that Save stores in Photos. |
| Day and night screen, under each wall | Android and iOS | The copy that the schedule (Android) or the Shortcuts snapshot (iOS) uses. |

The chip does not show:

- When all zones are ok.
- When **Readability tips** is off in Settings.
- When a tip already showed for this wall in this app session.
- For live wallpapers. The Set screen hides the chip in the 3D (spatial) view and in the Duo view. The live wallpaper screen has no chip.
- When the screen cannot apply a fix, for example the plain preview without Set.
- When the analysis is not done in 2 s, or when it fails.

## The domain

`lib/features/readability/domain/readability.dart` holds the model.

| Type | Meaning |
|---|---|
| `ReadabilityZone` | `clock` (lock screen clock and date) or `icons` (home screen grid and dock). |
| `readabilityZoneRects(zone, platform)` | The rectangles of a zone as fractions of the screen, one set per platform. |
| `ReadabilityResult` | The result for one zone: `lowContrastShare`, `edgeShare`, and `fix`. A zone with a `fix` is busy. A zone without one is ok. |
| `ReadabilityFixKind` | `dim` (a soft black gradient) or `blur` (a small blur). |
| `ReadabilityFix` | One zone and one kind. Its key is, for example, `clock-dim`. |

### Zones

The zones come from Prism's own lock and home previews (`preview_layers.dart`). Those previews follow the stock iOS and Android layouts. Launchers differ, so a zone is approximate.

| Platform | Clock | Icons |
|---|---|---|
| iOS | 0.12 to 0.88 wide, 0.09 to 0.27 high | Grid: 0.05 to 0.95 wide, 0.08 to 0.50 high. Dock: 0.03 to 0.97 wide, 0.84 to 0.95 high. |
| Android | 0.10 to 0.90 wide, 0.07 to 0.30 high | 0.04 to 0.96 wide, 0.60 to 0.88 high (two rows and the dock). |

### Analysis

`analyzeReadability` is a pure function. `ReadabilityTips.check` runs it in an isolate (`Isolate.run`).

1. Prism decodes the image that the screen shows: the placed file after the Position studio, the edited file from the editor, or the wall preview. The colour variation applies too.
2. Prism draws it as the screen shows it: it covers a frame 108 px wide with the screen aspect, centred.
3. For each pixel in a zone, the analysis calculates the WCAG contrast ratio against the text colour. The clock uses the colour that the preview clock uses (black or white, from `textColorForTopThird`). The icons use white.
4. A pixel with a contrast below 3:1 is low contrast. A pixel whose luma step to its right and lower neighbours is more than 0.15 is an edge.
5. A zone where more than 25% of the pixels are low contrast gets `dim`. Else, a zone where more than 22% of the pixels are edges gets `blur`. Else the zone is ok.

The thresholds are constants in `readability.dart`. They are tuned on the test fixtures and a few real walls.

One analysis of a 108 x 234 frame takes less than 1 ms on a laptop. The test bound is 50 ms.

### Cache

`ReadabilityTips` keeps the last 32 results. The key (`ReadabilityKey`) is a record of the wall id, the local image path (for an edit or a placement), the placement, the tint, the platform, the clock colour, and the frame height. A cache hit does not decode the image.

## The fix

`paintReadabilityFixes` in `readability_render.dart` paints every fix. These paths use it, so the preview matches the file:

- `renderPlacementPng`: the Position studio render. `WallpaperPlacement.fixes` carries the fixes.
- `renderReadabilityFrame`: the analysis frame, the before and after preview, and the iOS full-screen preview.

| Kind | What it paints |
|---|---|
| `dim` | Black at 50% opacity from the nearest screen edge over the zone. It fades to clear 10% of the screen height past the zone. |
| `blur` | The wall again with a blur of 1.2% of the short side, kept in a soft band around the zone. |

A fix never changes the source wall. It always writes a new file.

- Android: **Apply** calls `SetScreenRequest.onApplyFixes`. The flow gets consent for the original first (as Adjust does), then `PlacedWallpaper.render` draws the original with the placement and the fixes. Set then uses that file, as after the Position studio. A new placement from the studio clears the fixes, and the tip can show again for the new image.
- iOS: **Apply** draws the fix on the preview. **Save** passes the fixes to `saveAction`. The detail screen adds them to the `DownloadVariant` (after the colour variation, when there is one). The saved copy has the screen size. The detail screen keeps only its last fixed copy in the temp folder.
- Day and night: **Apply** adds the fix to the slot wall (`DayNightWall.fixes`, saved in the pair). When the mode publishes, the repository renders a copy to `<app support>/prism/offline/assets/day_night_fixed/<slot>.png`. Android schedules that file. iOS adds it to the Shortcuts snapshot as the asset `daynight-fixed-<slot>`.

The fix works for Home, Lock and Both, because Set uses one file for the chosen target. It works for both walls of a day and night pair.

## The chip and the sheet

- The clock chip shows under the clock zone. The icons chip shows on top of the controls card, near the dock.
- The chip for a zone shows only while the preview shows that zone: Lock shows the clock chip, Home shows the icons chip.
- A tap opens a sheet with a before and an after thumbnail, **Apply** and **Keep as is**. **Apply** is active when the after image is ready.
- The chip uses theme colours and `PressScale`. It has a 44 point target, a `Semantics` label and hint, and wraps to two lines with large text.
- The chip fades in over 240 ms with a scale from 0.95. With reduce motion on, it shows at once (`context.motion`).

Copy (all 7 locales):

| Key | English |
|---|---|
| `readabilityClockChip` | Clock may be hard to read |
| `readabilityIconsChip` | Icons may be hard to read |
| `readabilityDimClockTitle` | Dim behind the clock? |
| `readabilityBlurIconsTitle` | Soften behind the icons? |
| `readabilityApply` | Apply |
| `readabilityKeep` | Keep as is |
| `settingsReadabilityTipsTitle` | Readability tips |

## Settings

**Settings** has **Readability tips** under **Show tips**. It is on by default. The value is in `readability.enabled` (device-wide).

The tip is not a feature hint. It does not use the hint budget, and **Show tips** does not turn it off.

## Analytics

| Event | Fields | When |
|---|---|---|
| `readability_tip_shown` | `zone` | A chip shows for the first time on a screen. |
| `readability_fix_applied` | `zone`, `fix_kind` | The fix is applied. |
| `readability_fix_kept` | `zone` | The user taps **Keep as is**. |

A set whose wall only a fix shaped tracks `set_wall` with `fit` = `readability_fix` and no `wallpaper_placement_applied`. A fix on top of a Position studio placement keeps the studio `fit` and its placement event.

## Safety

- A failed or slow analysis shows no chip. Set and Save never wait for the analysis.
- A failed fix render shows "Couldn't apply the fix. Try again." The wall stays as it was.
- The analysis decodes a small image (about 216 px high). The fix render decodes the wall at most 4096 px on the long side, as the Position studio does.

## Code

| Path | Role |
|---|---|
| `lib/features/readability/domain/readability.dart` | Zones, results, fixes, `analyzeReadability`. |
| `lib/features/readability/data/readability_render.dart` | `paintReadabilityFixes`, `renderReadabilityFrame`, `decodeForFrame`. |
| `lib/features/readability/data/readability_tips.dart` | Setting, session memory, cache, isolate. |
| `lib/features/readability/views/readability_views.dart` | Chip, before and after sheet, Settings row, `ReadabilityFixedImage`. |
| `lib/features/wallpaper_detail/views/widgets/clock_overlay.dart` | The Set screen and the iOS preview. |
| `lib/core/widgets/menu_button/set_wallpaper_choice.dart` | `PlacedWallpaper.render`. |
| `lib/features/day_night/views/widgets/day_night_readability_tip.dart` | The day and night tip. |

## Limits

- The zones are approximate. A launcher with a different layout can put icons outside the icons zone.
- The analysis reads the wall at a small size. Very fine detail can read as smooth.
- The system can change the clock colour after the set. iOS and Android choose it from the wall, so the result can differ from the preview.
- On iOS the fixed copy has the screen size, not the size of the original.

## Test

- `fvm flutter test --no-pub test/features/readability test/features/day_night`
- On a device: open a wall with a bright or busy top, tap **Set**, pick **Lock screen**. The clock chip shows. Tap it, tap **Apply**, then **Set**. The lock screen clock reads over the dim.
