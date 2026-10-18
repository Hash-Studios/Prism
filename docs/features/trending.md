# Trending

Trending shows the Prism wallpapers that people use most. It has two lists: **This week** and **All time**. The backend builds both lists every 3 hours.

## Where to find it

- The **Trending** tab on the Home screen. It sits between **Following** and **Latest**. It has two segments at the top, **This week** and **All time**.
- The tab replaces the old home strip and the old Trending page. The `/trending` route is gone.

## Platforms and plans

- Android and iOS. The code has no platform branch.
- Free. The tab and the detail screen have no coin or premium gate.

## How it works

| Path | Role |
|---|---|
| `lib/features/trending/data/repositories/trending_repository_impl.dart` | Reads the id list, loads the walls, and keeps the offline copy. |
| `lib/features/trending/biz/bloc/trending_bloc.j.dart` | Holds both lists. Events: `started`, `rangeSelected`, `refreshRequested`. |
| `lib/features/personalized_feed/views/widgets/trending_chip_sliver.dart` | The Trending tab on Home: the segments, then the grid. |
| `lib/features/personalized_feed/views/pages/personalized_feed_screen.dart` | Creates the bloc the first time the user opens the tab. |
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

### The home tab

- The tab shows the **This week | All time** segments, then the walls of the chosen list in the home grid. The grid has 3 columns on a phone in portrait, 2 px gaps, no side margin and square corners.
- The tab shows the whole list, up to 100 walls, with no paging. A boosted wall has the "Boosted" tag.
- A tap on a tile opens the wallpaper detail screen with the wallpaper that the tab already loaded. A long press opens the quick actions. The analytics source context is `home_trending_grid`.
- The bloc starts the first time the user opens the tab, not when the Home screen opens. The `started` event loads **This week** and reports the `viewTrending` quest event. The Home screen keeps the bloc, so a later visit to the tab does not report it again.
- **All time** loads the first time the user picks it. A later pick reuses the list.
- Pull down to refresh the list that is on screen. The old walls stay on screen while the new list loads.
- A first load shows the skeleton grid. An empty list shows "Nothing is trending yet". A failed first load shows "Couldn't load trending wallpapers" and a **Try again** button.
- When the user blocks a creator, the bloc removes that creator's walls from both lists at once.

## Limits

- Prism wallpapers only. Wallhaven and Pexels walls do not appear.
- The lists change every 3 hours at most. A new action can take that long to show.
- A list holds at most 100 walls. The tab shows all of them at once, with no paging.
- A wall that is hidden, rejected or from a blocked creator leaves a gap that the tab closes. A list can be shorter than 100.
- The home tab sends the tab tap (`home_chip_trending`) and the tile source context `home_trending_grid`. It sends no `surface_content_loaded` event yet.

## How to test

1. Run `fvm flutter test test/features/trending test/features/personalized_feed`.
2. Open the app with a signed-in test account. Tap the **Trending** tab on Home. Check that the **This week | All time** segments show above the grid.
3. Tap **All time**. Check that a new list loads. Pull down to refresh. Check that the list on screen reloads.
4. Turn on airplane mode after one good load. Close and open the app. Open the **Trending** tab. Check that it shows the saved list.
5. Block a creator that has a trending wall. Check that the wall is gone from the tab.
