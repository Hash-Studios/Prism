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

The screen reads two capabilities from the `async_wallpaper` plugin.

| Capability | Plugin field | What it enables |
|---|---|---|
| Shaders | `supportsOpenGlLiveWallpaper` | Make it live and Gradients |
| Video | `supportsLiveWallpaper` | Video |

- If both are false, the screen shows "Live wallpapers are not available".
- If only one is false, that mode shows "Not available on this device".
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

Prism follows the plugin validator (`ShaderProgramValidator.kt` in `async_wallpaper` 3.3.0).

| Rule | Value |
|---|---|
| Language | GLSL ES 1.00, with `precision mediump float;` |
| Uniforms Prism uses | `u_time` (float), `u_resolution` (vec2), `u_touch` (vec2), `u_offset` (vec2), `u_texture0` (sampler2D) |
| Loops | No `while`. Only `for` with integer literal bounds. |
| Source size | Under 64 KiB. Prism constant `LiveShaderSources.maxBytes`. |
| Plugin limits | Up to 4 textures, 32 uniform declarations, 128 static loop iterations. Prism uses at most one texture. |

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
| `previewOpened` or `awaitingUserConfirmation` | "Confirm in the system preview." |
| `cancelled` | No message. |
| `unsupported` | "This device cannot show live wallpapers." |
| `foregroundRequired` | "Keep Prism open and try again." |
| `failed` | A message chosen by error code. The mapper has a default: "Could not set the live wallpaper. Try again." |

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
