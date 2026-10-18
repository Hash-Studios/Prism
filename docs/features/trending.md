# Trending

Trending shows the Prism wallpapers that people use most in the last 7 days. The backend builds the list every 3 hours. The all-time list is the **Popular** tab. See [home-feed.md](home-feed.md).

## Where to find it

- The **Trending** tab on the Home screen. It sits between **Following** and **Latest**. The grid starts right under the tab bar.
- The tab replaces the old home strip and the old Trending page. The `/trending` route is gone.
- Boosted walls also show in the carousel at the top of the **For you** tab, right after the Wall of the Day. See [Boosted walls](#boosted-walls).

## Platforms and plans

- Android and iOS. The code has no platform branch.
- Free. The tab and the detail screen have no coin or premium gate.

## How it works

| Path | Role |
|---|---|
| `lib/features/trending/data/repositories/trending_repository_impl.dart` | Reads the id list, loads the walls, and keeps the offline copy. |
| `lib/features/trending/biz/bloc/trending_bloc.j.dart` | Holds the week list. Events: `started`, `refreshRequested`, `blockedCreatorsChanged`. |
| `lib/features/personalized_feed/views/widgets/trending_chip_sliver.dart` | The Trending tab on Home: the grid. |
| `lib/features/personalized_feed/views/widgets/feed_carousel.dart` | Shows the boosted walls in the home carousel, after the Wall of the Day. |
| `lib/features/trending/views/widgets/boosted_tag.dart` | `BoostedTag`: the "Boosted" pill on a grid tile and on a carousel page. |
| `lib/features/personalized_feed/views/pages/personalized_feed_screen.dart` | Creates the bloc when the Home opens and keeps it. Reports the `viewTrending` quest event. |
| `functions/src/trending.ts` | Writes `trending/current` and `popular/current`. See [popular-and-trending.md](popular-and-trending.md). |

### Loading the list

1. The repository reads `trending/current`. The doc holds `wallIds`, best first, up to 100. The source tag is `trending.week.ids`.
2. It makes the ids upper case and removes repeats and blank ids.
3. It loads the walls from `walls` in batches of 30 ids. Each query asks for `review == true` and `id` in the batch. The source tag is `trending.week.walls`. The batches run at the same time.
4. It puts the walls back in the order of the id list.
5. It drops a wall that is missing, not reviewed, from a blocked creator, or has no image address.

The Wallhaven content filters do not apply. The lists hold only Prism wallpapers.

### Offline copy

After a good load, the repository saves the list in the feed cache. It saves an empty list too, so a list that went empty does not come back from the old copy. The cache source is `trending` and the scope is `week`. If a later load fails, the repository returns the saved list and hides creators that the user blocked since. A saved empty list gives an empty list. If there is no saved list at all, the load fails.

### Boosted walls

A boost puts an approved wall at the front of `trending/current.wallIds` for 24 hours (see [coin-economy-v2.md](coin-economy-v2.md)). The server keeps up to 10 live boosts, so the front of the list holds the boosted walls. A boosted wall shows in two places on the Home:

1. In the carousel on the **For you** tab, right after the Wall of the Day. The page has the "Boosted" tag and no caption. A tap opens the wallpaper detail screen.
2. First in the **Trending** tab, with the "Boosted" tag on its tile.

The app finds the boosted walls in the Trending list. A boosted wall is a wall of that list with `boostedUntil` in the future. The app keeps the order of the list and takes at most 10. The carousel and the For you grid show a boosted wall once: the grid skips it.

### The home tab

- The tab shows the walls of the week list in the home grid, with no switch above it. The grid has 3 columns on a phone in portrait, 4 px gaps, a 4 px side margin and rounded corners.
- The tab shows the whole list, up to 100 walls, with no paging. The boosted walls come first and have the "Boosted" tag.
- A tap on a tile opens the wallpaper detail screen with the wallpaper that the tab already loaded. A long press opens the quick actions. The analytics source context is `home_trending_grid`.
- The Home screen creates the bloc when it opens and sends `started`, which loads the list. The carousel needs the list for its boosted pages, so the load does not wait for the Trending tab. The Home screen keeps the bloc, so the tab and the carousel share one list.
- The bloc does not report a quest event. The Home screen reports the `viewTrending` quest event each time the Trending tab becomes the selected tab, the first visit included. Opening the Home alone reports nothing.
- Pull down to refresh the list. The old walls stay on screen while the new list loads. A pull down on the **For you** tab also refreshes the Trending bloc, so the boosted pages stay current.
- A first load shows the skeleton grid. An empty list shows "Nothing is trending yet". A failed first load shows "Couldn't load trending wallpapers" and a **Try again** button.
- When the user blocks a creator, the bloc removes that creator's walls from the list at once. When the user unblocks a creator, the bloc loads the list again if it was loaded.

## Limits

- Prism wallpapers only. Wallhaven and Pexels walls do not appear.
- The list changes every 3 hours at most. A new action can take that long to show.
- A list holds at most 100 walls. The tab shows all of them at once, with no paging.
- Only the Trending list feeds the carousel. A boosted wall that is not in that list does not show there.
- A wall that is hidden, rejected or from a blocked creator leaves a gap that the tab closes. A list can be shorter than 100.
- The home tab sends the tab tap (`home_chip_trending`) and the tile source context `home_trending_grid`. It sends no `surface_content_loaded` event yet.

## How to test

1. Run `fvm flutter test test/features/trending test/features/personalized_feed`.
2. Open the app with a signed-in test account. Tap the **Trending** tab on Home. Check that the grid starts right under the tab bar and that no switch shows above it.
3. Pull down to refresh. Check that the list reloads. Tap **Popular**. Check that it shows the all-time list, not the Trending list.
4. Turn on airplane mode after one good load. Close and open the app. Open the **Trending** tab. Check that it shows the saved list.
5. Block a creator that has a trending wall. Check that the wall is gone from the tab.
6. Boost an approved wall. Open the **For you** tab. Check that the Wall of the Day is the first carousel page and that the wall is the next page, with the "Boosted" tag and no caption. Check that the wall is not in the For you grid. Tap **Trending**. Check that the wall is the first tile, with the "Boosted" tag.
7. Open **Trending**, then **Latest**, then **Trending** again. Check that each visit to **Trending** reports the `view_trending` quest event. Open the Home and stay on **For you**. Check that the app reports no `view_trending` event.
