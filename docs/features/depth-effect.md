# Depth Effect

On iOS 16 and later, the Lock Screen can put the subject of a photo in front of the clock. Apple calls this the Depth Effect. Prism checks each wall and stores how iOS treats it in `walls/{id}.depth`. The app reads this value to tell iPhone users which walls work with the Depth Effect.

## Where to find it

- On iOS, a wall that works shows a **Depth** tag on its grid tile and a **Depth Effect** row in the detail panel.
- On iOS, the search tab has a **Depth Effect** row above Browse by colour, and the search filter sheet has a **Depth Effect** switch. Both list the walls with tier `auto` or `menu`.
- On iOS, the save guide ends with the step that turns the effect on. After the guide has shown once in a session, the save toast carries that step.
- In swipe review, admins see the tier on each card and can set Auto, Menu or None.
- The backend writes the value. There is no backend screen.

## Platforms and plans

- The backend checks every wall. Only the iOS app shows the result.
- Free. No coin or premium gate.

## How it works

### The iOS rules

These rules and numbers come from decompiled iOS 18.2 and iOS 26.1 code. iOS turns on the Depth Effect only when all four rules are true:

1. The iOS segmenter makes a subject mask. It makes one only for people, pets (cats and dogs), and scenes with sky.
2. More than 2% of the mask pixels have a value of 0.6 or higher.
3. The mask touches the clock box.
4. The mean mask value over the top 75% of the clock box is at most T. The bottom 25% band of the box has no limit.
   - `T_AUTO = 0.2 * boxHeight / boxWidth`, about 0.041. At or below this value, iOS turns on the Depth Effect by itself.
   - `T_MENU = T_AUTO + 0.25 * (1 - T_AUTO)`, about 0.281. At or below this value, the user can turn it on: tap ••• in the Lock Screen editor, then **Depth Effect**.

The clock box on an iPhone 15 Pro (screen 393 x 852 pt) is x 27.5 to 365.5 pt and y 190 to 260 pt. That is 22% to 31% down the screen. The default wallpaper crop is an aspect-fill centre crop to the screen shape.

### Data

```ts
// walls/{id}.depth
interface WallDepth {
  tier: "auto" | "menu" | "none";
  kind: "person" | "pet" | "sky" | null; // the subject class, in iOS order person > pet > sky
  top: number | null; // mean mask value over the top 75% of the clock box, 3 decimals; null when no mask was made
  v: number; // DEPTH_VERSION, now 1
  by: "detector" | "admin";
}
```

- A missing `depth` field means that nobody checked the wall.
- The detector writes `by: "detector"`. An admin can replace the value with `by: "admin"`. No backend code replaces an admin value.
- Clients cannot write `depth`. `firestore.rules` keeps it server and admin owned.

### Tiers in the app

The app reads only `depth.tier`.

| Tier | iOS app |
|---|---|
| `auto` | **Depth** tag. Detail row: "Your subject sits in front of the clock." |
| `menu` | **Depth** tag. Detail row: "In the Lock Screen editor, tap ••• then Depth Effect." |
| `none` or no field | No tag and no row. |

Client files: `lib/core/wallpaper/wall_depth.dart`, `lib/core/widgets/depth_tag.dart`, `lib/features/wallpaper_detail/views/widgets/depth_effect_row.dart`.

### Detector

| Path | Role |
|---|---|
| `functions/src/wallDepth.ts` | The geometry, the kind table, the mask score, the Vision and fal calls, and `wallDepthFor`. |
| `functions/src/onWallCategorize.ts` | Checks each new wall. |
| `functions/src/studio/gates.ts`, `functions/src/studio/process.ts` | The depth gate of the Studio Depth Effect series. |
| `functions/src/scripts/backfillWallDepth.ts` | Checks walls that exist now. |

`wallDepthFor(wallId, {url} | {jpeg})` does these steps:

1. It accepts a wall URL only on https and on an allowed host (`ALLOWED_IMAGE_HOSTS` in `wallColors.ts`).
2. It sends one Vision call with `LABEL_DETECTION` (20 results) and `OBJECT_LOCALIZATION` (10 results).
3. It finds the subject kind. The first match wins:

   | Kind | Matches |
   |---|---|
   | `person` | Object Person, Man, Woman, Boy, Girl, Baby or Toddler, score 0.5 or higher |
   | `pet` | Object Dog or Cat, score 0.5 or higher, or label Dog or Cat, score 0.7 or higher |
   | `sky` | Label Sky, Cloud, Horizon or Skyline, score 0.7 or higher |

4. If no kind matches, it returns `{tier: "none", kind: null, top: null}` and does not call fal. Most walls stop here, so this step keeps the cost low.
5. It gets a subject mask from fal BiRefNet (`fal-ai/birefnet`, model "General Use (Light)", 1024x1024, `sync_mode`). The mask comes back as a base64 data URI. Any other answer is an error. The timeout is 60 seconds. For JPEG bytes (Studio), the image goes to fal as a data URI.
6. It crops the mask to the screen shape (aspect-fill, centre), scales it to 393 x 852, and applies rules 2 to 4.
7. If any step fails (Vision, fal, an empty `FAL_KEY`, bad data), it logs a warning with the wall id and returns undefined. The wall keeps no `depth` field, so a backfill can try again.

### New walls

`onWallCategorize` checks each new wall that has no `depth` field. It uses `wallpaper_url`, or `wallpaper_thumb` when there is no `wallpaper_url`. The check runs at the same time as the colour step.

`writeDepthIfAbsent` saves `depth` in its own transaction. It writes only when the wall still has no `depth`. So an admin value that was set during the check stays. The update of `colors` and `category` runs after the depth write. If the depth write fails, the function logs a warning. The failure does not block the update of `colors` and `category`.

### Studio Depth Effect series

- The series `depth-effect` ("Depth Effect") in `functions/src/studio/series.ts` has `depth: true`. It has 6 subjects: 2 people seen from the chest up, a cat, a dog, a mountain peak and a tower.
- Its prompts use `STUDIO_DEPTH_COMPOSITION`: the top of the subject sits 24% to 30% down the frame, the subject fills the frame below, and the area above is calm open sky.
- `processStudioCandidate` runs `wallDepthFor` on the 1600 px JPEG that the Vision gate uses.
- The gate rejects tier `none` with the reason `depth`. The values go into `gates.details.depth`.
- A check that cannot run (Vision, fal or an empty `FAL_KEY`) throws. The candidate goes back to the queue and tries again, up to 3 attempts, like a Vision error.
- A wall that passes gets `depth` when the pipeline creates it, so `onWallCategorize` does not check it again.

### Backfill

```sh
cd functions && npm run build
FAL_KEY=<key> node lib/scripts/backfillWallDepth.js --limit=50        # dry run of 50 walls
FAL_KEY=<key> node lib/scripts/backfillWallDepth.js --apply           # writes depth
FAL_KEY=<key> node lib/scripts/backfillWallDepth.js --apply --start-after=<wallId>   # resume
```

- The script reads reviewed walls in document id order, 4 at a time. It prints one line for each wall (id, tier, kind, top), the last id of each batch, and the tier and kind counts at the end.
- A dry run writes nothing, but it still calls Vision and fal. It costs money.
- It skips walls with `depth.v` at the current version. `--force` checks them again. `--limit=N` stops after N checked walls. `--batch=N` sets the page size (1 to 500, default 100).
- It never changes a wall with `depth.by == "admin"`, also with `--force`. Each write has a precondition on the read time, so a wall that changed during the run is not written. Run the script again to pick it up.
- It needs Application Default Credentials for project `prism-wallpapers`.

### Cost

- Each check uses 2 Vision units (labels and objects).
- A wall with a person, pet or sky also uses one fal BiRefNet call. fal bills it by compute time.

## Limits

- An open model (BiRefNet) and Vision labels only approximate Apple's segmenter. A tier can be wrong for some walls. An admin can fix a value with `by: "admin"`.
- The geometry is the iPhone 15 Pro clock. Other iPhones have a slightly different box.
- iOS 26 and later can use a tall clock, which tolerates more overlap. The tiers follow the standard clock, so they can be strict on iOS 26.
- On iOS 16 to 18, widgets under the clock turn off the Depth Effect.
- A user who moves or zooms the wall in the Lock Screen editor changes the result.

## How to test

- `cd functions && npm run build && node --test 'lib/__tests__/*.test.js'`. The depth tests are in `wallDepth.test.ts`, `studioGates.test.ts` and `studioProcess.test.ts`.
- After deploy, run the backfill dry run with `--limit=50`. Set 3 `auto` walls and 3 `menu` walls on an iPhone. Make sure that iOS puts the subject in front of the clock by itself for `auto`, and from the ••• menu for `menu`.

## Sources

- Decompiled iOS 18.2 (iPhone17,1, build 22C152): https://github.com/EthanArbuckle/iPhone17-1_18.2_22C152_Restore. Files `PFParallaxLayoutNumericTextOverlapParameters.m`, `PISegmentationHelper.m` and `PUParallaxLayerStackViewModel.m`.
- fal BiRefNet: https://fal.ai/models/fal-ai/birefnet
