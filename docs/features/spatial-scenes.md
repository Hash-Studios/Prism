# Spatial Scenes

On iPhone 12 or later with iOS 26, the Lock Screen can turn a photo into a 3D Spatial Scene: the near parts move against the far parts as the phone tilts. Prism checks each wall with a depth model and stores how well it splits into near and far parts in `walls/{id}.spatial`. The app uses the value to point users at walls that make strong Spatial Scenes, and to preview the 3D effect before they save.

This is a different feature from the [Depth Effect](depth-effect.md), which puts the subject in front of the clock.

## Where to find it

- The search tab has a **Spatial** row below the Depth Effect row, on iOS and Android. It lists walls with tier `great`, then `ok`, newest first in each tier.
- In the wallpaper preview (the clock button on the detail screen), a wall with a depth map gets a **3D** toggle. With the toggle on, the wall tilts with the phone. With reduce motion on, or on a phone with no tilt sensor (the iOS Simulator), a drag tilts it instead.
- On iOS, a `great` or `ok` wall shows a **Spatial** tag on its grid tile (bottom end; the Depth tag sits at the bottom start) and a **Spatial Scene** row in the detail panel. The row opens a 3-step guide.
- On iOS, the save guide ends with the Spatial Scene step, and after the guide has shown once in a session, the save toast carries it. The Depth Effect tip wins when a wall has both.
- Android shows the 3D preview and the search row, but no tag, detail row or guide.

## Data

```ts
// walls/{id}.spatial
interface WallSpatial {
  tier: "great" | "ok" | "none";
  map: string; // public R2 URL of a grey 8-bit PNG, 512 px on the long side, bright is near
  v: number; // SPATIAL_VERSION, now 1
}
```

- A missing `spatial` field means that nobody checked the wall.
- Clients cannot write `spatial`. `firestore.rules` keeps it server and admin owned, like `depth`.
- Maps live in the public R2 preview bucket at `spatial/v1/<wallId>.png`, next to the wall previews.

## Detector

`functions/src/wallSpatial.ts`, `wallSpatialFor(wallId, {url} | {jpeg})`:

1. It accepts a wall URL only on https and on an allowed host (`checkedImageUrl` in `wallColors.ts`).
2. It sends the image to fal Depth Anything v2 (`fal-ai/image-preprocessors/depth-anything/v2`) with `FAL_API_KEY`. fal answers with a PNG on `*.fal.media`; any other host is an error.
3. It resizes the map to 512 px on the long side, makes it grey and stretches it to the full range.
4. It scores the split with Otsu's method: `split` (between-class variance over total variance), `gap` (near mean minus far mean) and `near` (share of near pixels). A smooth gradient has a split of 0.75.
5. It maps the score to a tier. The thresholds are a first guess to tune against real iPhones:

   | Tier | split | gap | near share |
   |---|---|---|---|
   | `great` | 0.85 or more | 0.4 or more | 0.08 to 0.65 |
   | `ok` | 0.78 or more | 0.28 or more | 0.04 to 0.8 |

6. It stores the map in R2 and returns `{tier, map, v}`. On any failure it logs a warning and returns undefined, so the wall keeps no field and a backfill can try again.

`onWallCategorize` runs it for each new wall (Studio walls too) that has no `spatial` field, next to the depth check. It writes `spatial` only when the wall still has none.

## Preview

`lib/features/wallpaper_detail/views/widgets/spatial_tilt_view.dart` draws the wall with `shaders/spatial_tilt.frag`. The shader reads the map decoded at 128 px wide, shifts each pixel by at most 2.5% of the image, and zooms in by the same amount so no edge shows. Two texture reads per pixel.

The tilt comes from the `prism/tilt` event channel: CoreMotion attitude on iOS (`ios/Runner/PrismTiltStream.swift`), the rotation-vector sensor on Android (`PrismTiltStream.kt`). The view listens only while the preview is open and the app is in front.

## Backfill

```sh
cd functions && npm run build
FAL_API_KEY=<key> node lib/scripts/backfillWallSpatial.js --limit=50                              # dry run, stores nothing
FAL_API_KEY=<key> <R2 env> node lib/scripts/backfillWallSpatial.js --limit=10 --map-prefix=spatial-test/v1  # dry run, maps to a test prefix
FAL_API_KEY=<key> <R2 env> node lib/scripts/backfillWallSpatial.js --apply                        # writes spatial
```

- A dry run writes nothing to Firestore and, without `--map-prefix`, nothing to R2. It still calls fal for every wall it checks.
- `--apply` with `--map-prefix` is refused, so test URLs never reach Firestore.
- It skips walls with `spatial.v` at the current version. `--force` checks them again. `--limit`, `--batch` and `--start-after` work like the depth backfill.

## Cost

fal bills Depth Anything v2 at $0.00125 per compute second. One call took 3 to 4 seconds end to end in the sample run, so a wall costs at most about $0.005.

## Limits

- An open depth model only approximates Apple's own. iOS can refuse a `great` wall or accept a `none` wall.
- The tiers do not know about the clock. A wall whose near part sits under the clock still scores well.
