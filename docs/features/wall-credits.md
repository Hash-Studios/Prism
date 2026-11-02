# Wall credits

Every wall shows one credit row in the detail info panel. The row names the source of the wall. It opens the creator, the studio or the photo source. The row also shows a short label, such as "Prism exclusive" or "From Pexels".

## Where to find it

| Surface | What the user sees |
|---|---|
| Wall detail, info panel | One credit row. It shows the source of the wall. |
| Creator wall | "By <name>", the creator avatar and the second line "Prism exclusive". A tap opens the creator profile. |
| Studio wall | "By Hash Studios" and the second line "Prism exclusive". A tap opens the Prism Studio profile. |
| Pexels wall | "Photo by <name>" and the second line "From Pexels". A tap opens the photographer page. |
| Wallhaven wall | "By <name>" and the second line "From Wallhaven". A tap opens the Wallhaven user page. |

## Platforms and plans

Android and iOS. Every plan sees the credit row. No coin, premium or Pro gate applies.

## How it works

### Provenance

Each wall has one source. The app reads the source and shows the matching row.

| Source | Row | Tap target |
|---|---|---|
| `creator` | "By <name>", the avatar, "Prism exclusive" | The creator profile. |
| `studio` | "By Hash Studios", "Prism exclusive" | The Prism Studio profile (uid `prism-studio`). |
| `pexels` | "Photo by <name>", "From Pexels" | The photographer page. Only http and https links open. |
| `wallhaven` | "By <name>", "From Wallhaven" | `wallhaven.cc/user/<name>`. |

- AI walls that a creator uploaded are creator walls.
- "Prism exclusive" is derived in the app from the wall source. No stored field holds it.
- The app builds the row in `lib/features/wallpaper_detail/views/widgets/wall_credit_row.dart`.
- The domain type is in `lib/features/wallpaper_detail/domain/entities/wall_credit.dart`.

### Studio field

The app cannot read the Studio candidate docs that `isStudioWall` checks. So the server stores the flag on the wall.

- `walls.byStudio` is a server field.
- `onWallApproved` writes `byStudio: true` when `isStudioWall` is true.
- The client reads `byStudio` to choose the Studio row.

### Backfill

Walls approved before `byStudio` existed need the backfill.

- The script is `functions/src/scripts/backfillWallStudio.ts`.
- The dry run is the default. It writes nothing.
- The `--apply` flag writes the field.
- Run the dry run first. Get the owner's OK before `--apply`.

Build the functions first. Then run the dry run:

```sh
cd functions && npm run build && node lib/scripts/backfillWallStudio.js
```

Run the write only with the owner's OK:

```sh
cd functions && npm run build && node lib/scripts/backfillWallStudio.js --apply
```

The script needs Application Default Credentials for project `prism-wallpapers`.

## Data

| Path or field | Writer | Contents |
|---|---|---|
| `walls.byStudio` | Server only (`onWallApproved`, backfill) | `true` for a Studio wall. |

Firestore rules refuse client writes of `byStudio`. The field is in `wallServerKeysAbsent` and `wallServerKeysUntouched`.

## Limits

- The Studio row depends on `byStudio`. Older Studio walls have no `byStudio` field until the backfill runs.
- "Prism exclusive" is a rule in the app. A new source needs an app change.
- The Pexels tap opens only http and https links. Other links do not open.

## How to test

1. Open a creator wall. Check the "By <name>" row and the "Prism exclusive" line. Tap the row. Check that the creator profile opens.
2. Open a Studio wall. Check the "By Hash Studios" row. Tap it. Check that the Prism Studio profile opens.
3. Open a Pexels wall. Check the "Photo by <name>" row and the "From Pexels" line. Tap it. Check that the photographer page opens in the browser.
4. Open a Wallhaven wall. Check the "By <name>" row and the "From Wallhaven" line.
5. Run `fvm flutter test test/features/wallpaper_detail`.
6. Run the backfill dry run. Check the log for the count of walls it would change. Do not run `--apply` without the owner's OK.

## Related

- [editors-choice.md](editors-choice.md) for the Editors' Choice label on the same info panel.
- [backend-deploy.md](backend-deploy.md) for the deploy order.
