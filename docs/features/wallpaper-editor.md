# Wallpaper editor

The wallpaper editor changes a wallpaper before the user keeps it. The user adds filters, changes five colour settings, and crops the image. Then the user downloads, shares or sets the edited file. The editor is `WallpaperFilterScreen`.

The editor never changes the Prism original. Each export is a new file.

## Where to find it

Open a wallpaper detail screen. Tap **Edit**. The editor opens. The bottom panel (`FilterEditorPanel`) has three tabs:

- **Filters**: preset looks for the image.
- **Adjust**: five sliders for blur, hue, saturation, lightness and brightness.
- **Crop**: the crop frame, the presets, rotate and reset.

The top bar has **Reset**, **Download**, **Share** and **Set**. **Set** is hidden where `hideSetWallpaperUi` is true. That is iOS.

## Platforms and plans

- Android and iOS. On iOS, **Set** is hidden and **Download** saves to Photos.
- Edit uses the same server grant as Download for protected Prism originals. The call is `resolveOriginalWithConsent` with `OriginalAccessAction.edit`.
- The server prices edit like download. Edit has no grace downloads.
- Pro walls are protected Prism walls. A crop of a Pro wall needs the same Pro, pass or coins as Download.
- A crop alone costs no premium filter coins.
- Filters and adjustments still use the premium filter coin gate.

## How it works

### Crop tab

The crop frame covers the whole image. It is `CropFrameView`.

- Drag inside the frame to move it.
- Pinch to resize the frame.
- Drag a corner handle to resize the frame from that corner.
- A rule-of-thirds grid shows only while a finger is down.

Tap a preset to change the frame shape:

| Preset | Frame |
|---|---|
| Free | Any shape. |
| This phone | The screen aspect, in portrait. |
| 9:16 | Portrait. |
| 1:1 | Square. |
| 16:9 desktop | Landscape. |
| Original | The aspect of the whole image. |

The tab has two buttons:

- **Rotate 90°** turns the image clockwise. The frame turns with the image. A fixed preset fits a new frame of its aspect.
- **Reset crop** returns the frame to the whole image.

The tab shows the output size, for example "1080 × 1920 px". A preset tap plays a selection haptic (`PrismHaptics.selection`). The frame moves to a preset in 240 ms. With reduce motion on, the frame jumps.

The other tabs show the cropped image. Filters preview on the kept area only.

### Export

The export applies the crop first. It reads the kept area from the source in source pixels. It turns that area on the canvas. Then it runs the filters and adjustments on the kept area only.

- With a crop, the output is the kept area at full resolution. The export does not downscale.
- Without a crop, the long side is capped at 4096 px (`maxExportLongSide`). If the device screen long side is larger, the cap is the screen size.
- The source is decoded once. Rendering and PNG encoding can allocate more full-image buffers, including the output and encoded PNG. Cropped exports are not capped, so large sources or crop outputs can use substantial memory and may run out of memory.
- Decode, render and PNG encode run on engine threads. The UI thread only waits.
- After 30 s (`editExportTimeLimit`), the action reports that saving took too long. This timeout does not cancel the render. Export actions stay disabled until the render settles. If it finishes after the timeout, the bytes are discarded and no temporary export file is created.
- The decoder applies EXIF orientation first. The crop uses that oriented space. The output PNG has no EXIF.

The export runs in `renderEditedFile` and `renderEditedPng` in `wallpaper_edit_pipeline.dart`.

### Download, Share and Set

Each action uses the cropped and filtered file.

- **Download** saves the edited file. Its temporary export is removed after the action.
- **Share** sends the edited file. Its temporary file stays until the editor closes so the receiving app can read it late; the editor then removes its owned export. Cleanup only removes files created by the editor, never the source wallpaper.
- **Set** opens the Set screen with the edited file. Its **Adjust position and preview** row opens the Position studio on that file. If the user places the wall in the studio, **Set** uses the placed file.

## Crop and placement are different

Crop and placement both shape the wall image. They do different jobs.

- Crop changes the file. It removes pixels and can turn the image. Every export gets the new file.
- Placement does not change the source. It only decides how **Set** fits the wall on this screen. See `docs/features/position-studio.md`.

Use crop for a new file that you keep or share. Use placement to frame a wall on your screen.

| | Crop | Placement |
|---|---|---|
| Changes the file | Yes. It removes pixels. | No. It only sets the fit for one **Set**. |
| Output size | The kept area at full source resolution. | The device screen size, capped by `exportSize`. |
| Used by | **Download**, **Share** and **Set**. | **Set** only. |
| Where | **Edit**, then the **Crop** tab. | The Set sheet, then **Adjust position and preview**. |

## Limits

- The frame cannot leave the image.
- The minimum side is a tenth of the short side of the image.
- The crop lasts for one editor session. It resets when the editor opens again, when the source file changes, when the image size changes, or when the user retries a failed image load.
- Large sources and uncapped crop outputs can use substantial memory and may run out of memory. See the memory note in Export.
- VoiceOver: each preset is a button. The presets alone give a usable crop.
- VoiceOver: each corner handle has a label. Swipe up or down on a handle to grow or shrink the frame by 5 percent of the short side.

## Analytics

- `wallpaper_crop_applied` with `preset` and `adjusted`. It fires when a cropped export is downloaded, shared or set.
- `wallpaper_crop_reset` with `preset`. It fires when the user resets a crop.

## Code

| Path | Role |
|---|---|
| `lib/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart` | `WallpaperFilterScreen`, the editor. |
| `lib/features/wallpaper_detail/views/widgets/filter_editor_panel.dart` | `FilterEditorPanel`, the tabs. |
| `lib/features/wallpaper_detail/views/widgets/crop_frame_view.dart` | `CropFrameView`, the frame and gestures. |
| `lib/features/wallpaper_detail/domain/entities/crop_spec.dart` | `CropSpec`, pure data for the crop. |
| `lib/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart` | Export. |

`CropSpec` holds the source size, `quarterTurns` (0 to 3), `preset`, `rect` (whole pixels in the turned view), `sourceRect` (the same area in source pixels) and `adjusted`. `adjusted` is true after a hand move, pinch or corner move since the last preset or reset. Every operation returns a new spec. Gestures apply the total movement since the gesture started. Rounding does not build up.

## How to test

Automated tests:

- `test/features/wallpaper_detail/domain/crop_spec_test.dart`
- `test/features/wallpaper_detail/wallpaper_edit/wallpaper_edit_crop_export_test.dart`
- `test/features/wallpaper_detail/wallpaper_edit/wallpaper_filter_crop_ui_test.dart`
- `test/features/wallpaper_detail/wallpaper_edit/wallpaper_filter_crop_export_test.dart`

Screenshots without a device: `make test-qa-render QA_RENDER_TARGET=test/qa_render/wallpaper_crop_render.dart`. The PNGs go to `build/qa_render/`.

Command: `fvm flutter test --no-pub <file>`

Manual check:

1. Open a wallpaper. Tap **Edit**.
2. Open the **Crop** tab. Tap **16:9 desktop**. Make sure the frame is landscape and the output size shows.
3. Tap **Download**. Check the saved file. Make sure its pixel size matches the output size on the **Crop** tab.
