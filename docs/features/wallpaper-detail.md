# Wallpaper detail

The detail screen shows one wallpaper as a rounded card under the status bar. Under the card are the actions, the colour variations and a short summary. The details open from the summary. Below them, a grid of more wallpapers loads as you scroll. The whole page scrolls as one.

## Where to find it

Tap a wallpaper in any feed, search, or favourites list. Route: `WallpaperDetailRoute`, built by `wallpaperDetailRouteBuilder`. Tap the summary row, or its chevron, to show or hide the details.

## Platforms

| Platform | Difference |
|---|---|
| Android | Primary action is **Set**. The row also has a Download icon. A **Live** chip on the card and a **Make it live** button in the details show when the device supports OpenGL live wallpapers. |
| iOS | Primary action is **Save** (a download to Photos). The row has no separate Download or Set. No **Make it live** action. |

## Free and Pro

- **Set** is free. So is the Position studio (see `docs/features/set-wallpaper.md` and `docs/features/position-studio.md`).
- **Download** has a gate in `DownloadButton`. A Pro user downloads at no cost. A guest sees an ad gate pop-up with BUY PREMIUM. A signed-in user spends coins or watches a rewarded ad.
- A wallpaper in a premium collection costs 15 coins (`CoinPolicy.premiumWallpaperDownload`). Other wallpapers cost 5 coins (`CoinPolicy.wallpaperDownload`).
- Only Prism wallpapers can be premium. Wallhaven and Pexels wallpapers never are.

## How it works

Card and page:

- The card has the wallpaper's own shape across the width, up to 66 percent of the screen height. A taller wallpaper fills the card and is cropped at the top and bottom (`BoxFit.cover`). The clock preview shows it whole. On a tablet or in landscape the card narrows and stays centred, so a tall wallpaper never becomes a strip.
- The shape comes from `width` and `height`, or from a "1080x1920" style resolution string. With neither, the card is 9 by 16.
- **Back** and the **clock** sit in the top corners of the card, on 44 px chips of the theme scrim at 55 percent with light ink. They stay in place while the page scrolls under them.
- The status bar icons follow the page, then the card while the card is under them, then the page again. When the grid is under the status bar, a fade of the page colour sits behind it.
- The rows under the card keep to the panel width on a tablet (`PrismLayout.panelWidth`).

Opening and closing (`lib/core/router/wallpaper_detail_route.dart`):

- From a grid tile, the card is a Hero that flies from the tile. The page grows out of the tile with it over 240 ms, and a scrim of up to 30 percent dims the page behind. While the page grows, taps outside it do nothing, so a second tap cannot open another page.
- The card shows the tile's decoded picture until its own picture is ready, so it never flashes blank.
- With no tile (a deep link, for example) the page fades in. When the device asks for less motion, the page opens in place without a flight.
- Back during the opening shrinks the page back into its tile. After the opening, Back fades the page out on Android. On iOS the page slides out, and the native edge swipe from the left works, unless the wall is immersive.

While Prism confirms a Prism wallpaper that a feed passed in, the card shows its thumbnail only. Placeholders hold the place of the actions and the summary, and nothing under the card takes taps. **Back** works. The clock shows when the wallpaper is ready.

Action row (`WallpaperActionBar`):

- It sits under the card. Icon actions are at the start: Favourite with its published total, Share, Edit. Download (Android) and the labelled primary (Set or Save) are at the end. Each icon button has a tooltip.
- The icons are bare 24 px glyphs. The heart is 30 px. While Set or Save works, a spinner takes the place of the label, and the button keeps its width.
- Every button shrinks to 0.96 under the finger (`PressScale`, 100 ms down and 140 ms up, ease out both ways). `CircularMenuButton` does this itself, so the screen wraps only the Set pill, the Save pill and Favourite. A button never scales twice. A round button takes taps on its whole circle, not only on the icon.
- The total beside the heart is the published favourite count: the shared Prism stats, or the Wallhaven total. It is compact and localized ("12.3K"), and a screen reader hears it as "12,345 favourites". It is hidden when it is unknown or below zero. Pexels walls show no total.

Colour variations:

- Tap a swatch to tint the whole wallpaper with its hue (`ColorFiltered` with `BlendMode.hue`, over the image). The change slides in about 220 ms, or at once when the device asks for less motion. The slide blends the two colours in HSL space and the hue takes the short way round (`lerpHueTint`), so it never fades through grey. A tap on the card does not change the colour. It toggles immersive mode.
- Hold the card for its menu: **Favourite** (or **Unfavourite**), **Share link**, and **Reset to original**. Reset to original brings back the untouched wallpaper. The menu is the shared hold menu of the grids (`WallpaperQuickActionRegion`).
- The swatch row under the actions shows the original first, then one round swatch per palette colour (up to 5). Each swatch is the wallpaper thumbnail with that hue, and a ring marks the one in use. Tap a swatch to pick it. It plays the selection haptic. Long press a swatch to copy its hex code.
- At first, the wallpaper stays original. It only changes after you pick a colour.
- Set, Download (Save on iOS) and Edit use the tinted image. Set and Edit get `prepareSource`, which calls `renderTintedWallpaper` (`wallpaper_tint_renderer.dart`). It draws the full wallpaper with the same hue blend and returns a PNG path. Download gets a `DownloadVariant` with the key `tint-<rrggbb>` and the same `prepare`. Each colour is its own purchase, and a finished tinted download is remembered in `DownloadedWallIndex` under `variant.identityOf(url)`, not under the wallpaper link. The identity is a plain file name, `<base>_<key>.png`. Every character of the base outside `A-Z a-z 0-9 . _ -` becomes `_` (a decoded `#` or `?` in the link would otherwise start a fragment or query when the name is parsed again) and the base is cut so the name stays within the 200 bytes the native side accepts. With the original showing, the buttons use the wallpaper as before.
- A tinted file opened from Library > Downloads is that variation. When the file name ends in `_tint-<rrggbb>` (and an optional ` (n)` copy suffix) and no new colour is picked, Download (Save on iOS) gets a `DownloadVariant` with that key whose `prepare` returns the file itself. So the pill reads Saved, and Download again copies the tinted file, not the original. Edit opens any local file as it is. A colour picked on top renders from the local file, as a new variation.
- The clock preview shows the same hue (`ClockOverlay.tint`). The clock text colour is measured on the tinted 32 px sample (`textColorForTopThird(tint:)`), so it reads on the hue the user sees.

Summary and details:

- The summary row shows the creator and where the wallpaper is from, then its title. The app never shows an email as the creator. A tap anywhere on the row, or on its chevron, shows or hides the details.
- The title is the one the creator gave (`PrismWallpaper.title`). Older uploads have no title, so it reads "Wallpaper by <creator name>". When the name is empty or looks like an email, it reads "Wallpaper by Prism creator". The share link title is the same text.
- In the details, a Prism wall shows the same title as its headline, with "Set N times" next to it from 5 sets on. The count is `wallpaper_stats.sets`, read with source tag `wallpaper_stats.detail`. It is hidden for fewer than 5 sets and when the read fails. Under the headline are the views, then collections, category, resolution, size, the creator (a tap opens the profile), the date and the source.
- Wallhaven and Pexels walls keep their id as the headline. Wallhaven shows views, size, the uploader (a link to wallhaven.cc), category and resolution. Pexels shows the size in pixels and the photographer (a link to their Pexels page).
- A successful Set on a Prism wall calls the `recordWallpaperAction` callable with `set` (`RecordWallpaperActionUseCase`).

The **Live** chip sits in the bottom-left corner of the card (bottom-right in right-to-left languages). It is a small dark glass chip with a 48 px touch target. It fades in over 160 ms when the device answers that it supports live wallpapers. The label scales with the system text up to 1.5 times, and the chip width follows the label. It opens Make it live with the first palette colour as `accentSeed`.

Load error: if a wallpaper cannot load (a share link, for example), the screen shows the thumbnail dimmed, the title "Couldn't load this wallpaper", the text "Check your connection and try again.", and **Try again**. A wallpaper that does not exist shows "Wallpaper not found". Raw error text never shows.

Details content, after the metadata, in order:

1. Notes about the screen fit. "Low resolution for your screen" shows when "Fill screen" must enlarge the wallpaper by more than 25 percent (`max(screen width / wall width, screen height / wall height) > 1.25`). A wide wallpaper is compared by the same rule, so a 2560 by 1440 wallpaper on a 1080 by 2400 phone gets the note. "Landscape wallpaper: the sides will be cropped" shows when the wallpaper is wider than tall. The size comes from `width` and `height`, or from a "1080x1920" style resolution string. The notes do not show when the size is unknown. The set sheet shows the same notes as chips.
2. Tag chips (max 10, unique). A tap opens the Search tab with that tag (`openTagSearch` sets `pendingTagSearch`, and `SearchScreen` reads it).
3. Depth Effect row, for a wall with a Depth Effect tier.
4. **Make it live** button (Android, when `supportsOpenGlLiveWallpaper` is true). It opens `LiveWallpaperRoute(imageUrl: <full url>)`.
5. **Boost to Trending**, for the owner of an approved wall.
6. **Report** and, for a signed-in viewer on someone else's Prism wallpaper, **Block creator**. Block creator looks up the creator profile by email, then uses the same confirm dialog as the profile screen (`confirmAndBlockUser`). After "Report sent", a snackbar offers **Also block this creator**. A guest who taps Report gets the sign-in sheet. After sign-in, the report sheet opens again.

More wallpapers (`WallpaperRecommendationRepositoryImpl`):

- A uniform grid under the details. Its title is **More like this** for related walls, **Discovery** otherwise, and **Offline** for local results. Each tile has the shared favourite and view totals under it.
- Prism wallpapers with a category: a `FirestoreClient` query on `walls`. Filters: `category` equals the current category and `review` equals true. Order: `createdAt` descending. 24 walls a page. The next page starts after the last document of the page, also when every row on it was filtered out. Source tag: `wallpaper_detail.recommendations`. The cache policy is `memoryFirst`.
- Prism wallpapers without a category: the same query without the category filter, titled Discovery.
- Wallhaven wallpapers: a Wallhaven search for the first tag, or a plain search when the wall has no tags. It uses the Wallhaven category and purity settings. The query stays the same for the whole visit. If its first page fails, Pexels Curated continues the visit.
- Pexels wallpapers: Pexels Curated, titled Discovery.
- Downloads and bundled starters follow the same rules. Downloads opens a file by its catalogue identity (`DownloadedWallIndex`), so the wall's own category or tags decide what is related. A file with no catalogue identity opens the plain downloaded-file screen (`DownloadWallpaperRoute`), which has no grid. The bundled starters have the categories Nature and Abstract.
- Related walls come only from the wall's own category or tags. A wall with neither gets Discovery, never an invented match.
- The grid removes the current wallpaper, duplicates, walls from blocked creators and, when the setting hides it, anime. One load asks for at most 4 pages, so a page that is all filtered still moves on.
- Each visit owns its page cursor, in memory, under a `detail:` page key (`ephemeralPaginationPrefix`). Wallhaven and Pexels pages of a visit are never written to the durable feed cache, and a failed first page never reads old pages back. Closing the page releases the cursor.
- The next page loads when you are within 600 px of the end. **Show more** loads it by hand. When a first page fails, the grid shows local catalogue results, titled Offline. Cached Wallhaven rows show there only when the purity setting allows everything. When a later page fails, **Couldn't load more. Try again** retries the same page. At the end the grid reads "You are all caught up". With nothing to show, the grid is hidden.
- A tap on a tile opens that wallpaper's detail as a new page. Back restores the page before it, with its scroll position, its loaded pages and its colour variation.

Clock preview (the clock icon in the top right corner of the card):

- A full-screen preview with a **Lock** and **Home** toggle. Android starts on Home. iOS starts on Lock.
- The layers are `LockPreviewLayer` and `HomePreviewLayer` (`preview_layers.dart`). The Position studio uses the same two widgets.
- The text is black or white. The app decodes the wallpaper at 32 px and picks the colour with the better contrast on the top third. The palette accent does not colour the text.
- The full image loads through `PrismFullImageCache`, with a screen-width decode. While it loads, the thumbnail shows. If it fails, a broken image icon shows.
- The Android Lock view shows a large time and the date. The Home view shows the day, the date, and app icons.
- On iOS the Home view shows only the image.
- The time uses the device 12 h or 24 h setting (`MediaQuery.alwaysUse24HourFormatOf`). The preview does not show a temperature.

Share and favourite:

- `createDynamicLink` returns the link or null. It does not copy to the clipboard, show a toast, or throw.
- **Share** shows a toast "Couldn't create the share link. Try again." when the link is null. On other errors it shows "Couldn't share this wallpaper. Try again."
- **Share link** in the hold menu, on the card and on grid tiles, calls `copyWallpaperLink`, which copies a link and shows a toast.
- **Favourite** shows a toast "Couldn't update favourites. Try again." when the update fails. In trash mode, the screen closes only after success.

| Path | Role |
|---|---|
| `lib/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart` | Screen: card, actions, swatches, summary, details, colour variations. |
| `lib/core/router/wallpaper_detail_route.dart` | The detail route: card Hero, the page growing out of the tile, iOS edge back. |
| `lib/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart` | Action row layout. |
| `lib/features/wallpaper_detail/views/widgets/wallpaper_recommendations.dart` | Grid of more wallpapers. |
| `lib/features/wallpaper_detail/data/repositories/wallpaper_recommendation_repository_impl.dart` | Queries, filters and the page cursor of each visit. |
| `lib/data/feed_cache/pagination_session.dart` | `detail:` page keys, kept in memory only. |
| `lib/features/category_feed/views/widgets/wallpaper_quick_actions.dart` | The hold menu actions, including Reset to original. |
| `lib/features/wallpaper_detail/data/wallpaper_tint_renderer.dart` | `renderTintedWallpaper`: the tinted PNG for Set, Download and Edit. |
| `lib/core/widgets/prism_glass.dart` | The glass surface of the Live chip. `thickness` is the iOS refraction depth. Pills of 48 px or less pass 16. |
| `lib/core/widgets/animated/press_scale.dart` | Press feedback. It does not set a filter quality, because that would drop the blurred backdrop of any glass inside it. |
| `lib/core/widgets/menu_button/circular_menu_button.dart` | The round action buttons. |
| `lib/features/wallpaper_detail/views/widgets/accent_contrast.dart` | `onColor`: black or white by relative luminance (threshold 0.179). Used by the screen and by `PrimaryActionPill`. |
| `lib/features/wallpaper_detail/views/widgets/wallpaper_tag_chips.dart` | Tag chips. |
| `lib/features/wallpaper_detail/biz/tag_search_launcher.dart` | Opens Search with a tag. |
| `lib/features/wallpaper_detail/biz/wallpaper_detail_rules.dart` | Premium test, low resolution test, tags, preview title. |
| `lib/features/wallpaper_detail/views/widgets/clock_overlay.dart` | Lock and Home preview. |
| `lib/features/wallpaper_detail/views/widgets/preview_layers.dart` | `LockPreviewLayer`, `HomePreviewLayer`. |
| `lib/features/wallpaper_detail/biz/top_third_text_color.dart` | Text colour from the top third of a small decode. |
| `lib/features/wallpaper_detail/biz/block_wall_creator.dart` | Block creator from the details. |
| `lib/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart` | `RecordWallpaperActionUseCase`, `GetWallpaperSetCountUseCase`. |
| `lib/features/wallpaper_detail/views/widgets/make_it_live_button.dart` | Make it live button and the Live chip. |
| `lib/features/ads/views/widgets/download_button.dart` | Download and gate. |
| `lib/core/widgets/menu_button/share_button.dart` | Share. |
| `lib/core/widgets/menu_button/fav_wallpaper_button.dart` | Favourite. |
| `lib/data/share/create_dynamic_link.dart` | Share link. |

Remix (AI wallpapers with a prompt):

- The **Remix** action opens the AI tab with the prompt, style and tier of the wallpaper. It is hidden when AI is off, the wallpaper is not approved, the wallpaper is premium-gated for a free user or streak exclusive, or the creator is blocked.
- In the detail panel, an original with remixes shows **Remixes**, the count and a row of approved remixes by other creators.
- A remix shows **Remix of <title> by <creator>**. A tap opens the original.

The details are in [remix.md](remix.md).

### Immersive mode

A single tap on the wallpaper card hides every control. The hidden controls are the back and preview buttons, the action bar and the colour swatches. The summary and details rows, the chips and the recommendations hide too. The system bars hide as well. On Android, the app uses `SystemUiMode.immersiveSticky`. On iOS, the status bar and the home indicator hide.

- The card grows to the full screen and loses its rounded corners. The same decoded picture stays on screen. The image decodes for the full screen size, so the change does not load or decode the image again.
- The change takes 240 ms on the Prism ease-out curve (`PrismCurves.enter`). With reduced motion, the change is instant.
- Another tap shows every control again. On Android, the back button and the back gesture do the same. The first back press only leaves immersive mode. It does not close the screen. On iOS, the edge swipe back is off while the wall is immersive.
- A sideways swipe moves to the next or previous wall of the feed. The next wall is also immersive.
- A pinch zooms the wall up to 4x while immersive. The wall springs back when the fingers lift. There is no pinch zoom outside immersive mode, where the card is part of a scrolling page.
- A touch that pinches, swipes the feed or scrolls the page is never a tap.
- Immersive mode ends when one of these happens. The system bars show again.
  - The route closes.
  - A route or a sheet opens on top.
  - The app goes to the background (hidden or paused). A short "inactive" state, such as Control Centre, does not count.
  - A load error shows.
  When the app resumes, the screen shows the normal layout.
- The first detail screen that a user opens shows the hint "Tap to hide controls" for 3 seconds. The hint shows once per install. Its settings key is `wallpaper_detail.immersive_hint_shown`.
- Screen readers hear a "Hide controls" or "Show controls" action on the wallpaper. The default activate action also toggles immersive mode. Hidden controls leave the semantics tree.
- A long press still opens the hold menu. When the wall is a favourite, the menu also has "Pin to top" or "Unpin".
- Analytics: `detail_immersive_toggled{immersive, source}`, where `immersive` is a bool and `source` is `tap` or `semantics`. `detail_immersive_hint_shown` records the hint.
- Code: `_DetailImmersion` in `lib/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart` owns the immersive state and the system UI mode for the route. The feed browser shares it. `_FeedDragSurface` owns the tap, the feed drag and the pinch.
- The Lock Screen and Home Screen preview (`clock_overlay.dart`) also hides its controls on a tap, on the same ease-out curve. Its fade is 160 ms, because nothing in it moves. It keeps the system status bar on purpose, because a real Lock Screen shows it.

The table compares each gesture before and after the change.

| Gesture | Before | Now |
|---|---|---|
| Tap on wall | Cycles the tint through the palette, with a short press shrink | Toggles immersive mode |
| Double tap | Nothing | Nothing |
| Long press | Opens the hold menu | Opens the hold menu, with "Pin to top" or "Unpin" for favourites |
| Pinch | Nothing | Zooms the wall up to 4x while immersive, then springs back |
| Swipe up or down | Scrolls the page to the actions and details | Same, locked while immersive |
| Swipe left or right | Moves to the next or previous wall of the feed | Same, and the next wall is also immersive |
| Back | Closes the screen | Leaves immersive mode first, then closes the screen |
| Tap on the summary row or chevron | Opens or closes the details | Same |

## Limits

- The share link preview title is the wallpaper title, else "Wallpaper by <creator>". If the creator is unknown it is "Wallpaper by Prism creator" for Prism walls and "Wallpaper on Prism" for others.
- "Set N times" needs the deployed `recordWallpaperAction` function and Firestore read of `wallpaper_stats`. Guests are not counted.
- The palette comes from a 64 by 64 copy of the thumbnail.
- The full-image preview decodes at screen width times pixel ratio, with a cap of 2160 px.
- The low-resolution note uses the stored size. It can be wrong when the server data is wrong.
- Pexels wallpapers have no tags, so their grid is always Pexels Curated, never More like this.
- More like this matches only the category (Prism) or the first tag (Wallhaven). It is not personalized.
- The Home view in the clock preview on iOS has no dock. This is by design in the code.
- While the Live chip fades in or out, it is inside an opacity layer, so its glass shows the tint without the blur until it is fully there.
- The colour tint needs the full image to render for Set, Download and Edit. The first tap on one of them can take a moment. The same colour on the same wallpaper reuses the file.

## How to test

1. Open any Prism wallpaper on Android. Make sure the card sits under the status bar with round corners. Make sure the row under it shows Favourite with its total, Share and Edit at the start, and Download and Set at the end. Make sure the image has no color tint.
2. On iOS, make sure the row shows Favourite, Share, Edit and Save, with no Set, no Download icon and no Live chip.
3. Tap a premium wallpaper Download as a free user. Make sure the cost is 15 coins. Make sure a normal wallpaper costs 5.
4. Tap the summary row. Make sure the details show. Tap a tag chip. Make sure the Search tab opens with that tag.
5. Scroll down. Make sure the grid of more wallpapers loads, with more pages as you scroll. Tap a tile. Make sure a new detail page grows out of the tile. Go back. Make sure the first page is at the same scroll position.
6. Open a small wallpaper and show the details. Make sure "Low resolution for your screen" shows.
7. Tap the clock icon. Toggle Lock and Home. Change the device to 24 h time. Make sure the time follows it.
8. On Android with OpenGL support, tap the **Live** chip on the card, then **Make it live** in the details. Make sure the live wallpaper screen opens both times.
9. Open a wallpaper with a title. Make sure the title shows in the summary. Open an older upload. Make sure it reads "Wallpaper by" and the creator name, never an email.
10. Open a wallpaper that was set at least 5 times and show the details. Make sure "Set N times" shows.
11. Signed in, open someone else's Prism wallpaper and show the details. Make sure **Report** and **Block creator** show. Open your own wallpaper. Make sure Block creator does not show.
12. Report a wallpaper. Make sure the snackbar offers **Also block this creator**.
13. Turn on airplane mode. Open a share link to a wallpaper that is not cached. Make sure the screen shows the thumbnail, a plain message, and **Try again**.
14. Turn on airplane mode. Tap Share. Make sure an error toast shows and nothing is copied. Tap Favourite. Make sure the error toast shows.
15. Tap the card. Make sure the controls hide and the wallpaper fills the screen. Tap again. Make sure the controls show. Pick a swatch. Make sure the whole wallpaper changes hue. Hold the card and pick **Reset to original**. Make sure the original comes back.
16. Make sure each swatch shows the wallpaper in its own colour. Pick a swatch. Make sure the wallpaper changes. Long press a swatch. Make sure the hex code is copied.
17. With a colour picked, tap Set, then Download (or Save on iOS), then Edit. Make sure each one uses the tinted wallpaper. Tap the clock icon. Make sure the preview shows the same hue.
18. Open a Prism wallpaper that has a category from Library > Downloads. Make sure the grid is titled **More like this** and shows walls of that category.
19. Turn on reduce motion. Open a wallpaper from a tile. Make sure the page opens in place. On iOS, swipe from the left edge. Make sure the page follows the finger and goes back.
20. Press and hold the Live chip. Make sure it shrinks and the glass stays blurred. Hold Download, Share and Edit. Make sure each shrinks a little, once.
21. On a tablet, or a phone in landscape, make sure the card narrows and stays centred, and Back and the clock stay in its corners.
22. Pick a colour, then another. Make sure the hue turns over and does not go grey in between. Tap a swatch. Make sure you feel a light tick.

Automated tests:

- `test/features/wallpaper_detail/views/pages/wallpaper_detail_action_bar_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_glass_panel_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_colour_variation_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_navigation_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_downloaded_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_hero_lifecycle_test.dart`
- `test/features/wallpaper_detail/views/wallpaper_detail_motion_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_header_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_set_flow_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_saved_tint_test.dart`
- `test/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc_test.dart`
- `test/features/wallpaper_detail/biz/bloc/recommendations_test.dart`
- `test/features/wallpaper_detail/data/recommendation_repository_test.dart`
- `test/core/router/wallpaper_detail_route_test.dart`
- `test/features/category_feed/wallpaper_hold_region_test.dart`
- `test/core/widgets/content_report/content_report_sheet_test.dart`
- `test/features/wallpaper_detail/views/widgets/wallpaper_detail_widgets_test.dart`
- `test/core/widgets/press_scale_test.dart`
- `test/core/widgets/circular_menu_button_test.dart`
- `test/features/wallpaper_detail/views/widgets/clock_overlay_test.dart`
- `test/features/wallpaper_detail/views/widgets/preview_layers_test.dart`
- `test/features/wallpaper_detail/biz/top_third_text_color_test.dart`
- `test/features/wallpaper_detail/biz/wallpaper_detail_rules_test.dart`
- `test/data/share/create_dynamic_link_test.dart`
- `test/core/widgets/share_button_test.dart`

Command: `fvm flutter test --no-pub test/features/wallpaper_detail test/core/router/wallpaper_detail_route_test.dart`
