# Wallpaper detail

The detail screen shows one wallpaper full screen. A bar at the bottom holds the main actions. A panel above it holds the details and related wallpapers.

## Where to find it

Tap a wallpaper in any feed, search, or favourites list. Route: `WallpaperDetailRoute`. Swipe up on the image to open the panel.

## Platforms

| Platform | Difference |
|---|---|
| Android | Primary action is **Set**. The bar also has Download. **Make it live** shows when the device supports OpenGL live wallpapers. |
| iOS | Primary action is **Save** (a download to Photos). The bar has no separate Download or Set. No **Make it live** action. |

## Free and Pro

- **Set** is free.
- **Download** has a gate in `DownloadButton`. A Pro user downloads at no cost. A guest sees an ad gate pop-up with BUY PREMIUM. A signed-in user spends coins or watches a rewarded ad.
- A wallpaper in a premium collection costs 15 coins (`CoinPolicy.premiumWallpaperDownload`). Other wallpapers cost 5 coins (`CoinPolicy.wallpaperDownload`).
- Only Prism wallpapers can be premium. Wallhaven and Pexels wallpapers never are.

## How it works

Action bar (`WallpaperActionBar`):

- It is pinned to the bottom, in an overlay beside the sliding panel (a `Stack` sibling). It does not move when the panel opens. It paints no surface. The panel supplies the translucent blurred surface (sigma 16) under it, so the two read as one calm surface. It respects the bottom safe area.
- Order: primary (Set or Save), Download (Android), Favourite, Share, Edit. Each icon button has a tooltip.
- The wallpaper image layer has no tint or color filter. The palette only changes the chrome accent (back button, clock button, text on the preview).

The panel reserves the bar height plus the bottom safe area at its bottom edge, so its content scrolls above the bar.

Panel content, in order:

1. A note "Low resolution for your screen" when the wallpaper is smaller than the screen in pixels on either side. The size comes from `width` and `height`, or from a "1080x1920" style resolution string. The note does not show when the size is unknown.
2. Tag chips (max 10, unique). A tap opens the Search tab with that tag (`openTagSearch` sets `pendingTagSearch`, and `SearchScreen` reads it).
3. **Make it live** button (Android, when `supportsOpenGlLiveWallpaper` is true). It opens `LiveWallpaperRoute(imageUrl: <full url>)`.
4. **More like this** strip.
5. A Report action for Prism wallpapers.

More like this (`SimilarWallpapersLoader`):

- Prism wallpapers: a `FirestoreClient` query on `walls`. Filters: `category` equals the current category and `review` equals true. Order: `createdAt` descending. Source tag: `wallpaper_detail.similar`. The cache policy is `memoryFirst`.
- The loader removes the current wallpaper and wallpapers from blocked creators. The maximum is 12 items.
- Wallhaven wallpapers: a search for the first tag through `WallpaperSearchService`.
- Pexels wallpapers: no strip.
- The strip is hidden while it loads, when it is empty, and on any error.
- A tap on a tile opens that wallpaper's detail screen.

Clock preview (the clock icon at the top right):

- A full-screen preview with a **Lock** and **Home** toggle. Android starts on Home. iOS starts on Lock.
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
| `lib/features/wallpaper_detail/views/widgets/make_it_live_button.dart` | Make it live. |
| `lib/features/ads/views/widgets/download_button.dart` | Download and gate. |
| `lib/core/widgets/menu_button/share_button.dart` | Share. |
| `lib/core/widgets/menu_button/fav_wallpaper_button.dart` | Favourite. |
| `lib/data/share/create_dynamic_link.dart` | Share link. |

## Limits

- The share link preview title is "Wallpaper by <creator>" when the creator is known. Otherwise it is "Wallpaper on Prism".
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
8. On Android with OpenGL support, tap **Make it live**. Make sure the live wallpaper screen opens.
9. Turn on airplane mode. Tap Share. Make sure an error toast shows and nothing is copied. Tap Favourite. Make sure the error toast shows.

Automated tests:

- `test/features/wallpaper_detail/views/pages/wallpaper_detail_action_bar_test.dart`
- `test/features/wallpaper_detail/views/widgets/wallpaper_detail_widgets_test.dart`
- `test/features/wallpaper_detail/views/widgets/clock_overlay_test.dart`
- `test/features/wallpaper_detail/biz/similar_wallpapers_loader_test.dart`
- `test/features/wallpaper_detail/biz/wallpaper_detail_rules_test.dart`
- `test/data/share/create_dynamic_link_test.dart`
- `test/core/widgets/share_button_test.dart`

Command: `fvm flutter test --no-pub test/features/wallpaper_detail`
