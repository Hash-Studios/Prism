# Wallpaper detail

The detail screen shows one wallpaper at full screen size. A floating liquid glass panel sits over the bottom of the wallpaper. The action bar is in the panel. The details and related wallpapers show when you open the panel.

## Where to find it

Tap a wallpaper in any feed, search, or favourites list. Route: `WallpaperDetailRoute`. Swipe up on the image to open the panel.

## Platforms

| Platform | Difference |
|---|---|
| Android | Primary action is **Set**. The bar also has Download. A **Live** glass pill above the panel and a **Make it live** button in the panel show when the device supports OpenGL live wallpapers. |
| iOS | Primary action is **Save** (a download to Photos). The bar has no separate Download or Set. No **Make it live** action. |

## Free and Pro

- **Set** is free. So is the Position studio (see `docs/features/set-wallpaper.md` and `docs/features/position-studio.md`).
- **Download** has a gate in `DownloadButton`. A Pro user downloads at no cost. A guest sees an ad gate pop-up with BUY PREMIUM. A signed-in user spends coins or watches a rewarded ad.
- A wallpaper in a premium collection costs 15 coins (`CoinPolicy.premiumWallpaperDownload`). Other wallpapers cost 5 coins (`CoinPolicy.wallpaperDownload`).
- Only Prism wallpapers can be premium. Wallhaven and Pexels wallpapers never are.

## How it works

Wallpaper and glass panel:

- The wallpaper fills the whole screen, behind the status bar and the panel. It is centred and cropped to fit (`BoxFit.cover`). The clock preview frames it the same way, so opening the preview does not move the wallpaper.
- The panel is glass (`PrismGlass`, the same surface as other chrome over a wallpaper). It floats 10 px from the left, right and bottom. At the bottom, the 10 px sits above the safe area. On the left and right, the 10 px sits beside the side safe area (landscape, or a 3-button bar on the side). The wallpaper stays full screen. All four corners are round (radius 40) when the panel is closed and when it is open.
- Closed, the panel is a dock: the collapse handle on top, then the action bar. Open, the glass grows up to 55 percent of the screen height. The colour bar, the details and the extras show above the action bar. The action bar does not move.
- The glass is drawn at its visible height, so its rounded bottom never gets cut off while the panel slides. The content is laid out at the open height and fades in with the panel position. Above the action bar the content fades out over 24 px (a `ShaderMask` with `BlendMode.dstIn`), so it never ends in a hard edge.
- The glass tint is the theme primary colour. Closed and open: 50 and 60 percent in a dark theme, 55 and 70 percent in a light theme. A light theme paints dark icons on a pale tint, so it needs more. Text in the panel that sits one step below the title (views, set count, row icons) is at 85 percent.
- Contrast, measured on a render of the Android (blurred) glass, for the worst case of each theme: a dark theme over a near white wallpaper (`#fafafa`) gives 3.6 to 1 for the dock icons, 5.2 to 1 for the open text and 4.3 to 1 for the dimmed text. A light theme over a near black wallpaper (`#050505`) gives 4.1 to 1, 6.5 to 1 and 4.8 to 1. Over a normal photo every dock icon and every text is above 5.3 to 1, even on its worst pixels.
- A soft shadow lifts the glass off the wallpaper: black at 14 percent (light theme) or 35 percent (dark theme), blur 24 or 28, offset 8 or 10 px down. It has the shape of the glass and is drawn outside it only, so it never darkens what the glass blurs. Its blur ends about 40 px above the dock.
- Swipe up on the wallpaper, drag the dock, or tap the handle to open the panel.
- The handle is one chevron. It turns over with the panel position, and it is the theme text colour at 70 percent. Its touch target is 96 by 48 px. It reaches 12 px down over the top of the action bar, so the dock is not taller. The action bar buttons are above it, so they keep their own taps.

Action bar (`WallpaperActionBar`):

- It sits on the glass, above the safe area, in an overlay beside the sliding panel (a `Stack` sibling). It does not move when the panel opens. It paints no surface of its own.
- Order: primary (Set or Save), Download (Android), Favourite, Share, Edit. Each icon button has a tooltip.
- The row is 24 px in from the left glass edge, so the Set pill lines up with the swatches and the text. It is 16 px in from the right.
- Every button shrinks to 0.96 under the finger (`PressScale`, 100 ms down and 140 ms up, ease out both ways). `CircularMenuButton` does this itself, so the screen wraps only the Set pill, the Save pill and Favourite. A button never scales twice. A round button takes taps on its whole circle, not only on the icon.

Colour variations:

- Tap the wallpaper to cycle through the palette. Each tap tints the whole wallpaper with the hue of the next colour (`ColorFiltered` with `BlendMode.hue`, over the image). The change slides in about 220 ms, or at once when the device asks for less motion. The slide blends the two colours in HSL space and the hue takes the short way round (`lerpHueTint`), so it never fades through grey. Long press the wallpaper to bring back the original.
- The colour bar shows the original first, then one swatch per palette colour. Each swatch is the wallpaper thumbnail with that hue. A bar in the swatch colour is at its bottom. Tap a swatch to pick it. It plays the selection haptic, like a tap on the wallpaper. Long press a swatch to copy its hex code.
- The back and clock buttons always follow the accent. At first, the accent is the first palette colour and the wallpaper stays original. The wallpaper only changes after you pick a colour.
- Set, Download (Save on iOS) and Edit use the tinted image. Set and Edit get `prepareSource`, which calls `renderTintedWallpaper` (`wallpaper_tint_renderer.dart`). It draws the full wallpaper with the same hue blend and returns a PNG path. Download gets a `DownloadVariant` with the key `tint-<rrggbb>` and the same `prepare`. Each colour is its own purchase, and a finished tinted download is remembered in `DownloadedWallIndex` under `variant.identityOf(url)`, not under the wallpaper link. With the original showing, the buttons use the wallpaper as before.
- The clock preview shows the same hue (`ClockOverlay.tint`).

Header (top of the panel):

- The headline is the title the creator gave (`PrismWallpaper.title`). Older uploads have no title, so the headline reads "Wallpaper by <creator name>". When the name is empty or looks like an email, it reads "Wallpaper by Prism creator". The app never shows an email here. The share link title is the same text. Wallhaven and Pexels walls keep their id as the headline.
- Next to it: "N views" and, from 5 sets on, "Set N times". The count is `wallpaper_stats.sets`, read with source tag `wallpaper_stats.detail`. It is hidden for fewer than 5 sets and when the read fails.
- A successful Set on a Prism wall calls the `recordWallpaperAction` callable with `set` (`RecordWallpaperActionUseCase`).

Image overlays: the back button, the clock button, and on Android a **Live** pill. The pill is a small glass chip with a 48 px touch target. It sits 12 px above the top edge of the panel, 24 px in from the glass edge (in line with the Set pill). The glass tint is 65 percent in a light theme and 60 percent in a dark theme. It fades in over 160 ms when the device answers that it supports live wallpapers. The label scales with the system text up to 1.5 times, and the pill width follows the label. It rises with the panel and fades out before the panel is half open. It opens Make it live with the first palette colour as `accentSeed`.

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
| `lib/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart` | Screen, glass panel, colour variations. |
| `lib/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart` | Bar layout. |
| `lib/features/wallpaper_detail/data/wallpaper_tint_renderer.dart` | `renderTintedWallpaper`: the tinted PNG for Set, Download and Edit. |
| `lib/core/widgets/prism_glass.dart` | The glass surface for the panel and the Live pill. `thickness` is the iOS refraction depth. Pills of 48 px or less pass 16. |
| `lib/core/widgets/animated/press_scale.dart` | Press feedback. It does not set a filter quality, because that would drop the blurred backdrop of any glass inside it. |
| `lib/core/widgets/menu_button/circular_menu_button.dart` | The round action buttons. |
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
| `lib/features/wallpaper_detail/views/widgets/make_it_live_button.dart` | Make it live button and the Live pill. |
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
- Not confirmed on a device: the real glass refraction on iOS (the tests draw the blurred fake that Android uses), the glass tint on every theme, and the layout on small screens. The contrast numbers above are for the Android glass.
- While the Live pill fades in or out, it is inside an opacity layer, so its glass shows the tint without the blur until it is fully there.
- The handle is a hint, not text. On the worst wallpapers above it is about 2.6 to 1 (worked out from the tint, not measured on a render).
- The colour tint needs the full image to render for Set, Download and Edit. The first tap on one of them can take a moment. The same colour on the same wallpaper reuses the file.

## How to test

1. Open any Prism wallpaper on Android. Make sure the wallpaper fills the screen behind the glass panel and the panel floats with round corners on all sides. Make sure the bar shows Set, Download, Favourite, Share, Edit. Make sure the image has no color tint.
2. On iOS, make sure the bar shows Save, Favourite, Share, Edit. Open a bright wallpaper. Make sure the icons in the dock are readable.
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
15. Tap the wallpaper. Make sure the whole wallpaper changes hue and the back button changes colour. Tap again. Make sure the next colour shows. Long press. Make sure the original comes back.
16. Swipe up. Make sure each swatch shows the wallpaper in its own colour. Pick a swatch. Make sure the wallpaper changes. Long press a swatch. Make sure the hex code is copied.
17. With a colour picked, tap Set, then Download (or Save on iOS), then Edit. Make sure each one uses the tinted wallpaper. Tap the clock icon. Make sure the preview shows the same hue.
18. Watch the glass while you open and close the panel. Make sure its rounded bottom stays in view all the time and the action bar does not move. Make sure the chevron turns over, and the content fades out above the action bar instead of being cut.
19. Open a bright wallpaper in the light theme and in the dark theme. Make sure the dock icons and the panel text are easy to read. Make sure the shadow under the dock does not darken the wallpaper above it.
20. Press and hold the Live pill. Make sure it shrinks and the glass stays blurred. Hold Download, Share and Edit. Make sure each shrinks a little, once.
21. On a phone in landscape, or with a 3-button bar on the side, make sure the dock and the Live pill stay clear of the side bar and the wallpaper still fills the screen.
22. Pick a colour, then another. Make sure the hue turns over and does not go grey in between. Tap a swatch. Make sure you feel a light tick.

Automated tests:

- `test/features/wallpaper_detail/views/pages/wallpaper_detail_action_bar_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_glass_panel_test.dart`
- `test/features/wallpaper_detail/views/wallpaper_detail_motion_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_header_test.dart`
- `test/features/wallpaper_detail/views/pages/wallpaper_detail_set_flow_test.dart`
- `test/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc_test.dart`
- `test/core/widgets/content_report/content_report_sheet_test.dart`
- `test/features/wallpaper_detail/views/widgets/wallpaper_detail_widgets_test.dart`
- `test/core/widgets/press_scale_test.dart`
- `test/core/widgets/circular_menu_button_test.dart`
- `test/features/wallpaper_detail/views/widgets/clock_overlay_test.dart`
- `test/features/wallpaper_detail/views/widgets/preview_layers_test.dart`
- `test/features/wallpaper_detail/biz/similar_wallpapers_loader_test.dart`
- `test/features/wallpaper_detail/biz/wallpaper_detail_rules_test.dart`
- `test/data/share/create_dynamic_link_test.dart`
- `test/core/widgets/share_button_test.dart`

Command: `fvm flutter test --no-pub test/features/wallpaper_detail`
