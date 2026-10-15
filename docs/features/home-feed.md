# Home feed

The Home tab shows a carousel and a grid of wallpapers. A chip rail under the "For you" title switches between four views: For you, Latest, Following and Popular. The feed paints from the disk cache at once and updates in the background.

## Where to find it

- The **Home** tab in the bottom bar (`PersonalizedFeedScreen`, `lib/features/personalized_feed/views/pages/personalized_feed_screen.dart`).
- The tune icon next to the "For you" title opens the feed settings sheet.
- A long press on a tile opens the quick actions sheet. On the For you view it includes **Show less like this**.

## Platforms and plans

Android and iOS. The home feed has no premium or coin gate. A guest sees For you and Latest. The Following chip asks a guest to sign in.

## How it works

| Path | Role |
|---|---|
| `lib/features/personalized_feed/views/pages/personalized_feed_screen.dart` | Carousel, title, chip rail, grid, footer. Owns the chip lists. |
| `lib/features/personalized_feed/views/widgets/home_chip_rail.dart` | The pinned chip rail (`ChoiceChip`s). |
| `lib/features/personalized_feed/views/widgets/paged_chip_sliver.dart` | The grid, skeleton, empty, error and footer states of Latest, Following and Popular. |
| `lib/features/personalized_feed/views/widgets/prefetch_tiles.dart` | Image prefetch for a new page. |
| `lib/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart` | For you state. Holds the selected chip. |
| `lib/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart` | Base bloc for a plain paged list. |
| `lib/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart` | Latest: newest reviewed Prism walls (`PrismWallpaperRepository.fetchFeed`). |
| `lib/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart` | Following: walls from followed creators. |
| `lib/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart` | Popular: most viewed walls. |
| `lib/features/personalized_feed/data/personalized_feed_repository_impl.dart` | Ranking, cache, `readCached`, `fetchFollowing`, `fetchPopular`. |
| `lib/features/personalized_feed/data/feed_impression_store.dart` | Shown counts and hidden walls. |

### Chip rail

| Chip | Source | Paging |
|---|---|---|
| For you | The ranked feed (six pools, ranked on the device). | Yes. |
| Latest | Newest reviewed Prism walls, 24 per page. | Yes. |
| Following | New walls from the creators the user follows. | Yes, to 30 walls per 10 followed creators. |
| Popular | The `popular/current` doc (see `popular-and-trending.md`). | One page. |

- The bloc keeps the selected chip, so the choice stays when the user changes tab. The lists of the other chips load the first time the user opens them.
- Following with nobody followed shows "Follow creators to see their new wallpapers here" and a **Find creators** button that opens user search.
- A guest on Following sees the sign-in prompt. The app does not read Firestore for a guest on this chip.
- Popular reads `popular/current` (`sourceTag` `popular.current`). It takes the first 40 ids and loads the walls 10 at a time (`popular.walls`). If the doc is missing or unreadable, it reads the 40 walls with most views from `wallpaper_stats` (`popular.stats`). The ids are upper case. Upload ids are upper case, so they match the `id` field of the wall.
- Analytics: a tap on a chip sends `surface_action_tapped` with action `home_chip_selected` and context `home_chip_<name>`. The lists send `surface_content_loaded` with surface `home_latest_grid`, `home_following_grid` or `home_popular_grid`.

### Instant home

1. On start, the bloc reads the cached first page (`readCached`, up to 24 items). It does not wait for the block list. It uses the blocked creators that the app already holds.
2. If the cache has items, the screen shows them at once. A thin progress bar with the label "Updating" shows under the title.
3. The bloc loads page 1 in the background. When it arrives, it replaces the cached list. If the first wallpaper changed and the user had scrolled down, the list jumps to the top.
4. If the load fails, the cached items stay and the bar goes away.

The analytics context of the first load tells the cases apart: `personalized_feed_initial` (no cache), `personalized_feed_initial_cache_hit` and `personalized_feed_initial_cache_stale` (the cache is older than 2 hours).

### Offline and cache

- The cache keeps the first 48 items. Pages 1 and 2 write it. Later pages do not.
- The write does not block the feed.
- The cache stores the Wallhaven content filter (categories and purity). If the filter changed since the write, the app drops the cached Wallhaven items when it reads the cache.
- Only page 1 falls back to the cache when the network fails. A later page that fails shows "Couldn't load more. Try again". The feed does not say "You're caught up" in that case.
- A failed pull to refresh keeps the items, shows a toast, and does not stop the automatic loading of the next page.

### Content filters

When the user changes the anime or sketchy filter, `personalizedFeedSettingsRevision` goes up by 1. The feed drops its items, shows skeletons and loads page 1 again.

### Show less like this

- The row is in the quick actions sheet of the For you grid. The wallpaper leaves the grid at once. A bar shows "Got it. You'll see fewer like this." with **Undo**.
- **Undo** puts the wallpaper back in its place and removes the hide (`FeedImpressionStore.unhide`).

### Impressions

The app counts a wallpaper as shown when its tile is first built, not when its page loads. The bloc batches the keys and writes them once a second, and once more when the screen closes. A wallpaper that the user never scrolled to is not counted.

### Scrolling

- The scroll view keeps 1.5 screens of tiles ready beyond the viewport.
- When a page arrives, the app starts loading the thumbnails of its first 6 new items at the grid decode height. A low data setting will turn this off (see Limits).
- The first-load skeleton uses the same columns and tile ratio as the grid.
- The carousel turns pages by itself only when the user does not ask for reduced motion, the tab is on screen, and no screen covers the feed.
- The carousel tiles decode at the carousel height, not at full size.

## Limits

- Popular is all time until the scheduler `computeTrending` has run once. After that, it follows `popular/current`. Without the doc the list can differ from the all time list of `wallpaper_stats`.
- Popular shows walls whose `id` field is upper case. Other walls drop out of the list.
- Following does not page by cursor. Page N loads the first N pages again from Firestore, up to 30 walls for each group of 10 followed creators.
- Undo does not remove the "fewer like this" taste signal. It only shows the wallpaper again.
- Latest uses the same page cursor as the other readers of `PrismWallpaperRepository.fetchFeed`.
- The image prefetch ignores the low data setting for now. The feed checks a placeholder that is always off. The Data saver setting will replace it.
- Only the For you view has Show less like this and the "Updating" bar.
- The Pexels path of the feed asks for 30 photos for each query. Category grids still ask for 80.

## How to test

1. Open the Home tab. Make sure the chips For you, Latest, Following and Popular show under the title.
2. Tap **Latest**, then **Popular**, then **For you**. Make sure each view shows wallpapers. Open another tab and come back. Make sure the chip is still the one you chose.
3. Sign in with an account that follows nobody. Tap **Following**. Make sure the empty text and **Find creators** show. Tap **Find creators**. Make sure user search opens.
4. Follow a creator who has wallpapers. Make sure **Following** lists them.
5. Close the app and open it again. Make sure the grid shows at once and a thin bar shows under the title until the new page arrives.
6. Turn on airplane mode and open the app. Make sure the cached grid shows. Scroll to the end. Make sure the footer says "Couldn't load more. Try again". Turn the network on and tap it.
7. Long press a tile on For you. Tap **Show less like this**. Make sure the tile goes and **Undo** shows. Tap **Undo**. Make sure the tile comes back in the same place.
8. In Settings, turn the anime filter on or off. Go to Home. Make sure the feed reloads.

Automated tests:

- `test/features/personalized_feed/biz/bloc/personalized_feed_bloc_test.dart`
- `test/features/personalized_feed/data/personalized_feed_repository_impl_test.dart`
- `test/features/personalized_feed/views/personalized_feed_screen_test.dart`
- `test/features/personalized_feed/views/prefetch_tiles_test.dart`
- `test/features/prism_feed/biz/bloc/paged_feed_bloc_test.dart`
- `test/core/widgets/home/loading_cards_test.dart`
- `test/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl_test.dart`
