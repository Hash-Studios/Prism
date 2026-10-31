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
| `lib/features/personalized_feed/views/pages/personalized_feed_screen.dart` | Floating header, carousel, grid, footer. Owns the tab controller, the Trending bloc and the lists of the other tabs. |
| `lib/features/personalized_feed/domain/entities/home_feed_chip.dart` | `HomeFeedChip`: the tabs and their labels, in tab order. |
| `lib/features/personalized_feed/views/widgets/home_feed_tab_bar.dart` | The five text tabs, the accent underline and the "Updating" bar. |
| `lib/features/navigation/views/widgets/prism_top_app_bar.dart` | The top bar row: avatar, wordmark, bell. |
| `lib/features/personalized_feed/views/widgets/feed_carousel.dart` | The carousel and its page dots. |
| `lib/features/personalized_feed/views/widgets/paged_chip_sliver.dart` | The grid, skeleton, empty, error and footer states of Latest, Following and Popular. |
| `lib/features/personalized_feed/views/widgets/trending_chip_sliver.dart` | The Trending tab: the week list in the grid. |
| `lib/features/personalized_feed/views/widgets/prefetch_tiles.dart` | Image prefetch for a new page. |
| `lib/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart` | For you state. Holds the selected tab. |
| `lib/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart` | Base bloc for a plain paged list. |
| `lib/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart` | Latest: newest reviewed Prism walls (`PrismWallpaperRepository.fetchFeed`). |
| `lib/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart` | Following: walls from followed creators. |
| `lib/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart` | Popular: most viewed walls. |
| `lib/features/personalized_feed/data/personalized_feed_repository_impl.dart` | Ranking, cache, `readCached`, `fetchFollowing`, `fetchPopular`. |
| `lib/features/personalized_feed/data/feed_impression_store.dart` | Shown counts and hidden walls. |
| `lib/features/trending/biz/bloc/trending_bloc.j.dart` | Trending list. The Trending tab and the carousel share it. See [trending.md](trending.md). |
| `lib/features/trending/views/widgets/boosted_tag.dart` | `BoostedTag`: the "Boosted" pill. Used on the Trending tiles and on the boosted carousel pages. |
| `lib/features/moods/domain/entities/wall_mood.dart` | `WallMood`: the Home moods, their ids and the iOS version each one needs. |
| `lib/features/moods/biz/moods_cubit.dart` | The moods for this device. `rowMoodsFor` picks the two moods for the grid rows. |
| `lib/features/moods/biz/mood_walls_cubit.dart` | The walls of one mood, in the order of the user's taste. |
| `lib/features/moods/data/mood_repository_impl.dart` | Reads `moods/current`, loads the walls by id and ranks them. |
| `lib/features/moods/views/` | The chip row, the mood row in the grid and the mood page (`/mood/:moodId`). |
| `functions/src/wallMoods.ts` | The mood rules (one table) and the job step that writes `moods/current`. |
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
| Trending | `trending/current`, the last 7 days (see [trending.md](trending.md)). | No. Up to 100 walls at once. |
| Latest | Newest reviewed Prism walls, 24 per page. | Yes. |
| Popular | The `popular/current` doc (see `popular-and-trending.md`). | One page. |

- The bloc keeps the selected tab, so the choice stays when the user changes tab in the bottom bar. The Following, Latest and Popular lists load the first time the user opens them. The Trending week list loads once when the Home opens, because the carousel needs the boosted walls.
- Following with nobody followed shows "Follow creators to see their new wallpapers here" and a **Find creators** button that opens user search.
- A guest on Following sees the sign-in prompt. The app does not read Firestore for a guest on this tab.
- Popular reads `popular/current` (`sourceTag` `popular.current`). It takes the first 40 ids and loads the walls 10 at a time (`popular.walls`). If the doc is missing or unreadable, it reads the 40 walls with most views from `wallpaper_stats` (`popular.stats`). The ids are upper case. Upload ids are upper case, so they match the `id` field of the wall.
- Trending shows the week list in the grid, with no switch above it. Boosted walls come first in the grid and have a "Boosted" tag. The Home loads the list when it opens. The Home screen reports the `viewTrending` quest event each time the Trending tab becomes the selected tab, the first visit included. Opening the Home alone reports nothing. A tile sends the source context `home_trending_grid`. The tab sends no `surface_content_loaded` event. Details are in [trending.md](trending.md).
- Analytics: a tap on a tab sends `surface_action_tapped` with action `home_chip_selected` and context `home_chip_<name>`. The names are `forYou`, `following`, `trending`, `latest` and `popular`, so Trending gives `home_chip_trending`. The lists send `surface_content_loaded` with surface `home_latest_grid`, `home_following_grid` or `home_popular_grid`.

### Carousel

- The carousel shows on the For you tab only. It has a 4 px margin on each side (`PrismFeedLayout.gridSpacing`), so a card is as wide as the screen minus 8 px. A card is 0.6 times as tall as it is wide. It has rounded corners (`PrismRadius.lg`, 20 px) and a thin outline. The height is fixed, so pages that arrive late do not move the grid.
- A 4 px gap separates the carousel from the first row of the grid.
- The pages are, in this order:
  1. The Wall of the Day (when there is one).
  2. The boosted walls, in the order of the Trending week list. There are at most 10.
  3. The promo banner (when one is set).
  4. The first 4 wallpapers of the feed.
- A boost pays for the top of Trending for 24 hours. The boosted walls also show in the home carousel, right after the Wall of the Day, so the user sees them early on the For you tab. A boosted page has the "Boosted" tag at the top left and no caption. A tap opens the wallpaper detail screen.
- The app takes the boosted walls from the Trending week list: the walls of that list with a live boost (`boostedUntil` in the future). The Home screen holds the Trending bloc and loads the list when it opens. With no boosted wall, the carousel goes from the Wall of the Day to the banner.
- A wall shows once. The preview pages and the For you grid skip the walls that the boosted pages already show.
- The page dots sit over the bottom of the image. They show when the carousel has more than one page.
- A wallpaper page has no caption. The banner and the Wall of the Day keep their text.
- A pull down on the For you tab also refreshes the Trending list, so the boosted pages stay current.
- A tap on a boosted page sends `surface_action_tapped` with context `personalized_feed_carousel_boosted`. Each boosted page counts a wallpaper impression with the source `personalized_feed_carousel_boosted`.

### Moods

- A mood is a named set of walls, for example **Dreamy** or **Dark and quiet**. Each mood has a title and one line of text under it.
- The For you tab shows a row of mood chips under the carousel. A tap on a chip opens the mood page.
- On a returning session, the For you grid can show **Pick up where you left off** after 2 rows of tiles. It shows recently viewed wallpapers the user did not keep. See [wallpaper-history.md](wallpaper-history.md).
- The For you grid also shows two mood rows: one after 4 rows of tiles and one after 12 rows. A mood row has the title, the line of text, a **See all** button and a strip of up to 10 walls. The two moods move on one place each day.
- The mood page shows all the walls of the mood in the normal grid. A tap on a tile opens the detail screen, and the user can swipe through the walls of the mood.
- The order of the walls in a mood row and on the mood page comes from the For you ranker. The walls that match the user's taste come first.
- The moods and their rules are in one table, `MOODS` in `functions/src/wallMoods.ts`:

| Mood | id | Rule |
|---|---|---|
| Dreamy | `dreamy` | The main colour is pink, purple, teal, white or blue. All colours are soft (those, or grey). A sky, cloud, sunset, flower or fluid label. |
| Dark and quiet | `dark_quiet` | The main colour is black. At most two colours, all calm. A night, moon, star or space label. No city, neon, light, firework or sunset label. |
| Bright and bold | `bright_bold` | The main colour is red, orange, yellow, pink or green. At least two of those colours. No black. |
| Minimal | `minimal` | At most two colours. In the `minimal` collection or category. No pattern, illustration, cartoon or text label. |
| Spatial ready | `spatial_ready` | `spatial.tier` is `great`. iOS 26 and later only. |
| Depth ready | `depth_ready` | `depth.tier` is `auto` or `menu`. iOS only. |

- The colours come from `walls.colors` (the 12 palette ids, the main colour first). The labels come from `walls.visionLabels`.
- The daily job `refreshCollections` (04:00 UTC) writes `moods/current` after it refreshes the collection covers. For each mood it keeps the 60 newest walls that match. It skips a mood with fewer than 12 walls.
- The job uses only walls that the free daily pick can use (`isWotdEligible`): reviewed walls with a protected original, not reserved for a Drop, not in a Drop, not streak exclusive and not in a premium collection.
- Clients can read `moods/current`. Nobody can write it from the app.
- The app hides **Spatial ready** on Android and on iOS before 26. It hides **Depth ready** on Android.
- A Home open reads `moods/current` once. A mood row reads its first 30 walls (one query) when it comes near the screen. The mood page reads up to 60 walls (two queries). The first query of the mood page is the same as the row query. When the row loaded less than 30 seconds before, the app takes that query from its memory cache.
- Analytics: `mood_chip_tapped` (`mood_id`, `position`), `mood_row_seen` (`mood_id`, `slot`) when the first wall of a row shows, and `mood_page_opened` (`mood_id`, `source`: `chip`, `row` or `link`).

### Grid

- Every tab uses the same grid: 3 columns on a phone in portrait (a wider screen gets more), 4 px gaps on both axes, a 4 px side margin and rounded corners (12 px). The side margin equals the gap, so the gutters are even. A tile is twice as tall as it is wide.
- The Home grids pass `PrismFeedLayout.gridSpacing` (4 px) to `PrismWallGrid.delegate` and `PrismFeedLayout.gridPadding` as the padding. The tiles keep the default `PrismWallGrid.tileRadius`.
- The Creators to follow row sits four wallpaper rows into the Home grid. The details are in [creator-directory.md](creator-directory.md).
- The other screens (search, categories, collections, favourites, profiles) keep the 8 px gap, the 12 px side margin and the rounded corners.

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

### Taste signals

The For you ranker learns from things the user does with a wall. The app keeps these signals on the device only (`TasteSignalStore`, at most 300). Each action has a weight (`TasteProfile.actionWeights`):

| Action | Weight | Comes from |
|---|---|---|
| `open` | 1 | The wallpaper screen opens. |
| `favourite` | 3 | A favourite, or a pick in "This or that". |
| `download` | 4 | A download. |
| `set` | 6 | A set wallpaper. |
| `passedOver` | -0.5 | The wall that lost a round of "This or that". It is a hint, not a dislike. |
| `lessLikeThis` | -8 | Show less like this. |

A weight halves every 30 days. "Clear" in the Tune sheet removes all signals.

### This or that

The quiz runs in onboarding (see [onboarding.md](onboarding.md)) and again from the Tune sheet: tap the selected **For you** tab, then **Retake This or that**. The retake loads walls from the picks in the sheet. If they do not load, a toast says "Couldn't load walls. Check your connection and try again." The retake adds to the signals the user already has. It does not clear them. After "Tuning your feed" the sheet shows again with the new learned pills, and the feed loads page 1 again.

The quiz does not set the "seeded" flag of `TasteSignalStore`. That flag means the app already read the user's favourites into the signals. The quiz signals and the favourites import add to each other.

### Show less like this

- The row is in the quick actions sheet of the For you grid. The wallpaper leaves the grid at once. A bar shows "Got it. You'll see fewer like this." with **Undo**.
- **Undo** puts the wallpaper back in its place and removes the hide (`FeedImpressionStore.unhide`).

### Impressions

The app counts a wallpaper as shown when its tile is first built, not when its page loads. The bloc batches the keys and writes them once a second, and once more when the screen closes. A wallpaper that the user never scrolled to is not counted.

### Scrolling

- The scroll view keeps 1.5 screens of tiles ready beyond the viewport.
- When a page arrives, the app starts loading the thumbnails of its first 6 new items at the grid decode height. A low data setting will turn this off (see Limits).
- The first-load skeleton uses the same columns, tile ratio, gaps, side margin and rounded corners as the grid. The carousel skeleton has the same side margin and corners as the carousel.
- The carousel turns pages by itself only when the user does not ask for reduced motion, the tab is on screen, and no screen covers the feed.
- The carousel tiles decode at the carousel height, not at full size.

## Limits

- A mood gets new walls once a day, when `refreshCollections` runs. Before the first run, the app shows no moods.
- The mood rules use the palette colours and the Vision labels. A wall with wrong labels can show in the wrong mood.
- A mood row hides when it fails to load or has fewer than 3 walls the user can see.
- Popular is all time until the scheduler `computeTrending` has run once. After that, it follows `popular/current`. Without the doc the list can differ from the all time list of `wallpaper_stats`.
- Popular shows walls whose `id` field is upper case. Other walls drop out of the list.
- Following does not page by cursor. Page N loads the first N pages again from Firestore, up to 30 walls for each group of 10 followed creators.
- Undo does not remove the "fewer like this" taste signal. It only shows the wallpaper again.
- Latest uses the same page cursor as the other readers of `PrismWallpaperRepository.fetchFeed`.
- The image prefetch ignores the low data setting for now. The feed checks a placeholder that is always off. The Data saver setting will replace it.
- Only the For you view has Show less like this and the "Updating" bar.
- The Trending tab does not page. It shows the whole list (up to 100 walls) at once.
- The carousel shows at most 10 boosted walls. The server also allows at most 10 active boosts.
- The carousel finds boosted walls in the Trending week list only. A boosted wall that is not in that list does not show in the carousel.
- The tabs do not keep the scroll position. A tab starts at the top each time the user picks it.
- The Pexels path of the feed asks for 30 photos for each query. Category grids still ask for 80.

## How to test

1. Open the Home tab. Make sure the top bar shows your picture on the left, the "prism" wordmark in the centre and the bell on the right. Tap the wordmark. Make sure nothing happens.
2. Make sure the tabs For you, Following, Trending, Latest and Popular show under the top bar, with an accent underline under For you. Make sure the carousel has a 4 px margin on each side and rounded corners, with page dots over the image, and that the wallpaper pages have no caption.
3. Scroll down. Make sure the top bar and the tabs slide away and the status bar strip stays. Make sure the bottom bar hides and a scroll-to-top button shows. Scroll up a little. Make sure the header and the bar come back. Scroll down again and tap the scroll-to-top button. Make sure the list goes to the top.
4. Make sure the grid has 3 columns, 4 px gaps, a 4 px side margin and rounded corners. Make sure a 4 px gap separates the carousel from the first row. Open Search. Make sure its grid keeps the 8 px gap, the 12 px side margin and rounded corners.
5. Tap **Latest**, then **Popular**, then **For you**. Make sure each view shows wallpapers and the list starts at the top each time. Open another tab in the bottom bar and come back. Make sure the tab is still the one you chose.
6. Tap **Trending**. Make sure the grid starts right under the tab bar and no switch shows above it. Pull down to refresh. Make sure the list reloads. Make sure the boosted walls come first and have the "Boosted" tag. Tap **Popular**. Make sure it shows the all-time list.
7. Boost an approved wall (the **Boost to Trending** button on its detail screen). Open the Home on **For you**. Make sure the Wall of the Day is the first carousel page and the boosted wall is the next page, with the "Boosted" tag at the top left and no caption. Tap the page. Make sure the wallpaper detail screen opens. Scroll down. Make sure the wall is not in the grid. With no live boost, make sure the carousel goes from the Wall of the Day to the banner. With no Wall of the Day, make sure a boosted wall is the first page.
8. Tap the selected **For you** tab. Make sure the feed settings sheet opens.
9. Sign in with an account that follows nobody. Tap **Following**. Make sure the empty text and **Find creators** show. Tap **Find creators**. Make sure user search opens.
10. Follow a creator who has wallpapers. Make sure **Following** lists them.
11. Close the app and open it again. Make sure the grid shows at once and a thin bar shows on the line under the tabs until the new page arrives.
12. Turn on airplane mode and open the app. Make sure the cached grid shows. Scroll to the end. Make sure the footer says "Couldn't load more. Try again". Turn the network on and tap it.
13. Long press a tile on For you. Tap **Show less like this**. Make sure the tile goes and **Undo** shows. Tap **Undo**. Make sure the tile comes back in the same place.
14. In Settings, turn the anime filter on or off. Go to Home. Make sure the feed reloads.
15. Make sure the create button in the bottom bar turns slowly. Tap it. Make sure the Create sheet opens.
16. On **For you**, make sure the mood chips show under the carousel. Tap **Dreamy**. Make sure the mood page opens with its title, one line of text and a grid. Tap a tile and swipe. Make sure the walls of the mood show.
17. Scroll the For you grid. Make sure a mood row shows after 4 rows and a second one after 12 rows. Tap **See all**. Make sure the mood page opens.
18. On an iOS 26 device, make sure the **Spatial ready** and **Depth ready** chips show. On Android, make sure they do not show.
19. Tap the selected **For you** tab, then **Retake This or that**. Pick 6 times. Make sure "Tuning your feed" shows, then the sheet comes back with new learned pills. Close the sheet. Make sure the feed leads with walls like your picks.

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
- `test/features/navigation/tune_sheet_retake_test.dart`
- `test/features/taste_quiz/taste_quiz_ranking_test.dart`
- `test/features/prism_feed/biz/bloc/paged_feed_bloc_test.dart`
- `test/core/widgets/home/loading_cards_test.dart`
- `test/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl_test.dart`
- `test/features/moods/` (mood rules on the client, cubits, repository, chip row, mood row, mood page)
- `functions/src/__tests__/wallMoods.test.ts`
