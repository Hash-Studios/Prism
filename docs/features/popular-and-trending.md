# Popular and trending

The backend counts what users do with a wallpaper. Two scheduled lists, `trending` and `popular`, rank wallpapers from those counts. This page covers the backend only. The app does not read the counters or the lists yet.

## Where to find it

There is no screen. The data lives in Firestore.

| Item | Path |
|---|---|
| Action counter callable `recordWallpaperAction` | `functions/src/wallStats.ts` |
| Favourite trigger `onFavouriteWritten` | `functions/src/wallStats.ts` |
| Daily view counter | `functions/src/viewStats.ts` (`bumpDaily`) |
| Scheduler `computeTrending` | `functions/src/trending.ts` |
| Rules | `firestore.rules` (`trending`, `popular`) |
| TTL policies | `firestore.indexes.json` (`fieldOverrides`) |

## Platforms and plans

Android and iOS share the same backend. Every plan counts the same. The counters are display data. No coin, premium or subscription code reads them.

## How it works

### Counters

`recordWallpaperAction({wallId, action})` takes `action` of `download`, `set` or `share`. The caller must be signed in. The wall id uses the same rules as `recordWallpaperView`: trimmed, upper case, letters, digits, `.`, `_` and `-`.

| Step | Detail |
|---|---|
| Dedupe | One doc `wallActionRate/{uid}_{ID}_{action}` per user, wall and action. It holds `lastAt` and `expireAt` (24 hours). A second call inside 24 hours returns `{counted: false}`. |
| Total | `wallpaper_stats/{ID}` gets `downloads`, `sets` or `shares` plus 1, and `lastEventAt`. |
| Per day | `wallpaper_stats_daily/{yyyymmdd}_{ID}` gets `{wallId, day, <counter>, expireAt}`. `expireAt` is 14 days out. |
| Views | `recordWallpaperView` also adds 1 to `views` in the daily doc. |
| Favourites | `onFavouriteWritten` runs on `usersv2/{uid}/images/{wallId}`. A new doc adds 1 to `wallpaper_stats.favs`. A deleted doc takes 1 away, never below 0. It counts only docs with provider `Prism`. A new favourite also adds 1 to `favs` in the daily doc. |

The callable runs with `maxInstances: 10`. It never gives coins.

### Lists

`computeTrending` runs every 3 hours (`0 */3 * * *`, UTC).

| List | Doc | Score |
|---|---|---|
| Trending | `trending/current` | For each of the last 7 UTC days: `sets*3 + downloads*2 + favs*2 + shares*2 + views`, times `0.8` for each day of age. Sum over the days. |
| Popular | `popular/current` | `sets*3 + downloads*2 + favs*2 + views` from `wallpaper_stats`. It reads the 500 walls with most views, then sorts by score. |

Each doc holds `wallIds` (the top 100, best first) and `updatedAt`. The ids are the upper case keys of `wallpaper_stats`. Both docs are public to read. Only the function writes them.

## Limits

- Backend only. No client code sends actions or reads the lists. Counts start when a client sends them.
- The ids are upper case stats keys. The client must match them to the wall `id` field with a case-insensitive match.
- Wall ids can collide for old walls (4 random characters). Colliding walls share one counter.
- `popular` reads only the 500 walls with most views. A wall with many sets and few views can miss the list.
- A retried favourite trigger can count a favourite twice. The count is display data.
- The job reads at most 50,000 daily docs per run and logs a warning at the cap.

## How to test

1. Run `cd functions && npm run build && node --test 'lib/__tests__/wallStats.test.js' 'lib/__tests__/trending.test.js' 'lib/__tests__/viewStats.test.js'`.
2. Run the rules smoke test (`make rules-test`). Signed-out reads of `trending/current` and `popular/current` return 200. A user write returns 403.
3. After a deploy, call `recordWallpaperAction` twice from a signed-in test account. The first call returns `{counted: true}`. The second returns `{counted: false}`. Check `wallpaper_stats/<ID>` and `wallpaper_stats_daily/<day>_<ID>` in the console.
4. Run `computeTrending` from the Cloud Scheduler console. Check `trending/current` and `popular/current`.
