# Watch sets

A watch set is one wall in three sizes. One tap saves all of them:

| Item | What it is |
|---|---|
| Phone | The wall, the same file as **Download**. |
| Watch | A crop of the wall at the exact pixel size of the user's watch. |
| Desktop | The desktop version (see [desktop-companions.md](desktop-companions.md)). Only when the wall has one. |

Then a guide shows how to put the watch image on a photo watch face.

Prism has no watch app. It does not detect the watch. The user picks the watch type one time, and Prism remembers it.

## Where to find it

Open a wall. The detail panel has a **Watch set** row with the other save options (Desktop version, Depth Effect). Tap it. A sheet opens.

1. The first time, the sheet asks for the watch type. The list starts with the watches of this phone's platform: Apple Watch on iOS, Wear OS on Android.
2. The sheet shows the set: the phone wall, the watch crop in the shape of the watch screen, and the desktop version when the wall has one.
3. **Adjust watch crop** opens the crop screen. **Change watch** opens the watch list again.
4. **Save set** saves every item. The price is on the button.
5. After the save, the guide opens. **How to use it on your watch** in the sheet opens the guide again.

## Platforms and plans

- Android and iOS.
- The set follows the **Download** rules. See [coins-and-downloads.md](coins-and-downloads.md).
- The coin gate runs one time for the whole set. There is one confirm sheet with one total.

### How a set counts

| Item | Price |
|---|---|
| Phone | One **Download** of the wall at the server price: 5 coins, 15 for a Pro wall, free with Pro, a pass or a grace download. |
| Watch | Free. It is a crop of the phone file. |
| Desktop | One **Download** of the desktop version at the server price. This is the same price as the desktop version on its own. |

So a set without a desktop version costs the same as one download. A set with a desktop version costs the same as two downloads. Prism adds no new price and no new server call. The total on the confirm sheet comes from the two server quotes.

- Protected Prism walls get the phone file through `resolveOriginalAccess` (action `download`). The desktop file needs its own grant (`variant: desktop`). Both calls run inside the one gate run, in the gate's spend step.
- Wallhaven and Pexels walls use the normal download spend. They have no desktop version.
- The confirm sheet shows the server total before any charge.

### When part of a set fails

| What fails | What happens |
|---|---|
| The watch crop cannot render | Nothing is saved. A client spend is refunded, as for any failed download. |
| The phone save fails | Nothing more is saved. The download rules for a failed save apply. |
| The desktop grant is refused after the phone grant (the balance changed) | Prism saves the phone and the watch files and says that the desktop version was not saved. |
| The desktop save fails | Prism keeps the phone and the watch files and says that the desktop version was not saved. Its grant stays open for 5 minutes, so a retry in that time does not charge again. |
| The user closes the sheet during the save | The save goes on, as **Download** does. The temporary files are deleted when it ends. |
| Another account signs in during the save | Prism saves no more files of the set. The account that tapped keeps what it paid for. |
| The user has exactly one grace download left and the set has a desktop version | Each server quote is free, but the phone uses the grace download. The desktop grant then needs coins that the user did not confirm, so Prism skips it. The phone and watch files save, and Prism says that the desktop version was not saved. |

While a set saves, the sheet locks **Adjust watch crop**, the watch row and the guide button. A save refused by Photos or by Android storage permission stops the set before the second file. The `download_result` reason names the cause: `permission_denied`, `permission_restricted`, `permission_unknown` or `storage_permission_required`.

## Watch sizes

The sizes are in one table in code: `WatchFormat` in `lib/features/watch_set/domain/entities/watch_format.dart`. The watch image is exactly this size.

### Apple Watch

The screen is a rounded rectangle. Sizes are width x height in pixels.

| Group | Case | Pixels | Source |
|---|---|---|---|
| Series 4 to 6, SE, SE 2, SE 3 | 40 mm | 324 x 394 | Third party (Vodafone, newmobile) |
| Series 4 to 6, SE, SE 2, SE 3 | 44 mm | 368 x 448 | Apple compare page (SE 3) |
| Series 7 to 9 | 41 mm | 352 x 430 | Third party (carrier spec pages) |
| Series 7 to 9 | 45 mm | 396 x 484 | Apple compare page (Series 9) |
| Series 10 to 12 | 42 mm | 374 x 446 | Apple tech specs (Series 11, Series 12) |
| Series 10 to 12 | 46 mm | 416 x 496 | Apple tech specs (Series 11, Series 12) |
| Ultra, Ultra 2 | 49 mm | 410 x 502 | Apple compare page (Ultra 2) |
| Ultra 3, Ultra 4 | 49 mm | 422 x 514 | Apple tech specs (Ultra 3), Apple compare page (Ultra 4) |

Apple does not publish the corner radius of the screen. The mask preview uses a corner of 22% of the short side. It is a guide only. The saved image has square corners, and the watch masks it.

### Wear OS

The screen is round. Prism saves a square image. The watch shows the circle in it.

| Group | Pixels | Source |
|---|---|---|
| Pixel Watch (all) | 456 x 456 | Third party (GSMArena). Google gives only the density, 320 ppi. |
| Galaxy Watch 40 mm, Classic | 438 x 438 | Samsung Galaxy Watch8 spec table |
| Galaxy Watch 44 mm, Ultra | 480 x 480 | Samsung Galaxy Watch8 spec table |

Older Pixel and Galaxy watches have screens a little smaller than these. A round photo face scales the image to the screen, so a small difference does not show.

## The watch crop

The crop uses `CropSpec` from the wallpaper editor with the `watch` preset. Its aspect is the aspect of the watch format.

### Smart crop

The first frame is the largest frame of the watch aspect in the wall.

- When the wall has a subject box, the frame is centred on the subject. Then it is moved inside the wall.
- When the wall has no subject box, the frame is centred on the wall.

Prism finds a subject box only from the Spatial Scenes depth map (`walls.spatial.map`, see [spatial-scenes.md](spatial-scenes.md)). The map is grey: bright is near. The box holds the pixels in the nearest quarter of the depth range. A wall with no map, a flat map, or a map that does not load gets the centre crop. The Spatial Scenes data has no stored subject box.

### Adjust

The crop screen is `CropFrameView` from the editor with a mask:

- Round: a circle in the frame.
- Rounded rectangle: the frame with round corners.

The area outside the mask is dimmed. The user can drag, pinch and drag corners as in the editor. The frame keeps the watch aspect. **Reset** goes back to the smart crop. **Done** keeps the crop for this sheet.

The crop is made on the preview image. On save, Prism scales the crop to the full file and renders it at the watch size.

## Save

### iOS

- Each file goes to Photos with add-only access (`PHAccessLevel.addOnly`). This is the same path as **Download**.
- **No "Prism" album.** With add-only access, an app cannot read the library. It cannot find an album or check if one exists, so it cannot add to a "Prism" album. To make an album, Prism must ask for full library access. Prism does not ask for it. The three files are in **Recents**.
- When the user refused Photos access, the sheet shows the same "Allow Photos" help as **Download**.

### Android

- Each file goes to `Pictures/Prism/Downloads`, the Prism download folder in the gallery. This is the same path as **Download**, so the set also shows in the Prism **Downloads** page.

### File names

| Item | Name |
|---|---|
| Phone | The same name as **Download**. |
| Watch | The download name with `_watch-<format id>`, for example `sunset_watch-apple_46.png`. |
| Desktop | The download name with `_desktop-<version>`. |

### Temporary files

The watch image is rendered to `<tmp>/prism_watch_set/`. Prism deletes the file after the save, also when the save fails. The first render in an app run deletes files left from an earlier run.

## Guide

### iOS

**Share watch image** opens the share sheet with the watch image. Our research found that only the Photos app offers **Create Watch Face**. Prism cannot add it to its own share sheet. The guide gives the Photos steps:

1. Open Photos. The watch image is in Recents.
2. Tap the image. Tap Share. Swipe up. Tap **Create Watch Face**.
3. Tap **Photos Watch Face**. Tap **Add**.

Or, in the Apple Watch app on iPhone: Face Gallery, Photos, Choose Photos, select the watch image, then Add. A Photos face takes up to 24 photos.

### Android

Pixel Watch:

1. Open the Pixel Watch app. Tap **Watch faces**, then **Add new**.
2. Tap **Photos**. Select the watch image in Google Photos.
3. Tap **Add**, then **Save**.

Galaxy Watch:

1. Open the Galaxy Wearable app. Tap **Watch faces**.
2. Tap **My Photo+**. Tap **Customize**.
3. Select the watch image from Gallery. Tap **Save**.

### What Prism cannot do

The guide says this to the user:

- Prism cannot put the image on the watch. The watch app does this.
- Prism cannot add a "Create Watch Face" button to its share sheet. Only Photos has it.
- On iPhone, Prism cannot make a "Prism" album without full access to Photos. The image is in Recents.
- The watch app may crop or dim the image. Each watch face has its own layout and clock.
- A Pixel Watch photo face uses Google Photos. Back up the image to Google Photos first if it does not show.

## Analytics

| Event | Fields |
|---|---|
| `watch_set_saved` | `watch_type` (the format id, for example `apple_46`), `with_desktop` |
| `watch_guide_opened` | `watch_type`, `source` (`after_save` or `sheet`) |
| `watch_crop_adjusted` | `watch_type` |

`watch_crop_adjusted` fires when the user keeps a crop that is not the smart crop.

## Code

| Path | Role |
|---|---|
| `lib/features/watch_set/domain/entities/watch_format.dart` | `WatchPlatform`, `WatchShape`, `WatchFormat` (the size table), `WatchMask` (mask maths). |
| `lib/features/watch_set/domain/entities/matching_set.dart` | `MatchingSet`: phone, watch, desktop. |
| `lib/features/watch_set/domain/smart_watch_crop.dart` | The first watch frame, with or without a subject box. |
| `lib/features/watch_set/data/` | The remembered watch type, the depth map subject box, the watch render. |
| `lib/features/watch_set/views/` | The row, the sheet, the crop screen and the guide. |
| `lib/features/ads/views/widgets/download_button.dart` | `DownloadSet`: the extra files saved in the same gate run. |

## Research

We did this research before we built the feature.

### Sources

- Apple Watch Series 11 tech specs: https://support.apple.com/en-us/125093
- Apple Watch Ultra 3 tech specs: https://support.apple.com/en-us/125095
- Apple Watch Series 12 tech specs: https://www.apple.com/apple-watch-series-12/specs/
- Apple Watch compare page: https://www.apple.com/watch/compare/
- Apple Watch SE 3 sizes (third party): https://devices.vodafone.com.au/apple/watch-se-3-watchos-26/specifications/
- Apple Watch Series 9 sizes (third party): https://devices.vodafone.com.au/apple/watch-series-9-watchos-11/specifications
- Apple Watch User Guide, Photos face: https://support.apple.com/guide/watch/customize-the-photos-watch-face-apd501eb33b3/watchos
- Apple Watch User Guide, sync a photo album: https://support.apple.com/guide/watch/choose-a-photo-album-and-manage-storage-apde3d82be52/watchos
- Apple Developer Forums, add-only access and albums: https://developer.apple.com/forums/thread/661196
- Pixel Watch, photo watch face: https://support.google.com/googlepixelwatch/answer/12662644
- Google Photos on Pixel Watch: https://support.google.com/photos/answer/12776450
- Pixel Watch 4 sizes (third party): https://www.gsmarena.com/google_pixel_watch_4-14088.php
- Samsung, change the watch face (My Photo+): https://www.samsung.com/sg/support/mobile-devices/how-to-change-watch-face-for-samsung-galaxy-watch/
- Samsung Galaxy Watch8 announcement with the spec table: https://news.samsung.com/global/samsung-galaxy-watch8-series-ultra-comfort-from-sleep-to-workout

### What we could not confirm

- If a share sheet from another app ever shows **Create Watch Face**. No Apple page says so. Prism has no iOS device in this build environment, so we did not check it.
- Pixel Watch pixel sizes from Google. Google gives only 320 ppi.
- The Apple Watch corner radius.

## Later: a watch app

A native watch app could do what this feature cannot:

- Put the image on a face with no steps: a watchOS app with a complication, or a Wear OS Watch Face Format face that reads images the phone sends.
- Send new walls every day, as the home widget does.
- Know the exact watch, so the user does not pick it.

Plan, if we do it:

1. Wear OS first. A Watch Face Format face with a photo slot, filled by the Data Layer API from the phone app. No code runs on the watch face.
2. watchOS: a small app with a complication and a gallery. watchOS does not let third-party apps make full-screen photo faces, so the face itself stays a Photos face.
3. Both need store review and a new build target. Measure `watch_set_saved` first. Build the watch app only if many users save sets.

## How to test

Automated tests:

- `test/features/watch_set/domain/watch_format_test.dart`: the size table and the mask maths.
- `test/features/watch_set/domain/smart_watch_crop_test.dart`: the smart crop with and without a subject box.
- `test/features/watch_set/data/depth_subject_box_test.dart`: the subject box from a depth map.
- `test/features/watch_set/views/`: the row with and without a desktop version, the remembered watch type, access for protected walls, one gate run per set, and large text.

Command: `fvm flutter test --no-pub test/features/watch_set`

Manual check:

1. Sign in. Open a Prism Studio wall that has a desktop version. Tap **Watch set**.
2. Pick a watch. Close the sheet. Open it again. The sheet does not ask again.
3. Tap **Adjust watch crop**. Move the frame. Tap **Done**.
4. Tap **Save set**. Make sure the confirm sheet shows the total of two downloads.
5. Open Photos (iOS) or Gallery (Android). Make sure there are three new images. Make sure the watch image has the size in the table.
