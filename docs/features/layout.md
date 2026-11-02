# Layout

The Layout settings set the order and visibility of the bottom bar tabs. They also set the size of every wallpaper grid. The Home feed opens on the tab the user saw last.

## Where to find it

- Settings, row **Layout**, under APPEARANCE. The row subtitle reads "Tabs and wallpaper grid". The route is `/layout` (`LayoutSettingsRoute`). Code: `lib/features/layout_prefs/views/pages/layout_settings_page.dart`.
- The **More** entry in the bottom bar. It shows when at least one tab is hidden. Its sheet has **Edit tabs**, which opens Layout.
- Pinch the Home feed to change the grid density. See [home-feed.md](home-feed.md).

## Platforms and plans

| Item | Android | iOS | Plan |
|---|---|---|---|
| Tabs, grid density, reset | yes | yes | Free |
| Remembered feed tab | yes | yes | Free |

A guest can use Layout. The guest copy stays on the device.

## How it works

| Path | Role |
|---|---|
| `lib/features/layout_prefs/domain/entities/layout_prefs.dart` | `LayoutPrefs`, `NavTab` and `WallGridDensity`. The rules for tabs, hidden tabs and density. |
| `lib/features/layout_prefs/data/layout_prefs_store.dart` | `LayoutPrefsStore`. Keeps the device copy, syncs the account copy and saves the feed tab. |
| `lib/features/layout_prefs/views/layout_prefs_scope.dart` | `LayoutPrefsScope`. Gives the layout to the widget tree. |
| `lib/features/layout_prefs/views/nav_tab_view.dart` | Icon, label and analytics value of each tab. |
| `lib/features/layout_prefs/views/pages/layout_settings_page.dart` | The Layout page. |
| `lib/features/layout_prefs/views/widgets/pinch_density.dart` | `PinchDensity`. Changes the density by a pinch. |
| `lib/features/navigation/views/widgets/prism_bottom_nav.dart` | The bottom bar. Draws the visible tabs and the More entry. |
| `lib/core/widgets/prism/prism_wall_grid.dart` | `PrismWallGrid.columns`. The column count of every wallpaper grid. |
| `lib/core/widgets/prism_image_tile.dart` | `gridTileDecodeHeight`. The decode size of a grid tile. |
| `lib/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart` | Opens the feed on the remembered tab. Follows a new tab from a link or a push. |
| `lib/auth/post_sign_in.dart` | `_syncAccountLayout`. Syncs the layout in the sign-in bootstrap. |
| `lib/core/router/notification_route_mapper.dart` | Reads the `feed` field of a push. |
| `lib/core/router/deep_link_catalog_resolver.dart` | `_homeRoute`. Saves the tab named by `/dashboard/home?feed=`. |
| `functions/src/winBack.ts` | `feedFor`. Adds `feed: latest` to the day 7 and day 14 pushes. |
| `firestore.rules` | `validLayoutPrefs`. Checks the `layoutPrefs` field of `usersv2`. |

### Tabs

- The bar shows the tabs in the order the user sets. Drag the handle of a row to move it. Screen reader users can use the actions **Move up** and **Move down**.
- Use the switch of a row to show or hide the tab. Home always shows.
- At least 3 tabs stay in the bar. The switch of a tab cannot hide it when only 3 tabs show.
- A hidden tab opens from **More**. The sheet lists the hidden tabs in bar order.
- A deep link or a push to a hidden tab still opens that tab. The dashboard keeps all four routes in a fixed order. The bar only changes what it draws. **More** shows as selected then.
- A hidden row shows "Under More". The Home row shows "Always in the bar".
- **Reset layout** sets the tab order, the visibility and the density back to the defaults. The feed tab stays.

### Grid density

There are three densities. Each one has a minimum column count and a tile width.

| Density | Minimum columns | Tile width | Columns on a phone 390 px wide |
|---|---|---|---|
| Compact | 3 | 120 px | 3 |
| Comfortable (default) | 2 | 180 px | 2 |
| Large | 1 | 360 px | 1 |

The column count is the screen width divided by the tile width, rounded down. It is never less than the minimum and never more than 8. A tablet or a landscape phone is wider, so it gets more columns.

- The setting applies to every wallpaper grid. Each grid reads `PrismWallGrid.columns`.
- Spread two fingers on the Home feed to make the tiles bigger. Pinch to make them smaller. Each pinch moves one step and gives a selection haptic.
- The feed keeps about the same place after a pinch. The position is approximate in headers and mood rows.
- Tiles always load the thumbnail. The decode size follows the column width. Compact decodes smaller images.
- Tiles show the image only.

### Feed tab

- The Home feed opens on the tab the user saw last. The app keeps this choice on the device.
- A guest never opens on **Following**. The feed opens on **For you** instead.
- The **For you** quick action on the Home screen opens **For you**. It saves that tab first.
- A push or a link with `feed=<tab>` saves the tab first. The link wins over the remembered tab. This is also true when the link arrives after the feed opened.
- The win-back pushes on day 7 and day 14 send `route: home` and `feed: latest`. They open **Latest** (issue #569). Older builds ignore `feed` and open Home.
- Home has no category picker. Categories open as their own pages. Only the feed tab is restored.

### Sync with the account

- The layout syncs with the field `layoutPrefs` of `usersv2/{uid}`. The field holds `{tabs, hidden, density, changedAt}`.
- The last change wins. This is the same rule as the theme.
- Sync runs in the sign-in bootstrap, after the theme sync. The account copy wins when its `changedAt` is the same or newer. Else the device copy uploads.
- A signed-out user keeps the device copy. A change uploads only while the user is signed in.
- The feed tab stays on the device. It does not sync.

### Device storage

| Settings key | Value |
|---|---|
| `layout.prefs` | JSON of `{tabs, hidden, density}`. |
| `layout.feed_tab` | Name of the feed tab, for example `latest`. |
| `layout.changed_at` | Time of the last change, in milliseconds. |

### Analytics

| Event | Fields | Sent when |
|---|---|---|
| `layout_tabs_reordered` | `tab`, `to_position` | The user moves a tab. |
| `layout_tab_visibility_changed` | `tab`, `visible` | The user changes a tab switch. |
| `layout_density_changed` | `density`, `source` (`settings` or `pinch`) | The user changes the density in Layout or by pinch. |
| `layout_reset` | None | The user taps **Reset layout** and the layout is not the default. |

## Limits

- The feed tab does not sync to other devices.
- The pinch position is approximate. Headers and mood rows change the scroll offset.
- A hidden tab can still open by a deep link or a push. The bar shows it again only when the user shows it.

## Deploy notes

- The rules change adds the optional field `layoutPrefs` to `usersv2`. Deploy the rules before a release that writes the field. Otherwise the write is refused. The app only logs the refused write.
- The win-back change in `functions/src/winBack.ts` needs a functions deploy.

## How to test

1. Open **Settings** and tap **Layout**. Make sure the page shows the sections **Tabs** and **Wallpaper grid**.
2. Drag the handle of **Rewards** to the top. Make sure the bar shows Rewards first.
3. Set the **Search** switch to off. Make sure the bar has no Search tab and shows **More**. Tap **More**. Make sure **Search** is in the sheet.
4. With 3 tabs in the bar, make sure their switches cannot turn off.
5. Tap **Compact**. Open **Search**. Make sure the grid has 3 columns on a phone. Tap **Large**. Make sure one tile shows in each row.
6. Tap **Reset layout**. Make sure the bar and the grid return to the defaults.
7. Open Home. Pinch out on the feed. Make sure the tiles get bigger in one step.
8. Open Home on **Latest**. Close the app and open it again. Make sure Home opens on **Latest**.
9. Open `prism://dashboard/home?feed=popular` on the device. Make sure Home opens on **Popular**.
10. Change the layout on one device while signed in. Sign in on a second device. Make sure the second device shows the same layout.

Automated tests:

- `test/features/layout_prefs/domain/layout_prefs_test.dart`
- `test/features/layout_prefs/data/layout_prefs_store_test.dart`
- `test/features/personalized_feed/biz/bloc/feed_tab_restore_test.dart`
- `test/features/personalized_feed/feed_carousel_columns_test.dart`
- `test/core/router/home_feed_link_test.dart`
