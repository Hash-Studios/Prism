# Layout

The Layout settings set the order and visibility of the bottom bar tabs. They also set the size of every wallpaper grid and the place of the profile and notifications buttons. The Home feed opens on the tab the user saw last.

## Where to find it

- Settings, row **Layout**, under APPEARANCE. The row subtitle reads "Tabs and wallpaper grid". The route is `/layout` (`LayoutSettingsRoute`). Code: `lib/features/layout_prefs/views/pages/layout_settings_page.dart`.
- The **More** entry in the bottom bar. It shows when at least one tab is hidden. Its sheet has **Edit tabs**, which opens Layout.
- Pinch the Home feed to change the grid density. See [home-feed.md](home-feed.md).

## Platforms and plans

| Item | Android | iOS | Plan |
|---|---|---|---|
| Tabs, grid density, reset | yes | yes | Free |
| One-handed controls | yes | yes | Free |
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
| `lib/features/layout_prefs/views/widgets/one_handed_preview.dart` | `OneHandedPreview`. The live sketch above the one-handed switch. |
| `lib/features/navigation/views/widgets/account_controls.dart` | `NotificationBell`, `ProfileAvatarButton` and `AccountButton`. The profile and notifications buttons of both bars. |
| `lib/features/navigation/views/widgets/bottom_nav_bar.dart` | `BottomBar`. Adds the one-handed controls to the bottom row. `oneHandedRowHasRoom` selects the wide or the narrow row. |
| `lib/features/navigation/views/widgets/prism_top_app_bar.dart` | `PrismTopAppBar`. Removes the avatar and the bell when one-handed controls are on. |
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
- **Reset layout** sets the tab order, the visibility, the density and the one-handed controls back to the defaults. The feed tab stays.

### One-handed controls

The **Controls** section has the switch **One-handed controls**. It is off by default. A small sketch above the switch shows where the buttons go. The sketch moves when the switch changes. With reduced motion, it changes at once.

When the switch is on:

- The avatar and the bell leave the top bar of Home. The wordmark stays. The top bar keeps its height.
- The avatar and the bell go into the bottom row, next to the tab pill and **Create**. They hide and show with the bottom row when you scroll.
- The tab pill keeps its size. The tabs, **Create** and the deep links do not change.
- Each control has a 44 point target, a disc in the pill colour and the pill shadow, so it is easy to see on a wallpaper.

The width of the screen sets the row. The floating bar keeps 10 px free at each side, so the row has the screen width minus 20 px, minus the side insets.

| Screen width (logical px, without the side insets) | Bottom row |
|---|---|
| 384 or more | Avatar, tab pill, **Create**, bell |
| 336 to 383 | Avatar, tab pill, **Create** |
| Less than 336 | Tab pill and **Create**. The avatar stands above **Create**. |

- On a wide screen, the avatar opens the profile and the bell opens Notifications. The bell shows the unread dot.
- On a narrower screen (for example 360 or 320), the row has no room for the bell. The avatar shows the unread dot. It opens the sheet **Profile and notifications** from the bottom. The sheet has the rows **Your profile** and **Notifications**. The Notifications row shows the unread count, for example "2 unread".
- No layout makes the tab pill or a control smaller. Each target stays 44 points or more.
- When the avatar stands above **Create**, snackbars move up by the height of the avatar, so they do not cover it.
- In the side rail of the iPhone Duo outer screen, the avatar and the bell go above the tab pill.
- In a right-to-left language, the row is mirrored. The avatar is at the right.
- When the switch is off, the top bar and the bottom row are the same as before. `test/features/navigation/one_handed_off_golden_test.dart` compares them with goldens drawn from master.
- A guest can use the switch. The avatar opens the guest profile, the same as the top bar.

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

- The layout syncs with the field `layoutPrefs` of `usersv2/{uid}`. The field holds `{tabs, hidden, density, changedAt}`. It also holds `oneHanded: true` when one-handed controls are on. The app does not write `oneHanded` when it is off.
- The last change wins. This is the same rule as the theme.
- Sync runs in the sign-in bootstrap, after the theme sync. The account copy wins when its `changedAt` is the same or newer. Else the device copy uploads.
- A signed-out user keeps the device copy. A change uploads only while the user is signed in.
- The feed tab stays on the device. It does not sync.

### Device storage

| Settings key | Value |
|---|---|
| `layout.prefs` | JSON of `{tabs, hidden, density}`, and `oneHanded: true` when it is on. |
| `layout.feed_tab` | Name of the feed tab, for example `latest`. |
| `layout.changed_at` | Time of the last change, in milliseconds. |

### Analytics

| Event | Fields | Sent when |
|---|---|---|
| `layout_tabs_reordered` | `tab`, `to_position` | The user moves a tab. |
| `layout_tab_visibility_changed` | `tab`, `visible` | The user changes a tab switch. |
| `layout_density_changed` | `density`, `source` (`settings` or `pinch`) | The user changes the density in Layout or by pinch. |
| `layout_reset` | None | The user taps **Reset layout** and the layout is not the default. |
| `layout_one_handed_toggled` | `enabled` (`1` or `0`) | The user changes the one-handed controls switch. |
| `notifications_opened` | `source` (`top` or `bottom`) | The user opens Notifications from the bell in the top bar (`top`), or from the bell or the sheet in the bottom row (`bottom`). |

## Limits

- The feed tab does not sync to other devices.
- The pinch position is approximate. Headers and mood rows change the scroll offset.
- On a narrow screen, notifications are one more tap away: avatar, then **Notifications**.
- A hidden tab can still open by a deep link or a push. The bar shows it again only when the user shows it.

## Deploy notes

- The rules change adds the optional field `layoutPrefs` to `usersv2`. Deploy the rules before a release that writes the field. Otherwise the write is refused. The app only logs the refused write.
- The win-back change in `functions/src/winBack.ts` needs a functions deploy.
- One-handed controls add the optional bool `oneHanded` to `layoutPrefs` (issue #587). Deploy order:
  1. Deploy `firestore.rules` (`firebase deploy --only firestore:rules`).
  2. Release the app.
- If the app ships first, the account write is refused only while the switch is on. The device copy still works, and the app only logs the refused write. A copy with the switch off has no `oneHanded` key, so the old rules accept it.
- An older app reads a synced layout and ignores `oneHanded`. When an older app changes the layout, it writes the map without `oneHanded`, so the switch goes back to off on the other devices. This is the same last-change-wins rule.
- No functions change.

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
11. Set **One-handed controls** to on. Make sure the sketch moves the avatar and the bell to the bottom. Open Home. Make sure the top bar shows only the wordmark, and the bottom row has the avatar and the bell (or only the avatar on a narrow phone).
12. With an unread notification, make sure the bell (or the avatar on a narrow phone) shows the dot. Open Notifications from it. Read all. Go back. Make sure the dot is gone.
13. Scroll the feed down. Make sure the avatar and the bell hide with the tab pill. Scroll up. Make sure they show again.
14. Set **One-handed controls** to off. Make sure the top bar and the bottom row look as before.

Automated tests:

- `test/features/layout_prefs/domain/layout_prefs_test.dart`
- `test/features/layout_prefs/data/layout_prefs_store_test.dart`
- `test/features/layout_prefs/views/layout_settings_page_test.dart`
- `test/features/navigation/one_handed_controls_test.dart`
- `test/features/navigation/one_handed_off_golden_test.dart`
- `test/features/personalized_feed/biz/bloc/feed_tab_restore_test.dart`
- `test/features/personalized_feed/feed_carousel_columns_test.dart`
- `test/core/router/home_feed_link_test.dart`
