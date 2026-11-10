# Live wallpapers

Live wallpapers let the user move a wallpaper. The screen has three modes: Make it live (animate one photo), Gradients (animated colour), and Video (play a clip on the home screen).

## Where to find it

- Settings, section PERSONALISE, row "Live wallpapers". It opens the screen with no photo, so only Gradients and Video show. Code: `lib/features/session/views/pages/settings_screen.dart`.
- Wallpaper detail screen, button "Make it live", and the small "Live" chip over the wallpaper. Both open the screen with the wallpaper `fullUrl`, so all three modes show. Code: `lib/features/wallpaper_detail/views/widgets/make_it_live_button.dart`.

The detail button shows only when two things are true:

- `AsyncWallpaper.getCapabilities()` reports `supportsOpenGlLiveWallpaper`.
- The detail screen shows the set-wallpaper UI and the wallpaper has a non-empty `fullUrl`.

## Platforms

| Platform | Status |
|---|---|
| Android | Supported when the device reports the capabilities below. |
| iOS | Not available. The Settings row shows on Android only. |

The screen reads three capabilities from the `async_wallpaper` plugin.

| Capability | Plugin field | What it enables |
|---|---|---|
| Shaders | `supportsOpenGlLiveWallpaper` | Make it live and Gradients |
| Video | `supportsLiveWallpaper` | Video |
| Tilt | `supportsTilt` | Sensor input for 3D only |

- If shader and video support are both false, the screen shows "Live wallpapers are not available".
- If shader or video support is false, that mode shows "Not available on this device".
- If the capability call throws, Prism treats the device as not supported.

## Free and Pro

| Mode | Free | Pro |
|---|---|---|
| Make it live | Drift | Drift, Breathe, Ripple, Shimmer |
| Gradients | Aurora, Mesh | Aurora, Mesh, Waves, Plasma, Starfield |
| Video | Yes | Yes |

- A free user can select a Pro style. A lock icon shows on the chip and the main button reads "Unlock with Prism Pro".
- When the free user taps the button, the paywall opens (`PaywallPlacement.mainUpsell`, source `live_wallpaper_screen`). Prism then reads `app_state.prismUser.premium` again.
- The gate lives in the bloc. The bloc refuses a locked style and returns `proRequired`.
- The Settings row itself is not gated.

## How it works

| Path | Role |
|---|---|
| `lib/features/live_wallpaper/views/pages/live_wallpaper_screen.dart` | Route `LiveWallpaperRoute({String? imageUrl, Color? accentSeed})`. Creates the bloc and sends `started`. |
| `lib/features/live_wallpaper/views/widgets/live_wallpaper_view.dart` | Mode chips, style pickers, colour swatches, battery saver switch, apply bar. |
| `lib/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart` | State, Pro gate, apply events. |
| `lib/features/live_wallpaper/data/repositories/live_wallpaper_repository_impl.dart` | Capability call, plugin requests, frame rates, video size limit. |
| `lib/features/live_wallpaper/data/shaders/live_shader_sources.dart` | Shader text and colour templating. |
| `lib/features/live_wallpaper/data/live_texture_preparer.dart` | Downloads the photo and writes a screen-shaped JPEG. |
| `lib/features/live_wallpaper/data/texture_geometry.dart` | Crop and size maths for the texture. |
| `lib/features/live_wallpaper/data/live_apply_outcome_mapper.dart` | Maps plugin results to user messages. |
| `lib/features/live_wallpaper/domain/entities/live_style.dart` | Style names, descriptions, free flags. |
| `lib/features/live_wallpaper/domain/entities/live_palette.dart` | Four colours and a background from a seed colour. Also the seed and its three variants for the swatch row. |

Data path:

```text
Apply button -> LiveWallpaperBloc -> Pro gate
  -> repository -> (photo only) texture JPEG
  -> AsyncWallpaper.setOpenGlLiveWallpaper / setVideoWallpaper
  -> Android system preview -> user taps Set wallpaper
```

### Make it live

- Styles: Drift (slow pan and zoom, follows home screen swipes), Breathe, Ripple, Shimmer.
- The photo is texture `u_texture0`. The screen shows a static preview of the photo. It does not run the shader in Flutter.
- The preparer downloads the photo with a 30 second timeout, through `PrismFullImageCache.instance` (60 files, 7 days). It crops to the screen aspect ratio and writes `live_wallpaper_texture.jpg` (quality 90) in the temporary directory.

### Living gradients

- Styles: Aurora, Mesh, Waves, Plasma, Starfield.
- Colours come from a seed colour. `LivePalette.fromAccent` builds four colours and a background. The shader text receives them as `vec3` constants.
- The seed is the route argument `accentSeed`. The wallpaper detail screen can pass the dominant colour of the wallpaper. When there is no `accentSeed`, the seed is the theme accent (`ColorScheme.primary`).
- A row of four swatches shows under the style description in the Gradients tab. The first swatch is the seed. The other three are the seed with the hue shifted by 38, -42 and 180 degrees (`LivePalette.seedVariants`). A tap on a swatch changes the preview and the colours that Prism sends to the plugin. Each swatch has a screen reader label such as "Gradient colour 2 of 4". The first swatch is selected when the screen opens.
- The Make it live tab uses the same seed for its palette.
- Starfield stays pure black for all themes (see `test/features/live_wallpaper/live_shader_sources_test.dart`).
- The gradient preview in Flutter is a plain gradient, not the shader.

### Video to wallpaper

- The user picks a video with `ImagePicker().pickVideo`.
- Prism sets it with `AsyncWallpaper.setVideoWallpaper`, then calls `openLiveWallpaperPreview`.
- The request uses the plugin defaults: target home and scale mode `centerCrop`.
- The screen text says the video plays on the home screen with the sound off.

### Shader contract

Prism follows the plugin validator (`ShaderProgramValidator.kt` in `async_wallpaper` 3.6.0).

| Rule | Value |
|---|---|
| Language | GLSL ES 1.00, with `precision mediump float;` |
| Uniforms Prism uses | `u_time` (float), `u_resolution` (vec2), `u_touch` (vec2), `u_offset` (vec2), `u_tilt` (vec2, 3D only), `u_texture0` and `u_texture1` (sampler2D) |
| Loops | No `while`. Only `for` with integer literal bounds. |
| Source size | At most 64 KiB of UTF-8 source, enforced by the plugin validator. |
| Plugin limits | Up to 4 textures, 32 uniform declarations, 128 static loop iterations. Prism uses at most two textures, for 3D. |
| Texture orientation | `texture2D(u_texture0, v_uv)` shows the image upright. Do not flip `v_uv.y`. Plugin versions before 3.5.0 showed it upside down. |

### Frame rate and battery saver

| Setting | Frame rate |
|---|---|
| Default | 30 |
| Battery saver on | 15 |

The plugin accepts 1 to 60 frames per second and its own default is 60. The switch shows in Make it live and Gradients. It does not show in Video.

### Limits on files

| Limit | Value | Where it comes from |
|---|---|---|
| Texture encoded size | 8 MiB | Plugin. Prism constant `TextureGeometry.maxEncodedBytes`. |
| Texture side | 4096 px | Plugin. |
| Texture pixels | 4 MiB pixels in the plugin | Plugin. Prism keeps below it. |
| Prism texture height | 2400 px at most | `TextureGeometry.maxOutputHeight`. |
| Prism texture pixels | 3,500,000 at most | `TextureGeometry.maxOutputPixels`. |
| Video size | 256 MB | `LiveWallpaperRepositoryImpl.maxVideoBytes`. |

Prism resizes the photo to fit these limits. If the JPEG is still over 8 MiB, the screen shows "That wallpaper is too detailed to animate." If the video is over 256 MB, the screen shows "That video is larger than 256 MB. Pick a shorter clip."

### Apply results

| Plugin result | User message |
|---|---|
| `applied` | "Live wallpaper set." |
| `previewOpened`, Android 16 with a screen picked | "In the preview, tap Set wallpaper, then Home screen." (or Lock screen, or Home screen and lock screen) |
| `previewOpened`, Android 15 or older (`effectiveTarget: both`) | "Confirm in the system preview. This phone shows the same live wall on both screens." |
| `previewOpened` or `awaitingUserConfirmation` for video | "Confirm in the system preview." |
| `cancelled` | No message. |
| `unsupported` | "This device cannot show live wallpapers." |
| `foregroundRequired` | "Keep Prism open and try again." |
| `failed` | A message chosen by error code. The mapper has a default: "Could not set the live wallpaper. Try again." |

## A different live wall on each screen (Android 16)

### What Android 16 adds

Android 16 (API 36) adds two classes for live wallpapers. One wallpaper service can then show different content on the Home Screen and the Lock Screen.

| API | What it does |
|---|---|
| [`WallpaperDescription`](https://developer.android.com/reference/android/app/wallpaper/WallpaperDescription) | Describes one instance of a live wallpaper: an id, a title, and a `PersistableBundle` of content. |
| [`WallpaperInstance`](https://developer.android.com/reference/android/app/wallpaper/WallpaperInstance) | Pairs a `WallpaperInfo` with a `WallpaperDescription`. |
| [`WallpaperService.onCreateEngine(WallpaperDescription)`](https://developer.android.com/reference/android/service/wallpaper/WallpaperService#onCreateEngine(android.app.wallpaper.WallpaperDescription)) | The system creates the engine for a screen with the description it saved for that screen. |
| [`Engine.onApplyWallpaper(int which)`](https://developer.android.com/reference/android/service/wallpaper/WallpaperService.Engine#onApplyWallpaper(int)) | A picker calls it on the preview engine when the user sets Home, Lock, or both. The engine returns the description to save. |
| [`Engine.getWallpaperFlags()`](https://developer.android.com/reference/android/service/wallpaper/WallpaperService.Engine#getWallpaperFlags()) (API 34) | Tells an engine which screen it draws: `FLAG_SYSTEM` (Home), `FLAG_LOCK`, or both. |

Source: [Android 16 features and APIs](https://developer.android.com/about/versions/16/features).

### What an app can and cannot do

- An app cannot set a live wallpaper on one screen by itself. `WallpaperManager.setWallpaperComponentWithDescription` and `setWallpaperComponentWithFlags` are not in the public SDK. In the Android 16 source they need `SET_WALLPAPER_COMPONENT`, a system permission. Only the system picker holds it.
- So the user always confirms the screen in the system preview. Prism opens it with `ACTION_CHANGE_LIVE_WALLPAPER`.
- The system flag `android.app.Flags.liveWallpaperContentHandling` turns the description API on. The public API 36 SDK ships it, so release builds have it on. An OEM build can turn it off.

### Which pickers support it

| Picker | Handles `ACTION_CHANGE_LIVE_WALLPAPER` | Calls `onApplyWallpaper` | Source |
|---|---|---|---|
| AOSP Live Wallpaper Picker (`com.android.wallpaper.livepicker`), Android 16 | Yes | No. It calls `setWallpaperComponentWithFlags(component, which)`. | [`LiveWallpaperPreview.java`](https://android.googlesource.com/platform/packages/wallpapers/LivePicker/+/refs/heads/android16-release/src/com/android/wallpaper/livepicker/LiveWallpaperPreview.java) |
| AOSP Wallpaper & style (`WallpaperPicker2`), Android 16 | No | Yes, for wallpapers the user picks inside it. | [`WallpaperConnectionUtils.kt`](https://android.googlesource.com/platform/packages/apps/WallpaperPicker2/+/refs/heads/android16-release/src/com/android/wallpaper/util/wallpaperconnection/WallpaperConnectionUtils.kt) |
| Pixel (Google builds of the two pickers) | Not verified on a device. | Not verified. | |
| Samsung One UI 8, other OEMs | Not verified. OEM pickers may offer only some screens. | Not verified. | |

The Android 16 emulator image (Pixel 9, API 36) uses the AOSP Live Wallpaper Picker. Its Set wallpaper button offers "Home screen", "Lock screen", and "Home screen and lock screen".

Because the stock picker never calls `onApplyWallpaper`, a description alone does not separate the screens. `async_wallpaper` 3.7.0 therefore does two things:

1. Each running engine reads its screen with `getWallpaperFlags()` and that screen's id with `WallpaperManager.getWallpaperId()`. Android issues a new id each time the user sets a screen. A new id means "this screen was just set", so the engine takes the content Prism staged for the preview. An id the engine saw before means a restart, so it keeps that screen's content.
2. A picker that does call `onApplyWallpaper` gets a `WallpaperDescription` that carries the shader, frame rate, texture folder, and content tag. The engine for that screen then reads its own description.

Verified on the API 36 emulator: a cool shader on Lock and a warm shader on Home show at the same time, and each stays after the other changes.

### In Prism

- When `supportsPerScreenLiveWallpaper` is true, Make it live and Gradients show "Where to set it" above the main button: Home screen, Lock screen, Both. Both is the default. Video never shows it.
- When it is false, the screen looks the same as before. Prism sends the plugin default target, Home.
- Prism tags every shader apply with `prism.live:<motion|gradient>:<style>:<apply id>`. When the app comes back from the system preview, it calls `getLiveWallpaperScreens()` and finds the screens that carry this apply's tag.
- If at least one screen got it, a card above the main button says what each screen shows, for example "Home screen: Aurora. Lock screen: Ripple." The text is a live region for screen readers.
- If only one screen got it, the card offers "Pick a wall for the Lock screen" (or Home screen). From a wall, it goes back so the user can open another wall; the next Live screen opens with that screen picked. From Settings, it stays and picks that screen, so the user can choose another gradient.
- If no screen got it (the user backed out of the preview), Prism says nothing.
- The Pro and coin gates are unchanged. Every apply goes through them, whatever screen is picked.
- Analytics: `live_wallpaper_applied` adds `target` (null for video), `per_screen`, and `fallback`.

### Release order

The Prism change needs `async_wallpaper` 3.7.0. Do these steps in this order:

1. Merge the plugin PR: https://github.com/codenameakshay/async_wallpaper/pull/89.
2. Publish `async_wallpaper` 3.7.0 to pub.dev. The plugin owner must approve this step.
3. Run `fvm flutter pub get` in Prism to update `pubspec.lock` to 3.7.0. Then merge the Prism PR: https://github.com/Hash-Studios/Prism/pull/818.

Until step 2 is done, `pub get` fails in Prism CI, because pub.dev does not have 3.7.0.

### Older Android

On Android 15 (API 35) and lower, all live wallpaper engines share the last content Prism applied. The plugin reports `effectiveTarget: both`, and Prism tells the user that both screens use the same live wall.

## 3D

3D is a photo live style. The photo moves in depth. Near parts shift against far parts.

- Mode: Make it live only.
- Where it shows: only for walls whose Firestore doc has `walls/{id}.spatial.map`. This is the depth map from Spatial Scenes. It is a grey PNG on R2, 512 px on the long side. Bright is near. Without a map, the chip does not show.
- Cost: a paid style, like Breathe, Ripple and Shimmer. It is free for Prism Pro users. Other users can unlock it with coins. The style id is `depth`.

Textures:

- `u_texture0` is the photo. `u_texture1` is the depth map.
- `LiveTexturePreparer.prepareWithDepth` crops the depth map with the same crop as the photo. `TextureGeometry.scaledTo` maps the photo crop onto the map size. A different crop makes the subject ghost.

Shader (`LiveShaderSources.motion(MotionStyle.depth, ...)`):

- The uv shifts by `(depth - 0.5) * strength * motion`.
- `motion` adds three inputs. Home page swipes (`u_offset.x`). A small touch nudge (`u_touch`). A slow idle drift. The result clamps to -1 to 1.
- The photo zooms about 4%. The shift never shows an edge.
- The source marks `strength` and `drift` with `ponytail:`. Tune these first on a device.

Tilt:

- async_wallpaper 3.6.0 adds the `u_tilt` uniform and `WallpaperCapabilities.supportsTilt`.
- Prism declares `u_tilt` and adds it to motion only when `supportsTilt` is true.
- Prism uses `async_wallpaper ^3.6.0`. `supportsTilt` is false on iOS and on Android devices without a game rotation vector or accelerometer. Then the shader has no `u_tilt`.

Frame rate: 30 fps. With battery saver, 15 fps.

Preview:

- The in-app preview uses `SpatialTiltView` from Spatial Scenes. It shows the same photo and depth map.
- On a phone, the preview follows tilt. With reduce motion or no sensor, a drag tilts it.

Analytics: `live_wallpaper_applied` sends `style: 3d`.

Tilt support ships in async_wallpaper 3.6.0. Prism requires `^3.6.0` and resolves 3.6.0 in `pubspec.lock`.

## Limits

- Android opens its own preview. The user must tap Set wallpaper there. The bottom of the screen says so.
- Once the system preview is open, Android owns the result. The plugin cannot detect a cancel (plugin 3.3.0 changelog).
- Flutter previews are static. The screen never shows the real shader or video motion before the user applies it.
- Make it live needs the photo to download within 30 seconds.
- Shader compile and link depend on the device driver. A device can fail with "This device could not start that style. Try another one."
- Without fragment `highp`, `u_time` is `mediump` and gets coarse after long runs. The shaders wrap it with `loopTime()`, but the plugin must also wrap `u_time` on the native side. This is a plugin follow-up. The `mediump` grain and starfield hash have not run on a GLES2 device.
- The route only receives `accentSeed` when the caller passes it. A caller that passes nothing gets the theme accent.
- Analytics: `live_wallpaper_applied` has the fields `style` and `result`. `style` is the motion, gradient or video name (for example `ripple`, `aurora`, `video`). `result` is the outcome name (`applied`, `confirmInPreview`, `cancelled`, `failed`, `unsupported`). The bloc sends it after each apply. It sends nothing when a Pro style is refused.
- No device run was done for this page. Real playback, battery use, and the system preview need a device.

## How to test

1. Use an Android phone. Open Prism as a free user.
2. Open Settings, then "Live wallpapers". Make sure the screen opens on Gradients and has no Make it live chip.
3. Select Aurora. Tap "Set live wallpaper". Make sure Android opens a preview and tap Set wallpaper there.
4. Select Waves. Make sure a lock icon shows and the button reads "Unlock with Prism Pro". Tap it and make sure the paywall opens.
4a. Open Gradients. Make sure four colour swatches show. Tap the third swatch and make sure the preview changes colour. Apply and make sure the colours match.
5. Turn on Battery saver. Make sure the text reads "15 frames per second".
6. Open a wallpaper. Tap "Make it live". Select Drift and apply it. Select Breathe and make sure it is locked.
7. Open the Video chip. Tap "Choose a video", pick a short clip, and tap "Set live wallpaper".
8. Pick a video over 256 MB. Make sure the error message names the 256 MB limit.
9. Repeat step 2 on iOS. Make sure the "Live wallpapers" row does not show.
10. Repeat steps 3 and 6 as a Pro user. Make sure no style has a lock.

Automated tests:

- `test/features/live_wallpaper/live_shader_sources_test.dart`
- `test/features/live_wallpaper/shader_contract.dart` (helper for the shader tests)
- `test/features/live_wallpaper/texture_geometry_test.dart`
- `test/features/live_wallpaper/live_apply_outcome_mapper_test.dart`
- `test/features/live_wallpaper/live_wallpaper_bloc_test.dart`
- `test/features/live_wallpaper/live_wallpaper_repository_test.dart`
- `test/features/live_wallpaper/live_wallpaper_view_test.dart`
- `test/features/live_wallpaper/live_texture_preparer_test.dart`
- `test/features/wallpaper_detail/views/widgets/wallpaper_detail_widgets_test.dart` (the "Make it live" button)

Command:

```sh
fvm flutter test --no-pub test/features/live_wallpaper
```

## Creator live walls

A creator can upload a short looping MP4. The video is the live wall. Its poster is a still image of the first frame. Feeds show a Live badge and play a silent preview. Android can set the video as a live wallpaper. iOS cannot use a video as a wallpaper.

To upload a live wall, see [upload.md](upload.md#live-walls).

### Data

| Field | Written by | Meaning |
|---|---|---|
| `kind` | Creator, on create | `live` for a live wall. `still`, or no value, means a still wall. |
| `live.video`, `live.videoPath`, `live.videoSha` | Creator, on create | The MP4 URL, its repo path and its blob SHA. |
| `live.frames` | Creator, on create | Three moderation frames. They show the start, the middle and the end. Each frame has `url`, `path` and `sha`. |
| `live.durationMs`, `live.width`, `live.height`, `live.codec`, `live.bytes`, `live.loop` | Server | Facts read from the MP4 headers. `loop` is `true` after a check. |
| `live.verified` | Server | `true` when the server proves every file. |
| `live.error` | Server | The reason for a failed check. Present only when `verified` is `false`. |
| `wallpaper_url`, `wallpaper_thumb` | Creator | The poster. The poster is the still image of the first frame. |

The server replaces the `live` map after its check (`verifyLiveWall` in `functions/src/wallLive.ts`). The rules allow the creator to write `kind` and the client keys of `live` only on create (`validLiveCreate` in `firestore.rules`).

### Old clients

Old clients read the poster in `wallpaper_url`. They show it as a still wall, and they can set it as a still wallpaper.

Old clients list only walls with `review == true`. A live wall uses the same gate. The rules refuse `review == true` until the server verifies the video (`liveReviewOk` in `firestore.rules`). So a live wall is public only when its video is proven.

### Video limits

| Limit | Value | Checked on the device | Checked on the server |
|---|---|---|---|
| Container | MP4. QuickTime files are refused. | `inspectLiveVideo` in `lib/features/wallpaper_upload/biz/live_upload_limits.dart` | `inspectLiveVideo` in `functions/src/liveVideo.ts` |
| Codec | H.264, in an `avc1` or `avc3` sample entry. | Same as above | Same as above |
| Duration | 15 seconds at most. | Same as above. The picker also stops at 15 seconds. | Same as above |
| Size | 20 MB at most. | `prepareLiveVideo` in `lib/features/wallpaper_upload/data/live_video_preparer.dart` | `githubPutFile` in `functions/src/githubContent.ts` |
| Orientation | Portrait. Height is more than width. | Same as above | Same as above |
| Display size | 1440 × 3200 pixels at most. Track rotation counts. | Same as above | Same as above |

The device reads the MP4 box headers. The server also reads the SPS sizes and the AVC configuration. It checks the sample tables against the track. It does not decode the video.

### Surfaces

| Surface | What the user sees | Code |
|---|---|---|
| Home and collection grids | Live badge. One silent preview plays at a time. | `lib/features/category_feed/views/widgets/wallpaper_tile.dart`, `lib/features/category_feed/views/widgets/collections_view_grid.dart`, `lib/core/widgets/live_tag.dart` |
| Search and Wall of the Day archive | Live badge over the poster. No preview. | `lib/features/user_search/views/widgets/search_grid.dart`, `lib/features/wall_of_the_day/views/pages/wotd_archive_page.dart` |
| Wall detail | Plays muted and loops. Pauses off screen. A pause button shows. | `lib/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart`, `lib/core/widgets/live_wall_video.dart` |
| Reduced motion or data saver | Feed shows the poster only. Detail shows the poster with a play button. | `lib/core/widgets/live_wall_video.dart` |
| Review queue | Plays even with reduced motion or data saver. Shows "Checking the video" or "The video failed the server check" until the check passes. | `lib/features/admin_review/views/widgets/swipe_wallpaper_card.dart` |
| Folders, smart Folders and favourites | The poster. No badge and no preview. Smart Folder items copy `kind` and `live`. | `lib/features/favourite_walls/data/favourite_wall_doc_mapper.dart`, `functions/src/smartFolders.ts` |
| Profile | The poster. No badge and no preview. | `lib/features/public_profile/domain/public_profile_snapshot_codec.dart` |
| Push images | The poster. | `functions/src/onWallApproved.ts` |
| iOS widgets | The cached still image. | `ios/PrismLiveActivities/PrismWidgets.swift` |
| Share cards | The still image. | `lib/core/share/share_sheet.dart` |
| Web catalogue | The poster. The web app has no live code. | `web/` |

### Set a live wall

- On Android, the **Set live wallpaper** button downloads the MP4. Then it opens the system preview through `LiveWallpaperRepository.applyVideo`. The user taps **Set wallpaper** there. While the video downloads, the button shows "Getting the video" and is disabled, like **Save video**, so a tap or a screen reader does not report an action that does nothing. Code: `LiveSetButton` in `lib/features/wallpaper_detail/views/widgets/live_wall_actions.dart`.
- On iOS, the wall detail shows a note under the actions. The note says that iPhone cannot use a video as a wallpaper. The action bar has two options.
  - **Set poster as wallpaper** saves the poster to Photos, like the Save button of a still wall.
  - **Save video** saves the MP4 to Photos. Code: `LiveSaveVideoButton` and `LiveIosNote` in `lib/features/wallpaper_detail/views/widgets/live_wall_actions.dart`.
- The Live Photo export is hidden for live walls. So are the **Make it live** button and chip. Live Photo animates one still image. It cannot use the creator's video.

### Memory

- The feed holds one video player at a time. The slot is `_feedSlot` in `lib/core/widgets/live_wall_video.dart`.
- A feed card closes its player when the card leaves the screen.
- A detail page or review card pauses its player when it leaves the screen.
- A player that does not close frees its slot after 2 seconds (`LiveWallVideo.releaseBudget`).

### Analytics

| Event | Fields |
|---|---|
| `live_wall_upload_started` | None |
| `live_wall_submitted` | `duration_ms` |
| `live_wall_preview_played` | `surface`: `feed`, `detail` or `review` |
| `live_wall_set` | `platform`, `action` and `result`. Android sends `action` `live`. iOS sends `poster` or `video`. |

### Limits and known gaps

- The creator makes the poster and the frames on the device. A creator can upload clean frames for a bad video. The admin must watch the clip before approval.
- The server checks the H.264 structure. It does not decode the video.
- Uploads that never become a wall stay in R2 while the account is active. The owner must decide a retention rule. Deleting the account removes them (`tombstoneUnreferencedLiveUploads` in `functions/src/wallLive.ts`).
- iOS users with an HEVC clip must export H.264 first. The app does not transcode.

### Deploy order

Nothing is deployed for creator live walls. Each step needs owner approval.

1. Deploy the Firestore rules.
2. Run `make functions-env`. New functions get the R2 variables only from `functions/.env`.
3. Deploy these functions.
   - `githubPutFile` and `githubDeleteFile`. The memory of `githubPutFile` rises from 256 MiB to 512 MiB. Deploy it after the asia-south1 CPU quota PR.
   - `onWallSubmitted` and `onWallModerate`. `onWallSubmitted` now retries, and its memory rises to 512 MiB. Deploy it after the asia-south1 CPU quota PR.
   - `onOwnedWallWritten` and `onR2TombstoneCleanup`.
   - `releaseScheduledWalls`.
   - `planWeeklyDrop`, `sendDropPushes`, `setDropTitle` and `unlockDrop`.
   - `deleteAccount`.
   - `rejectWallForReview`, `undoWallRejection`, `submitWallResubmission` and `getWallResubmissionContext`.
   - The smart Folder functions: `createSmartFolder`, `updateSmartFolderRules`, `previewSmartFolder`, `onWallSmartFolders` and `onSmartFollowWritten`.
   - `onRejectedLiveWallDeleted`. This function is new and runs in asia-south1. Deploy it only after the asia-south1 CPU quota PR.
4. Release the app.

### How to test

- Local QA harness: see [tool/live_walls_qa/README.md](../../tool/live_walls_qa/README.md).
- Functions tests, run with `cd functions && npm run build && node --test 'lib/__tests__/*.test.js'`:
  - `functions/src/__tests__/liveVideo.test.ts`
  - `functions/src/__tests__/wallLive.test.ts`
  - `functions/src/__tests__/githubContent.test.ts`
  - `functions/src/__tests__/wallModeration.test.ts`
  - `functions/src/__tests__/onWallSubmitted.test.ts`
  - `functions/src/__tests__/wallRelease.test.ts`
  - `functions/src/__tests__/drops.test.ts`
  - `functions/src/__tests__/r2Storage.test.ts`
- Rules smoke test: `tool/firestore_rules_smoke.mjs`. It has live wall fixtures.
- Dart tests, run with `fvm flutter test --no-pub` and the file paths below:
  - `test/core/widgets/live_wall_video_test.dart`
  - `test/core/widgets/live_wall_video_lifecycle_test.dart`
  - `test/core/widgets/live_tag_test.dart`
  - `test/features/wallpaper_upload/live_upload_limits_test.dart`
  - `test/features/wallpaper_upload/live_video_preparer_test.dart`
  - `test/features/admin_review/live_review_card_test.dart`
  - `test/features/wallpaper_detail/live_wall_actions_test.dart`
  - `test/features/wallpaper_detail/live_video_download_test.dart`
  - `test/features/prism_feed/data/mappers/prism_wall_live_mapper_test.dart`
