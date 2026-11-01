# Desktop companions

A desktop companion is a wide version of an approved Prism Studio wall. The server makes it from the same prompt and the same model as the wall. The web catalogue and the app both offer it. The app calls it **Desktop version**.

The server code is in `functions/src/studio/desktop.ts`. The backfill script is in `functions/src/scripts/backfillDesktopCompanions.ts`. The web pages are in `infra/cloudflare/worker/src/catalog.ts`.

## What it is

A companion has two files.

| File | Size | Use |
|---|---|---|
| Original | 2560 x 1600 (16:10) | The full desktop image. Tablets set it or save it. |
| Wide | 2560 x 1440 (16:9) | A centered crop of the original. |

The web downloads are smaller versions of these two files. See [web-catalogue.md](web-catalogue.md).

Only approved Prism Studio walls get a companion. Duo reveal walls are skipped. Creators cannot upload a desktop version yet. That is a later change.

## How it is made

The trigger is `onStudioWallDesktop`. It runs when a Studio wall is approved. It makes a companion only when `studioConfig/current.desktopCompanions` is `true`. The flag is off by default.

The server then does these steps.

1. The prompt changes. `DESKTOP_COMPOSITION` replaces the phone composition at the end of the prompt. The scene, the palette, the series style and the exclusions stay the same. A prompt without a known phone composition is skipped.
2. The server calls the wall model (`wall.aiModel`) through the Worker Studio route. The model must be one of these: GPT Image 2.5, Seedream 4.5 or Seedream 5 Lite. When the wall has a candidate seed, the server sends the same seed. GPT Image 2.5 has no seed. So its companion is a sibling of the wall, not a pixel match.
3. An output smaller than 2560 x 1600 is refused. The server never enlarges an image.
4. Cloud Vision checks safe search, text and logos. A flagged image is rejected.
5. The server stores the two files and the thumbnail, then links the companion to the wall.

Known limit. No human reviews a companion. The automatic checks decide. A companion appears on the wall when the checks pass.

## Storage and data

| Object or document | Access | Contents |
|---|---|---|
| `desktop-originals/<shareId>/<sha256>.jpg` | Private bucket | The original and the wide file. Each file has its own SHA-256. |
| `previews/desktop-<sha256>.jpg` | Public | The 960 x 600 thumbnail. |
| `desktopCompanions/{shareId}` | Server only | The manifest of the companion. |

The manifest holds `status`, `attempts`, `model`, `prompt`, `costUsd`, `original`, `wide`, `thumb` and `variant`. The `status` field has these values.

| Status | Meaning |
|---|---|
| `generating` | A run holds the claim and is making the companion. |
| `queued` | A transient error stopped the run. A later run retries it. |
| `deferred` | The Studio budget is used up. A later run retries it. |
| `ready` | The companion is linked to the wall. |
| `rejected` | A check failed. The companion is not retried. |
| `failed` | A permanent error stopped the run, or all attempts are used. The companion is not retried. |

The wall document holds `desktopVariant`, with `v`, `width`, `height`, `wideHeight` and `thumb`. The value of `v` is the first 16 characters of the original's SHA-256. A new original has a new `v`, so a cache never serves an old file. Only the server writes `desktopVariant`. The rules refuse client writes to it.

Deleting a wall deletes its companion. The server deletes the objects and the manifest.

## Spend and retries

- A companion gets at most 3 attempts (`STUDIO_MAX_ATTEMPTS`). After that, the status is `failed`.
- A Studio budget refusal sets the status to `deferred`. It does not use an attempt.
- The daily Studio cap is shared with the daily candidates. This change does not change the cap.

Cost per wall:

| Model | Model cost | Vision cost | Total |
|---|---|---|---|
| GPT Image 2.5 | $0.07 | $0.0045 | $0.0745 |
| Seedream 4.5 or Seedream 5 Lite | $0.04 | $0.0045 | $0.0445 |

## The backfill

Only a wall approved after the flag is `true` gets a companion from the trigger. Older walls need the backfill.

```sh
cd functions && npm run studio:desktop-backfill -- --limit=N
```

- A run without `--apply` is a dry run. It lists each wall and its cost. It calls no paid service. This is the default.
- `--apply` makes the companions and spends the Studio budget.
- `--limit=N` sets how many walls the run plans. The default is 25.
- `--start-after=<id>` resumes after a wall. The last line of a run prints `last=`, the id of the last wall that the run checked.

The run skips a wall that has a companion. It also skips a wall with a `rejected` or `failed` companion, and a wall that is not approved or not Studio. A second run does not pay twice. `--apply` needs `STUDIO_SECRET` and the R2 environment variables.

A dry run on 2026-11-01 read production. It scanned 167 Studio walls. 129 were eligible and 38 were not approved. The total cost is $9.61. With the $2 daily Studio budget, the backfill takes about 5 days. It competes with the daily candidates for the budget. The owner must agree before anyone runs `--apply`.

## Where users see it

On the web, the wall page has a Phone tab and a Desktop tab. The download links offer 1920 x 1200 and 1920 x 1080 files. The pages `/desktop-wallpapers` and `/matching-sets` list the walls that have a desktop version.

In the app, the wall detail shows a **Desktop version** chip when the wall has a companion. The chip opens a sheet with a preview. The sheet has **Send to my computer**, which shares the wall link. On tablets, the sheet gets the 2560 x 1600 original through `resolveOriginalAccess` with variant `desktop`. On Android, it sets the wallpaper. On iPad, it saves the file to Photos. The price is the same as the phone set.

## Limits

- Studio walls only. Duo reveal walls are skipped.
- No human review. The automatic checks decide.
- Creators cannot upload a desktop version yet.
- The GPT Image 2.5 companion is a sibling of the wall, not a pixel match.

## Deploy order

1. Deploy the Firestore rules: `firebase deploy --only firestore:rules`. This makes `desktopVariant` server-only.
2. Deploy the functions: `onStudioWallDesktop`, `wallpaperPreview`, `resolveOriginalAccess`, `onWallWebCatalog` and `buildWebCatalog`. Use `make functions-deploy`.
3. Run the backfill with `--apply`. Do this only with the owner's OK and the cost in this page.
4. Deploy the links Worker: `npx wrangler deploy` in `infra/cloudflare/worker`. The routes `/desktop-wallpapers*` and `/matching-sets*` are added. Set the `MIXPANEL_TOKEN` variable to the website's public Mixpanel token, so that downloads count. Then run `buildWebCatalog` with a force run.
5. Deploy the website. The header links to the desktop pages.

After these steps, set `studioConfig/current.desktopCompanions` to `true`. New approvals get a companion from then on.
