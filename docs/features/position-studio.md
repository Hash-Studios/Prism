# Position studio

The Position studio lets the user pan, zoom, fit, and dim a wallpaper before it is set. It shows the result in a frame the shape of the phone screen, under a preview of the lock screen or the home screen. It replaces the old "Crop and position" switch, which never worked.

## Where to find it

Open the set sheet (tap **Set** on a wallpaper, or long press it). Tap **Adjust position and preview**. The route is `WallpaperPositionRoute` (`/wallpaper-position`).

## Platforms and plans

- Android only. iOS cannot set wallpapers from the app, so the iOS flow does not show Set.
- Free for all users. The Dim control is free too. There is no coin gate.

## How it works

The screen has a frame and a bottom panel.

The frame:

- It has the aspect ratio of the device screen.
- The wallpaper sits in an `InteractiveViewer`. One finger pans. Two fingers zoom from 1x to 4x.
- A **Lock** and **Home** toggle above the frame draws the lock clock or the home date and dock over the wallpaper. These are `LockPreviewLayer` and `HomePreviewLayer`. The clock preview on the detail screen uses the same two widgets.
- The dim layer sits between the wallpaper and the lock or home layer.
- The caption under the frame says "Approximate. Your launcher may differ."

The bottom panel:

- **Fill**: the wallpaper covers the screen. The sides or the top and bottom are cropped.
- **Fit with blur**: the whole wallpaper over a blurred copy of itself.
- **Fit with colour**: the whole wallpaper over its dominant colour.
- **Dim**: a black layer from 0 to 60 percent.
- **Reset**: back to Fill, centred, zoom 1x, no dim. It keeps the Lock or Home view.
- Target buttons: Home screen, Lock screen, Both. The panel hides the targets the device cannot set (`getCapabilities`).

`WallpaperPlacement` holds `fit`, `dx`, `dy`, `zoom`, `dim`, and `previewMode`. `dx` and `dy` run from -1 to 1. A value of -1 shows the left or top edge of the wallpaper. A value of 1 shows the right or bottom edge. `PlacementGeometry` has the math, and both the preview and the render use it, so the result matches the preview.

When the user taps a target:

1. The app decodes the wallpaper once at most 4096 px on the long side.
2. `renderPlacementPng` draws the placement with a `PictureRecorder`, as the editor export does. The output size is the device screen in pixels, capped by `exportSize`. `Fit with blur` draws a blurred, scaled copy under the wallpaper (`ImageFilter.blur`, `TileMode.mirror`). The dim layer is a black rectangle on top.
3. The PNG goes to a `prism_edit/position_*` folder in the temp directory.
4. `WallpaperService.setWallpaper(path, target, fit: fill, historySource: <original URL>, historyThumbnail: <thumbnail URL>)` sets it. History keeps the original wallpaper, not the temp file, so a set again from history works.
5. The studio shows the normal result: the snackbar with **Undo**, or an error with **Try again**. On success it closes. The temp file is deleted, except while the system preview is open.

Analytics:

- `wallpaper_position_opened` with `source` (the screen the user came from).
- `wallpaper_placement_applied` with `fit`, `zoomed`, `dim_bucket` (dim in steps of 10), `wallpaper_target`, and `result`.

| Path | Role |
|---|---|
| `lib/features/wallpaper_position/domain/entities/wallpaper_placement.dart` | `WallpaperPlacement`, `PlacementFit`, `PlacementPreviewMode`. |
| `lib/features/wallpaper_position/domain/placement_geometry.dart` | Shared layout math. |
| `lib/features/wallpaper_position/data/placement_renderer.dart` | `renderPlacementPng`, `dominantColorOf`. |
| `lib/features/wallpaper_position/data/repositories/wallpaper_position_repository_impl.dart` | Load, decode, render to file. |
| `lib/features/wallpaper_position/biz/bloc/` | `WallpaperPositionBloc`. |
| `lib/features/wallpaper_position/views/` | Screen, preview, panel. |
| `lib/features/wallpaper_detail/views/widgets/preview_layers.dart` | `LockPreviewLayer`, `HomePreviewLayer`. |

## Limits

- The preview is approximate. Launchers crop, scroll, and place clocks in their own way.
- The final look is not proven on a device. The plugin crops to the display size, so the rendered PNG has the display aspect. Check a launcher that scrolls the wallpaper.
- A wallpaper larger than 4096 px on the long side is decoded smaller.
- The editor (filters) does not use the studio. Set from the editor opens the set sheet without the studio row.
- The dominant colour comes from a 64 by 64 copy of the wallpaper.

## How to test

1. On Android, open a landscape wallpaper. Tap Set, then **Adjust position and preview**. Make sure the frame shows the middle of the wallpaper.
2. Drag the wallpaper. Make sure the visible part moves. Pinch to zoom. Make sure the zoom stops at 4x.
3. Tap **Fit with blur**. Make sure the whole wallpaper shows over a blurred copy. Tap **Fit with colour**. Make sure the bars use one colour from the wallpaper.
4. Move the Dim slider to 60%. Make sure the wallpaper gets darker and the clock does not.
5. Switch Lock and Home. Make sure the layer changes.
6. Tap **Reset**. Make sure the placement returns to Fill, centred, no dim.
7. Tap **Lock screen**. Make sure the lock screen shows the framed result and the snackbar has **Undo**.
8. Open Wallpaper history. Make sure the new row shows the original wallpaper, not a temp file.
9. Turn on airplane mode and open the studio on a wallpaper that is not cached. Make sure it says "Couldn't load this wallpaper" with **Try again**.

Automated tests:

- `test/features/wallpaper_position/domain/placement_geometry_test.dart`
- `test/features/wallpaper_position/data/placement_renderer_test.dart`
- `test/features/wallpaper_position/data/repositories/wallpaper_position_repository_impl_test.dart`
- `test/features/wallpaper_position/biz/wallpaper_position_bloc_test.dart`
- `test/features/wallpaper_position/views/wallpaper_position_screen_test.dart`
- `test/features/wallpaper_detail/views/widgets/preview_layers_test.dart`

Command: `fvm flutter test --no-pub test/features/wallpaper_position`
