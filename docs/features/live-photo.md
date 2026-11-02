# Live Photo walls (iOS)

iOS does not let an app set a wallpaper. iOS can use a Live Photo from Photos as a Lock Screen wallpaper, and the Lock Screen plays its motion. Prism renders a wall in a live style to a short video, pairs the video with a key photo, and saves the pair to Photos as one Live Photo. Then Prism shows the user how to set it.

Android keeps Make it live (see [live-wallpapers.md](live-wallpapers.md)). This page is about iOS only.

## What it does

| Step | What the user sees |
|---|---|
| Open | On the Set screen (iOS), the user taps "Live Photo". A sheet shows the wall in a phone frame. It moves in the selected style. |
| Pick | The user picks a style: Drift, Breathe, Shimmer, or 3D when the wall has a depth map. Paid styles show a lock. |
| Save | "Save Live Photo" renders a 3-second clip at the screen size, with a progress bar and Cancel. iOS asks for add-only Photos access the first time. |
| Guide | After the save, a guide sheet shows 3 steps to set the Live Photo as the Lock Screen wallpaper, honest notes, and "Open Photos". |

Ripple and the gradient styles are not offered. Ripple needs a touch, so a clip shows a static ring. The gradients do not use the wall.

### States

| State | Shows |
|---|---|
| Picking | Preview, style chips, "Save Live Photo". |
| Exporting | Preview, status ("Making your Live Photo", then "Saving to Photos"), progress bar, "40% done", Cancel. |
| Refused | "Prism can't add to Photos", how to allow it, "Open settings" (opens `app-settings:`), "Not now". A device policy (Screen Time) shows a different body. |
| Failed | The reason (wall did not load, time limit, Photos refused the save, render error) and "Try again". |

## Where to find it

- iOS only. The Set screen is the preview that opens from the wall detail (`pushClockPreview`). The "Live Photo" button is under "Save to Photos".
- It does not show for Duo walls. It does not show on Android. Android keeps Make it live.

## Access

A Live Photo is a copy of the wall in Photos. So it follows the Download rules:

| Wall | Rule |
|---|---|
| Any | The user must sign in. |
| Pro wall (premium collection) | Needs Prism Pro or an active premium pass (`CoinsService.premiumContentUnlocked`). Otherwise the paywall opens. |
| Protected original | On the first Save, the same server grant as Download: `resolveOriginalWithConsent` with `OriginalAccessAction.download`. The coin price and the consent sheet are the Download ones. |
| Paid style | Breathe, Shimmer and 3D need Pro or a coin unlock, the same as Make it live. The unlock sheet is shared (`offerLiveStyleUnlock`). |

## How it works

| Path | Role |
|---|---|
| `pigeons/prism_live_photo_api.dart` | The one native entry point, `PrismLivePhotoHostApi.exportLivePhoto`, plus `cancelLivePhotoExport` and the progress callback `PrismLivePhotoFlutterApi.onLivePhotoExportProgress`. iOS only. Run `make pigeon-gen` after a change. |
| `lib/features/live_photo/domain/entities/live_export.dart` | `LiveExport` (wall, style, duration, size) and `LiveExportOutcome` (saved, cancelled, refused, timed out, failed). Limits: 3 seconds, 30 frames per second, 45 seconds for render and encode. |
| `lib/features/live_photo/data/repositories/live_photo_repository_impl.dart` | Crops the wall to the screen aspect with `LiveTexturePreparer`, calls the native export, maps the result, and deletes the texture files. |
| `lib/features/live_photo/biz/bloc/` | `LivePhotoBloc`: picking, exporting, saved, refused, failed. Sends the analytics events. |
| `lib/features/live_photo/views/` | The sheet, the motion preview, the guide, and `openLivePhoto` (access). |
| `ios/Runner/LivePhoto/PrismLivePhotoRenderer.swift` | Metal. One fragment function for each style. The shader source compiles at run time. |
| `ios/Runner/LivePhoto/PrismLivePhotoExporter.swift` | Permission, render loop, AVAssetWriter, pairing metadata, save, read-back, time limit, cleanup. |
| `ios/Runner/PrismLivePhotoHostApiImpl.swift` | Pigeon glue. One export at a time. Sends progress on the main thread. |

### Render

1. Dart crops the wall to the screen aspect and writes a JPEG (`LiveTexturePreparer`). 3D also writes the depth map with the same crop.
2. Native asks for add-only Photos access. A refusal stops here.
3. A detached task renders each frame on the GPU into a pixel buffer from the writer's pool. The main thread does no render work.
4. The clip is HEVC when the device can encode it, else H.264. The size is the screen size in pixels, with even sides, at most 4096.
5. Each style moves with `sin(phase)` and `sin(2 phase)` only. So the first, middle and last frames are the same picture. The key photo is the middle frame, so the still wallpaper matches where the motion starts and ends. Shimmer sweeps two times and is off screen at the start, middle and end, so the key photo has no glow.
6. The key photo is HEIC (JPEG when there is no HEIC encoder), with the content identifier in MakerApple key 17. The video has the QuickTime content identifier and the still-image-time track at the middle frame.
7. One `PHAssetCreationRequest` saves `.photo` and `.pairedVideo`. When the app can read the library, it fetches the asset and checks `.photoLive`. A saved asset without `.photoLive` is a failure (`not-live`).

### Cancel, time limit and cleanup

- Cancel stops the render at the next frame, cancels the writer, and deletes the work folder (`tmp/prism-live-photo/`). Closing the sheet also cancels.
- The time limit (45 seconds) covers render and encode. Saving is outside it, so a save never stops half done.
- Each export first deletes what an older export or a crash left in the work folder.
- Dart deletes its texture JPEGs after every export.

### Analytics

| Event | Fields |
|---|---|
| `live_photo_export_started` | `style` |
| `live_photo_export_done` | `style`, `duration_ms` |
| `live_photo_export_failed` | `style`, `reason` (`permission_denied`, `permission_restricted`, `timed_out`, `source_unavailable`, `render_failed`, `encode_failed`, `save_failed`, `not_live`, `invalid_request`, `unavailable`) |
| `live_photo_export_cancelled` | `style` |
| `live_photo_guide_opened` | none |

`style` uses `LiveWallpaperStyleValue` (3D is `3d`).

## Limits

- Lock Screen motion is not guaranteed. See "The main risk" below. Only a real iPhone can show if iOS plays the motion.
- With add-only access, the app cannot read the asset back. Then it trusts the Photos save, because Photos refuses a pair with wrong metadata.
- The texture is at most 2400 px high, so on the largest iPhones the frames scale up a little.
- iPad: the button shows. A Developer Forums report says iPadOS 17 does not play Live Photo motion on the Lock Screen. We did not check this.

## Tests

- Dart: `test/features/live_photo/` (bloc, repository mapping, sheet states, guide, large text, access) and `test/features/wallpaper_detail/views/widgets/clock_overlay_live_photo_test.dart` (iOS only entry).
- Native: `ios/RunnerTests/LivePhotoExportTests.swift`. It renders each style, checks the shared identifier in both files and the still-image-time track, saves to the simulator Photos library, reads the asset back and checks `.photoLive`. It also checks cancel and the time limit leave no files. Grant Photos first: `xcrun simctl privacy <udid> grant photos com.hash.prism`.

### What only a real iPhone can prove

- That the Lock Screen accepts the Live Photo with motion on, or says "Motion not available".
- How the motion looks when the iPhone wakes.
- Low Power Mode and Reduce Motion behaviour.
- HEVC encode time on older iPhones.

## Research

We did this research before we built the feature. Sources are at the end of this section.

### How Photos pairs a photo and a video

A Live Photo is two files with one shared identifier. Both files must carry the same UUID string:

| File | Where the identifier goes |
|---|---|
| Key photo (HEIC or JPEG) | MakerApple dictionary (`kCGImagePropertyMakerAppleDictionary`), key `"17"`. |
| Paired video (QuickTime `.mov`) | Top-level QuickTime metadata item `com.apple.quicktime.content.identifier` (key space `mdta`, UTF-8). In AVFoundation this is `AVMetadataIdentifier.quickTimeMetadataContentIdentifier`. |

The video also needs a timed metadata track with one item, `com.apple.quicktime.still-image-time` (key space `mdta`, data type `com.apple.metadata.datatype.int8`, value `0`). Its presentation time marks the frame that the key photo shows. Write it with an `AVAssetWriterInputMetadataAdaptor` whose format description comes from `CMMetadataFormatDescriptionCreateWithMetadataSpecifications`.

To save, use one `PHAssetCreationRequest`. Add the photo with resource type `.photo` and the video with `.pairedVideo`, in the same `performChanges` block. When the identifiers do not match, Photos refuses the request or saves a still photo only.

To check the result, fetch the new asset by its local identifier and check that `mediaSubtypes` contains `.photoLive`. This read needs read access to the library. The add-only level (`PHAccessLevel.addOnly`) cannot fetch assets.

### Lock Screen motion

| Item | What we found |
|---|---|
| iOS versions | iOS 16 removed Live Photo motion from the Lock Screen. iOS 17 added it again. iOS 17, 18 and 26 support it. Home Screen wallpapers do not play motion. |
| When it plays | The Lock Screen plays the motion one time when the user wakes the iPhone. Then it shows the key photo. |
| Low Power Mode | Most sources say Low Power Mode stops the motion. Apple does not document it. The iOS 26 Spatial Scene wallpaper also has no motion in Low Power Mode. |
| Reduce Motion | Some sources say Reduce Motion stops the motion. |
| Length | Camera Live Photos are about 3 seconds, with the key photo near the middle. One report says clips shorter than 1 second fail. No source gives an official limit. |
| Frame rate | Camera Live Photos use up to 30 frames per second. No source gives an official limit. |

### The main risk

Apple DTS said in the Developer Forums (thread 798044, 2025) that wallpaper eligibility has requirements that Apple does not document. In that thread, a developer wrote the identifier, the MakerApple key and the still-image-time track. The Live Photo played in Photos, but the Lock Screen said "Motion not available". Apple said that this is not a bug, and asked for an enhancement request.

Some open-source tools get motion on the Lock Screen. They copy timed metadata tracks (`com.apple.quicktime.live-photo-info` and `com.apple.quicktime.live-photo-still-image-transform`) from a real camera Live Photo into the new video. These tracks are not documented. Apple DTS advises against this. We do not do it.

Result: Prism writes the documented pairing only. The Live Photo saves, shows the LIVE badge, and plays in Photos. Lock Screen motion is not guaranteed. Only a real iPhone can show if iOS accepts it. The guide tells the user what to do when iOS says "Motion not available".

### Sources

- Apple Developer Forums, "Live Photos created with PHLivePhoto API show Motion not available when setting as wallpaper": https://developer.apple.com/forums/thread/798044
- Apple Developer Forums, "Motion not available ios 17 live photo": https://developer.apple.com/forums/thread/745694
- LimitPoint/LivePhoto issue 10: https://github.com/LimitPoint/LivePhoto/issues/10
- Apple PhotoKit reference: `PHAssetCreationRequest`, `PHAssetResourceType.pairedVideo`, `PHAssetMediaSubtype.photoLive`.
- Apple AVFoundation reference: `AVMetadataIdentifier.quickTimeMetadataContentIdentifier`, `AVAssetWriterInputMetadataAdaptor`.
