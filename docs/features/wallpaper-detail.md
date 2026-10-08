# Wallpaper detail

The detail screen shows one wallpaper full screen. A bar at the bottom holds the main actions. A panel above it holds the details and related wallpapers.

## Where to find it

Tap a wallpaper in any feed, search, or favourites list. Route: `WallpaperDetailRoute`. Swipe up on the image to open the panel.

## Platforms

| Platform | Difference |
|---|---|
| Android | Primary action is **Set**. The bar also has Download. A **Live** chip on the image and a **Make it live** button in the panel show when the device supports OpenGL live wallpapers. |
| iOS | Primary action is **Save** (a download to Photos). The bar has no separate Download or Set. No **Make it live** action. |

## Free and Pro

- **Set** is free. So is the Position studio (see `docs/features/set-wallpaper.md` and `docs/features/position-studio.md`).
- **Download** has a gate in `DownloadButton`. A Pro user downloads at no cost. A guest sees an ad gate pop-up with BUY PREMIUM. A signed-in user spends coins or watches a rewarded ad.
- A wallpaper in a premium collection costs 15 coins (`CoinPolicy.premiumWallpaperDownload`). Other wallpapers cost 5 coins (`CoinPolicy.wallpaperDownload`).
- Only Prism wallpapers can be premium. Wallhaven and Pexels wallpapers never are.

## How it works

Action bar (`WallpaperActionBar`):

- It is pinned to the bottom, in an overlay beside the sliding panel (a `Stack` sibling). It does not move when the panel opens. It paints no surface. The panel supplies the translucent blurred surface (sigma 16) under it, so the two read as one calm surface. It respects the bottom safe area.
- Order: primary (Set or Save), Download (Android), Favourite, Share, Edit. Each icon button has a tooltip.
- The wallpaper image layer has no tint or color filter. The palette only changes the chrome accent (back button, clock button, text on the preview).

The panel reserves the bar height plus the bottom safe area at its bottom edge, so its content scrolls above the bar.

Header (top of the panel):

- The headline is the title the creator gave (`PrismWallpaper.title`). Older uploads have no title, so the headline reads "Wallpaper by <creator name>". When the name is empty or looks like an email, it reads "Wallpaper by Prism creator". The app never shows an email here. The share link title is the same text. Wallhaven and Pexels walls keep their id as the headline.
- Next to it: "N views" and, from 5 sets on, "Set N times". The count is `wallpaper_stats.sets`, read with source tag `wallpaper_stats.detail`. It is hidden for fewer than 5 sets and when the read fails.
- A successful Set on a Prism wall calls the `recordWallpaperAction` callable with `set` (`RecordWallpaperActionUseCase`).

Image overlays: the back button, the clock button, and on Android a **Live** chip at the bottom left of the image. The chip opens Make it live with the first palette colour as `accentSeed`.

Load error: if a wallpaper cannot load (a share link, for example), the screen shows the thumbnail dimmed, the title "Couldn't load this wallpaper", the text "Check your connection and try again.", and **Try again**. A wallpaper that does not exist shows "Wallpaper not found". Raw error text never shows.

Panel content, in order:

1. Notes about the screen fit. "Low resolution for your screen" shows when "Fill screen" must enlarge the wallpaper by more than 25 percent (`max(screen width / wall width, screen height / wall height) > 1.25`). A wide wallpaper is compared by the same rule, so a 2560 by 1440 wallpaper on a 1080 by 2400 phone gets the note. "Landscape wallpaper: the sides will be cropped" shows when the wallpaper is wider than tall. The size comes from `width` and `height`, or from a "1080x1920" style resolution string. The notes do not show when the size is unknown. The set sheet shows the same notes as chips.
2. Tag chips (max 10, unique). A tap opens the Search tab with that tag (`openTagSearch` sets `pendingTagSearch`, and `SearchScreen` reads it).
3. **Make it live** button (Android, when `supportsOpenGlLiveWallpaper` is true). It opens `LiveWallpaperRoute(imageUrl: <full url>)`.
4. **More like this** strip.
5. **Report** and, for a signed-in viewer on someone else's Prism wallpaper, **Block creator**. Block creator looks up the creator profile by email, then uses the same confirm dialog as the profile screen (`confirmAndBlockUser`). After "Report sent", a snackbar offers **Also block this creator**. A guest who taps Report gets the sign-in sheet. After sign-in, the report sheet opens again.

More like this (`SimilarWallpapersLoader`):

- Prism wallpapers: a `FirestoreClient` query on `walls`. Filters: `category` equals the current category and `review` equals true. Order: `createdAt` descending. Source tag: `wallpaper_detail.similar`. The cache policy is `memoryFirst`.
- The loader removes the current wallpaper and wallpapers from blocked creators. The maximum is 12 items.
- Wallhaven wallpapers: a search for the first tag through `WallpaperSearchService`.
- Pexels wallpapers: no strip.
- The strip is hidden while it loads, when it is empty, and on any error.
- A tap on a tile opens that wallpaper's detail screen.

Clock preview (the clock icon at the top right):

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
- Long press on a wallpaper in the collection, color, and search grids still copies a link. These grids call `copyWallpaperLink`, which copies and shows a toast.
- **Favourite** shows a toast "Couldn't update favourites. Try again." when the update fails. In trash mode, the screen closes only after success.

| Path | Role |
|---|---|
| `lib/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart` | Screen, action bar, panel. |
| `lib/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart` | Bar layout. |
| `lib/features/wallpaper_detail/views/widgets/accent_contrast.dart` | `onColor`: black or white by relative luminance (threshold 0.179). Used by the screen and by `PrimaryActionPill`. |
| `lib/features/wallpaper_detail/views/widgets/similar_wallpapers_strip.dart` | Strip UI. |
| `lib/features/wallpaper_detail/biz/similar_wallpapers_loader.dart` | Query and filters. |
| `lib/features/wallpaper_detail/views/widgets/wallpaper_tag_chips.dart` | Tag chips. |
| `lib/features/wallpaper_detail/biz/tag_search_launcher.dart` | Opens Search with a tag. |
| `lib/features/wallpaper_detail/biz/wallpaper_detail_rules.dart` | Premium test, low resolution test, tags, preview title. |
| `lib/features/wallpaper_detail/views/widgets/clock_overlay.dart` | Lock and Home preview. |
| `lib/features/wallpaper_detail/views/widgets/preview_layers.dart` | `LockPreviewLayer`, `HomePreviewLayer`. |
| `lib/features/wallpaper_detail/biz/top_third_text_color.dart` | Text colour from the top third of a small decode. |
| `lib/features/wallpaper_detail/biz/block_wall_creator.dart` | Block creator from the detail panel. |
| `lib/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart` | `RecordWallpaperActionUseCase`, `GetWallpaperSetCountUseCase`. |
| `lib/features/wallpaper_detail/views/widgets/make_it_live_button.dart` | Make it live. |
| `lib/features/ads/views/widgets/download_button.dart` | Download and gate. |
| `lib/core/widgets/menu_button/share_button.dart` | Share. |
| `lib/core/widgets/menu_button/fav_wallpaper_button.dart` | Favourite. |
| `lib/data/share/create_dynamic_link.dart` | Share link. |

## Limits

- The share link preview title is the wallpaper title, else "Wallpaper by <creator>". If the creator is unknown it is "Wallpaper by Prism creator" for Prism walls and "Wallpaper on Prism" for others.
- "Set N times" needs the deployed `recordWallpaperAction` function and Firestore read of `wallpaper_stats`. Guests are not counted.
- The palette comes from a 64 by 64 copy of the thumbnail.
- The full-image preview decodes at screen width times pixel ratio, with a cap of 2160 px.
- The low-resolution note uses the stored size. It can be wrong when the server data is wrong.
- Pexels wallpapers have no tags and no More like this strip.
- The Home view in the clock preview on iOS has no dock. This is by design in the code.
- Not confirmed on a device: the blur of the action bar and the layout on small screens.

## How to test

1. Open any Prism wallpaper on Android. Make sure the bar shows Set, Download, Favourite, Share, Edit. Make sure the image has no color tint.
2. On iOS, make sure the bar shows Save, Favourite, Share, Edit.
3. Tap a premium wallpaper Download as a free user. Make sure the cost is 15 coins. Make sure a normal wallpaper costs 5.
4. Swipe up. Tap a tag chip. Make sure the Search tab opens with that tag.
5. Scroll the **More like this** strip. Tap a tile. Make sure a new detail screen opens.
6. Open a small wallpaper. Make sure "Low resolution for your screen" shows.
7. Tap the clock icon. Toggle Lock and Home. Change the device to 24 h time. Make sure the time follows it.
8. On Android with OpenGL support, tap the **Live** chip on the image, then **Make it live** in the panel. Make sure the live wallpaper screen opens both times.
9. Open a wallpaper with a title. Make sure the headline is the title. Open an older upload. Make sure it reads "Wallpaper by" and the creator name, never an email.
10. Open a wallpaper that was set at least 5 times. Make sure the header shows "Set N times".
11. Signed in, open someone else's Prism wallpaper. Swipe up. Make sure **Report** and **Block creator** show. Open your own wallpaper. Make sure Block creator does not show.
12. Report a wallpaper. Make sure the snackbar offers **Also block this creator**.
13. Turn on airplane mode. Open a share link to a wallpaper that is not cached. Make sure the screen shows the thumbnail, a plain message, and **Try again**.
14. Turn on airplane mode. Tap Share. Make sure an error toast shows and nothing is copied. Tap Favourite. Make sure the error toast shows.

Automated tests:

- `test/features/wallpaper_detail/views/pages/wallpaper_detail_action_bar_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_header_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_set_flow_test.dart`
- `test/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc_test.dart`
- `test/core/widgets/content_report/content_report_sheet_test.dart`
- `test/features/wallpaper_detail/views/widgets/wallpaper_detail_widgets_test.dart`
- `test/features/wallpaper_detail/views/widgets/clock_overlay_test.dart`
- `test/features/wallpaper_detail/views/widgets/preview_layers_test.dart`
- `test/features/wallpaper_detail/biz/similar_wallpapers_loader_test.dart`
- `test/features/wallpaper_detail/biz/wallpaper_detail_rules_test.dart`
- `test/data/share/create_dynamic_link_test.dart`
- `test/core/widgets/share_button_test.dart`

Command: `fvm flutter test --no-pub test/features/wallpaper_detail`
