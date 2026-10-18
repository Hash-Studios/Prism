# Home feed

The Home tab shows a floating header, a carousel and a grid of wallpapers. Five text tabs under the top bar switch between the views: For you, Following, Trending, Latest and Popular. The feed paints from the disk cache at once and updates in the background.

## Where to find it

- The **Home** tab in the bottom bar (`PersonalizedFeedScreen`, `lib/features/personalized_feed/views/pages/personalized_feed_screen.dart`).
- Tap the selected **For you** tab (it has a small caret) to open the feed settings sheet. The **Tune your feed** button in the empty For you state opens it too.
- A long press on a tile opens the quick actions sheet. On the For you view it includes **Show less like this**.

## Platforms and plans

Android and iOS. The home feed has no premium or coin gate. The Following tab asks a guest to sign in. Every other tab works for a guest.

## How it works

| Path | Role |
|---|---|
| `lib/features/personalized_feed/views/pages/personalized_feed_screen.dart` | Floating header, carousel, grid, footer. Owns the tab controller and the lists of the other tabs. |
| `lib/features/personalized_feed/domain/entities/home_feed_chip.dart` | `HomeFeedChip`: the tabs and their labels, in tab order. |
| `lib/features/personalized_feed/views/widgets/home_feed_tab_bar.dart` | The five text tabs, the accent underline and the "Updating" bar. |
| `lib/features/navigation/views/widgets/prism_top_app_bar.dart` | The top bar row: avatar, wordmark, bell. |
| `lib/features/personalized_feed/views/widgets/feed_carousel.dart` | The carousel and its page dots. |
| `lib/features/personalized_feed/views/widgets/paged_chip_sliver.dart` | The grid, skeleton, empty, error and footer states of Latest, Following and Popular. |
| `lib/features/personalized_feed/views/widgets/trending_chip_sliver.dart` | The Trending tab: the This week and All time switch, then the grid. |
| `lib/features/personalized_feed/views/widgets/prefetch_tiles.dart` | Image prefetch for a new page. |
| `lib/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart` | For you state. Holds the selected tab. |
| `lib/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart` | Base bloc for a plain paged list. |
| `lib/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart` | Latest: newest reviewed Prism walls (`PrismWallpaperRepository.fetchFeed`). |
| `lib/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart` | Following: walls from followed creators. |
| `lib/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart` | Popular: most viewed walls. |
| `lib/features/personalized_feed/data/personalized_feed_repository_impl.dart` | Ranking, cache, `readCached`, `fetchFollowing`, `fetchPopular`. |
| `lib/features/personalized_feed/data/feed_impression_store.dart` | Shown counts and hidden walls. |
| `lib/features/trending/biz/bloc/trending_bloc.j.dart` | Trending lists. See [trending.md](trending.md). |
| `lib/features/navigation/views/widgets/bottom_nav_bar.dart` | Hosts the floating pill and the create button above the tab pages. |
| `lib/features/navigation/views/widgets/prism_bottom_nav.dart` | The pill with the four tab buttons. |
| `lib/features/navigation/views/widgets/prism_fab.dart` | The round create button with four layered rings. |

### Header

- The top bar has the profile picture on the left, the "prism" wordmark in the centre and the bell on the right. The picture opens the profile. The bell opens the notifications and shows a dot when something is unread. The wordmark does not respond to a tap.
- The top bar and the tabs form one floating header. It hides when the user scrolls down. It comes back when the user scrolls up.
- A strip the height of the status bar stays at the top. The status icons stay easy to read over the wallpapers.

### Tabs

The tabs sit under the top bar, in this order: For you, Following, Trending, Latest and Popular. An accent underline marks the selected tab. A thin line runs under the row.

- A tap on another tab shows its view and scrolls the list back to the top.
- A tap on the selected **For you** tab opens the feed settings sheet. This tab has a caret. Screen readers say "Double tap to open feed settings" for it.
- On a narrow screen, the row scrolls sideways. It fades out at the right edge while more tabs wait there.

| Tab | Source | Paging |
|---|---|---|
| For you | The ranked feed (six pools, ranked on the device). | Yes. |
| Following | New walls from the creators the user follows. | Yes, to 30 walls per 10 followed creators. |
| Trending | `trending/current` for This week, `popular/current` for All time (see [trending.md](trending.md)). | No. Up to 100 walls at once. |
| Latest | Newest reviewed Prism walls, 24 per page. | Yes. |
| Popular | The `popular/current` doc (see `popular-and-trending.md`). | One page. |

- The bloc keeps the selected tab, so the choice stays when the user changes tab in the bottom bar. The lists of the other tabs load the first time the user opens them.
- Following with nobody followed shows "Follow creators to see their new wallpapers here" and a **Find creators** button that opens user search.
- A guest on Following sees the sign-in prompt. The app does not read Firestore for a guest on this tab.
- Popular reads `popular/current` (`sourceTag` `popular.current`). It takes the first 40 ids and loads the walls 10 at a time (`popular.walls`). If the doc is missing or unreadable, it reads the 40 walls with most views from `wallpaper_stats` (`popular.stats`). The ids are upper case. Upload ids are upper case, so they match the `id` field of the wall.
- Trending shows a **This week | All time** switch above the grid. The grid has a "Boosted" tag on boosted walls. The first time the user opens the tab, the app loads **This week** and reports the `viewTrending` quest event. A tile sends the source context `home_trending_grid`. The tab sends no `surface_content_loaded` event. Details are in [trending.md](trending.md).
- Analytics: a tap on a tab sends `surface_action_tapped` with action `home_chip_selected` and context `home_chip_<name>`. The names are `forYou`, `following`, `trending`, `latest` and `popular`, so Trending gives `home_chip_trending`. The lists send `surface_content_loaded` with surface `home_latest_grid`, `home_following_grid` or `home_popular_grid`.

### Carousel

- The carousel shows on the For you tab only. It is as wide as the screen and 0.6 times as tall as it is wide. It has no side margin and square corners.
- The pages are the Wall of the Day (when there is one), the promo banner (when one is set) and the first 4 wallpapers of the feed.
- The page dots sit over the bottom of the image. They show when the carousel has more than one page.
- A wallpaper page has no caption. The banner and the Wall of the Day keep their text.

### Grid

- Every tab uses the same grid: 3 columns on a phone in portrait (a wider screen gets more), 2 px gaps on both axes, no side margin and square corners. A tile is twice as tall as it is wide.
- The Home grids pass `PrismFeedLayout.gridSpacing` to `PrismWallGrid.delegate` and set the tile `borderRadius` to zero.
- The other screens (search, categories, collections, favourites, profiles) keep the 8 px gap, the side margin and the rounded corners.

### Bottom bar

- The bar is a floating pill with four buttons: Home, Search, Rewards and Collections. The round create button sits next to it. It has four layered rings. The middle and the top ring turn slowly. The ring spins only while the tab is on screen and the user does not ask for reduced motion.
- The look is the one from before the 2026-09-30 redesign. It uses the theme colours.
- The pill and the create button hide when the user scrolls down. A round scroll-to-top button ("Scroll to top") shows in their place. A tap on it scrolls the list to the top.
- The create button has the screen reader label "Upload". It opens the Create sheet. A guest sees the sign-in pop up first.

### Instant home

1. On start, the bloc reads the cached first page (`readCached`, up to 24 items). It does not wait for the block list. It uses the blocked creators that the app already holds.
2. If the cache has items, the screen shows them at once. A thin progress bar with the label "Updating" shows on the line under the tabs.
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
- The first-load skeleton uses the same columns, tile ratio, gaps and square corners as the grid.
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
- The Trending tab does not page. It shows the whole list (up to 100 walls) at once.
- The tabs do not keep the scroll position. A tab starts at the top each time the user picks it.
- The Pexels path of the feed asks for 30 photos for each query. Category grids still ask for 80.

## How to test

1. Open the Home tab. Make sure the top bar shows your picture on the left, the "prism" wordmark in the centre and the bell on the right. Tap the wordmark. Make sure nothing happens.
2. Make sure the tabs For you, Following, Trending, Latest and Popular show under the top bar, with an accent underline under For you. Make sure the carousel runs edge to edge with page dots over the image, and that the wallpaper pages have no caption.
3. Scroll down. Make sure the top bar and the tabs slide away and the status bar strip stays. Make sure the bottom bar hides and a scroll-to-top button shows. Scroll up a little. Make sure the header and the bar come back. Scroll down again and tap the scroll-to-top button. Make sure the list goes to the top.
4. Make sure the grid has 3 columns, 2 px gaps, no side margin and square corners. Open Search. Make sure its grid keeps the 8 px gap and rounded corners.
5. Tap **Latest**, then **Popular**, then **For you**. Make sure each view shows wallpapers and the list starts at the top each time. Open another tab in the bottom bar and come back. Make sure the tab is still the one you chose.
6. Tap **Trending**. Make sure the **This week | All time** switch shows above the grid. Tap **All time**. Make sure a new list loads. Pull down to refresh. Make sure the list on screen reloads. Make sure a boosted wall has the "Boosted" tag.
7. Tap the selected **For you** tab. Make sure the feed settings sheet opens.
8. Sign in with an account that follows nobody. Tap **Following**. Make sure the empty text and **Find creators** show. Tap **Find creators**. Make sure user search opens.
9. Follow a creator who has wallpapers. Make sure **Following** lists them.
10. Close the app and open it again. Make sure the grid shows at once and a thin bar shows on the line under the tabs until the new page arrives.
11. Turn on airplane mode and open the app. Make sure the cached grid shows. Scroll to the end. Make sure the footer says "Couldn't load more. Try again". Turn the network on and tap it.
12. Long press a tile on For you. Tap **Show less like this**. Make sure the tile goes and **Undo** shows. Tap **Undo**. Make sure the tile comes back in the same place.
13. In Settings, turn the anime filter on or off. Go to Home. Make sure the feed reloads.
14. Make sure the create button in the bottom bar turns slowly. Tap it. Make sure the Create sheet opens.

Automated tests:

- `test/features/personalized_feed/biz/bloc/personalized_feed_bloc_test.dart`
- `test/features/personalized_feed/data/personalized_feed_repository_impl_test.dart`
- `test/features/personalized_feed/views/personalized_feed_screen_test.dart`
- `test/features/personalized_feed/views/home_feed_tab_bar_test.dart`
- `test/features/personalized_feed/views/feed_carousel_test.dart`
- `test/features/personalized_feed/views/feed_wall_tile_test.dart`
- `test/features/personalized_feed/views/feed_loading_more_test.dart`
- `test/features/personalized_feed/views/paged_chip_sliver_test.dart`
- `test/features/personalized_feed/views/prefetch_tiles_test.dart`
- `test/features/navigation/prism_top_app_bar_test.dart`
- `test/features/navigation/prism_bottom_nav_test.dart`
- `test/features/navigation/prism_fab_test.dart`
- `test/features/prism_feed/biz/bloc/paged_feed_bloc_test.dart`
- `test/core/widgets/home/loading_cards_test.dart`
- `test/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl_test.dart`
