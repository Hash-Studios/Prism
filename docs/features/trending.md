# Trending

Trending shows the Prism wallpapers that people use most. It has two lists: **This week** and **All time**. The backend builds both lists every 3 hours.

## Where to find it

- The **Trending this week** row on the home feed. It sits under the carousel. Tap **See all** to open the page.
- The **Trending** page (`TrendingPage`, route `TrendingRoute`, path `/trending`). It has two segments, **This week** and **All time**.

## Platforms and plans

- Android and iOS. The code has no platform branch.
- Free. The row, the page and the detail screen have no coin or premium gate.

## How it works

| Path | Role |
|---|---|
| `lib/features/trending/data/repositories/trending_repository_impl.dart` | Reads the id list, loads the walls, and keeps the offline copy. |
| `lib/features/trending/biz/bloc/trending_bloc.j.dart` | Holds both lists. Events: `started`, `rangeSelected`, `refreshRequested`. |
| `lib/features/trending/views/widgets/trending_strip.dart` | The home row. |
| `lib/features/trending/views/pages/trending_page.dart` | The page with two segments. |
| `functions/src/trending.ts` | Writes `trending/current` and `popular/current`. See [popular-and-trending.md](popular-and-trending.md). |

### Loading a list

1. The repository reads `trending/current` for **This week** or `popular/current` for **All time**. Each doc holds `wallIds`, best first, up to 100. The source tags are `trending.week.ids` and `trending.allTime.ids`.
2. It makes the ids upper case and removes repeats and blank ids.
3. It loads the walls from `walls` in batches of 30 ids. Each query asks for `review == true` and `id` in the batch. The source tags are `trending.week.walls` and `trending.allTime.walls`. The batches run at the same time.
4. It puts the walls back in the order of the id list.
5. It drops a wall that is missing, not reviewed, from a blocked creator, or has no image address.

The Wallhaven content filters do not apply. The lists hold only Prism wallpapers.

### Offline copy

After a good load, the repository saves the list in the feed cache. It saves an empty list too, so a list that went empty does not come back from the old copy. The cache source is `trending` and the scope is `week` or `allTime`. If a later load fails, the repository returns the saved list and hides creators that the user blocked since. A saved empty list gives an empty list. If there is no saved list at all, the load fails.

### The home row

- The row shows up to 12 wallpapers, most trending first. A tap opens the wallpaper detail screen with the wallpaper that the row already loaded.
- The row stays hidden until the list loads. If the list is empty or the load fails, it stays hidden. It shows no error.
- The row loads when the home feed opens. Pull to refresh on the For you chip reloads it too.
- When the user blocks a creator, the bloc removes that creator's walls from both lists at once.

### The page

- **This week** loads when the page opens. **All time** loads the first time the user picks it. A later pick reuses the list.
- Pull down to refresh the list that is on screen. The old walls stay on screen while the new list loads.
- A first load shows a skeleton. An empty list shows "Nothing is trending yet". A failed first load shows "Couldn't load trending wallpapers" and a **Try again** button.
- A tile opens the wallpaper detail screen. A long press opens the quick actions. The analytics source context is `trending_grid`.

## Limits

- Prism wallpapers only. Wallhaven and Pexels walls do not appear.
- The lists change every 3 hours at most. A new action can take that long to show.
- A list holds at most 100 walls. The page shows all of them at once, with no paging.
- A wall that is hidden, rejected or from a blocked creator leaves a gap that the page closes. A list can be shorter than 100.
- The home row has no analytics events yet.

## How to test

1. Run `fvm flutter test test/features/trending`.
2. Open the app with a signed-in test account. Check that **Trending this week** shows under the carousel on the For you chip.
3. Tap **See all**. Check the two segments and the pull to refresh.
4. Turn on airplane mode after one good load. Close and open the app. Check that the row and the page still show the saved list.
5. Block a creator that has a trending wall. Check that the wall is gone from the row and the page.
