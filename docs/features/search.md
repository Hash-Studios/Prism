# Search

The user types a word and gets wallpapers from Wallhaven, with Pexels as a fallback. Matching Prism catalogue wallpapers show first in a "From Prism" row. The user can narrow results with filters, search by colour, and search by photo.

## Where to find it

- The **Search** tab in the bottom bar (`SearchScreen`, `lib/features/user_search/views/pages/search_screen.dart`).
- The tag chips on the wallpaper detail screen. A tap on a chip opens the Search tab and runs that tag.
- The **Filters** icon (tune icon) in the search bar opens the filter sheet.
- The **Search by photo** icon (image search icon) in the search bar opens the camera roll.

## Platforms

Android and iOS. The code has no platform branch.

## Free and Pro

Search is free. The search files contain no premium or coin gate.

## How it works

| Path | Role |
|---|---|
| `lib/features/user_search/views/pages/search_screen.dart` | Search bar, discover view, results, error and empty states. |
| `lib/features/user_search/views/widgets/search_discovery_widget.dart` | Discover view: recent searches, tag suggestions, "Browse by colour", trending, categories. |
| `lib/features/user_search/data/search_tags.dart` | The fixed list of tag suggestions. |
| `lib/features/category_feed/views/widgets/wallpaper_quick_actions.dart` | The long-press sheet on a result tile. |
| `lib/features/user_search/views/widgets/search_grid.dart` | Result grid, "From Prism" row, pagination, pull to refresh. |
| `lib/features/user_search/views/widgets/search_filter_sheet.dart` | Filter sheet and the mapping from choices to `SearchFilters`. |
| `lib/features/user_search/data/recent_searches_store.dart` | Recent searches in local settings. |
| `lib/features/user_search/data/search_filters.dart` | `SearchFilters`, `SearchSort`, `SearchSource` and `PrismWallKind`. |
| `lib/features/user_search/data/search_link.dart` | The search link keys and their parser. Plain Dart, so the deep link catalog can use it. |
| `lib/core/color/prism_palette.dart` | The 12 palette colours and `nearestPaletteColor`. |
| `lib/features/user_search/views/widgets/palette_swatch.dart` | The round colour swatch. |
| `lib/features/user_search/data/wallpaper_search_service.dart` | Runs the search. Falls back to Pexels. Throws on total failure. |
| `lib/features/user_search/data/repositories/user_search_repository_impl.dart` | Finds creators by name or username. |
| `lib/features/prism_feed/data/prism_wall_search.dart` | Finds Prism walls by tag or category in Firestore. |
| `lib/features/wallpaper_detail/biz/tag_search_launcher.dart` | `openTagSearch` hands a tag to the Search screen. |
| `lib/features/user_search/domain/entities/photo_query.dart` | `PhotoQuery`: the palette, labels and category of a picked photo. |
| `lib/features/user_search/data/photo_search_service.dart` | Picks the photo, makes the clean 512 px copy, reads the palette, calls `photoSearchLabels`. |
| `lib/features/user_search/data/photo_palette.dart` | The palette of a photo, in an isolate. |
| `lib/features/user_search/data/photo_match_ranking.dart` | Ranks Prism walls by palette closeness and label overlap. |
| `lib/features/user_search/views/widgets/photo_search_chip.dart` | The photo chip above photo results. |
| `functions/src/photoSearchLabels.ts` | The `photoSearchLabels` callable: Cloud Vision labels, the daily cap. |

Data path:

```text
query + SearchFilters
  -> PrismWallSearch (Firestore walls)      -> prismResults ("From Prism" row)
  -> Wallhaven page 1                       -> results
       fails -> Pexels page 1               -> results
       fails -> WallpaperSearchException    -> error state with Try again
```

A Prism only search skips Wallhaven and Pexels. See [Prism wall filters](#prism-wall-filters).

### Search bar

- The keyboard action is Search. A search runs when the user submits a non-empty query.
- A clear (X) button shows when the field has text. Its tooltip is "Clear search". A tap clears the field and returns to the discover view.
- System back from results returns to the discover view before the user leaves the tab.
- The Filters icon shows a badge with the number of filters that are on. Each kind and the Prism walls only switch count as one filter.

### Tag suggestions

- The discover view shows 21 tag chips. They are the 18 category names that the upload classifier writes (`Nature`, `Architecture`, `Cars`, `Anime`, `Space`, `Ocean`, `Flowers`, `Neon`, `Dark`, `Abstract`, `3D Render`, `Minimal`, `Gradient`, `AI Art`, `Cyberpunk`, `Vintage`, `Landscape`, `Galaxy`), then `AMOLED`, `Pastel` and `Cityscape`.
- The order is fixed. It does not change when the user opens the screen again.
- A tap on a chip runs that tag as a search.

### Recent searches

- The discover view lists recent searches as chips. A **Clear** button next to "Recent searches" removes all of them.
- `RecentSearchesStore` keeps the last 10 queries (`maxItems = 10`), newest first.
- A repeat of an older query, ignoring case, moves to the front. It does not make a copy.
- The store uses the key `search.recent` (`PersistenceKeys.recentSearches`).

### Tag chips from the detail screen

- The detail screen shows up to 10 tag chips for a Prism or a Wallhaven wallpaper (`wallpaperTags`).
- A Pexels wallpaper has no tags in the app, so the screen shows no chips for it.
- A tap calls `openTagSearch`. It sets `pendingSearch` and opens the Search tab. `SearchScreen` reads the value, fills the field, and runs the search.

### Filters

| Filter | Choices | Default |
|---|---|---|
| Portrait only | On or off | On |
| Min resolution | Any, 1080p, 1440p, 4K | Any |
| Sort | Relevance, Latest, Top | Relevance |
| Colour | One of 12 palette colours, or none | None |

The sheet has **Clear all** and **Apply**. **Clear all** turns every filter off at once. It does not wait for **Apply**. If a search is on screen, a changed filter runs it again.

The sheet also has a **Prism walls** section and, on iOS, a Depth Effect switch. The Spatial Scene filter has no switch in the sheet. See [Prism wall filters](#prism-wall-filters).

The sheet turns "Min resolution" into `<width>x<height>`. With Portrait only on, the long side is the short side times 16/9, rounded. 1080p becomes `1080x1920`, 1440p becomes `1440x2560`, and 4K becomes `2160x3840`. With Portrait only off, the value is a square such as `1080x1080`.

Mapping of `SearchFilters` to each source:

| Filter | Wallhaven | Pexels | Prism row |
|---|---|---|---|
| Portrait only | `ratios=portrait` | `orientation=portrait` | Drops walls wider than tall. |
| Min resolution | `atleast=<width>x<height>` | Client filter on the result resolution. | Client filter on the wall resolution. |
| Sort | `sorting=date_added` (Latest), `sorting=toplist` (Top). Relevance sends no `sorting`. | Not used. | Not used. |

A wall with an unknown resolution passes the client filters.

The colour filter is in the next section.

### Colour

Search by colour uses one palette of 12 colours: red, orange, yellow, green, teal, blue, purple, pink, brown, black, grey and white. The palette is in `lib/core/color/prism_palette.dart`. Each colour has an id, a hex value for Wallhaven, and a name for Pexels.

How to use it:

- Open **Filters**. The **Colour** row shows 12 round swatches. Each swatch has the colour name as its screen reader label. The selected swatch has a ring.
- Tap a swatch to choose it. Tap the same swatch again to clear it. The user can choose one colour at a time.
- **My accent** picks the palette colour that is nearest to the accent colour of the user. The distance is CIE76 in Lab space (`nearestPaletteColor`).
- In the discover view, **Browse by colour** shows the same 12 swatches in a row. A tap on a swatch opens results for that colour. No query is needed.
- When a colour is active, a chip with the colour name shows above the results. The chip has a **Clear colour** button.
- The colour is part of `SearchFilters`. It lives in the screen state like the other filters. It does not survive a restart of the app.
- Back from a colour-only search returns to the discover view and drops the colour. Back from a text search keeps the colour.

Mapping of the colour to each source:

| Source | Parameter | Query |
|---|---|---|
| Wallhaven | `colors=<hex>` (for example `0066cc`) | Optional. An empty query sends no `q`. |
| Pexels | `color=<name>` (for example `violet` for purple, `gray` for grey) | Required. A colour-only search skips Pexels. |
| Prism catalogue | `where colors array-contains <id>` | Optional. |

The colour-only Prism query is `review == true`, `colors array-contains <id>`, newest first. It needs the index `colors` (array contains), `review`, `createdAt` (descending). The index is in `firestore.indexes.json`.

A text query with a colour cannot use one Firestore query. Firestore does not allow two array filters in one query. The Prism search runs the tag and category queries with a limit of 48, then keeps the walls that have the colour. A wall without the `colors` field matches no colour filter.

The backend writes `walls.colors` (1 to 3 palette ids, most dominant first). An old wall has the field only after the backfill script runs. See `docs/features/backend-deploy.md`.

The page cursor key for a colour search is `search:<query>:color:<id>`. The Wallhaven cache scope also holds the colour.

### Prism wall filters

The **Prism walls** section of the filter sheet has three kind chips and the **Prism walls only** switch. Depth Effect and Spatial Scene also show only Prism walls.

#### Data shape

`SearchFilters` holds these fields:

| Field | Values | Default |
|---|---|---|
| `source` | `SearchSource.all` (All) or `SearchSource.prism` (Prism only) | All |
| `kinds` | Any set of `PrismWallKind.live`, `desktop` and `lightDark` | Empty |

Each kind is off by default. A wall must have every selected kind. Two selected kinds show fewer walls than one.

#### What each kind means in Firestore

| Kind | Chip | Firestore condition | Order |
|---|---|---|---|
| Live | Live | `kind == 'live'` | Newest first |
| Desktop version | Desktop version | `desktopVariant.width > 0` | Widest first, then newest |
| Light and dark | Light and dark | `variantIndex == 0` | Newest first |

- A live wall is a short looping video. The server sets `review` to true only after it verifies the video.
- A desktop version is a wide version of the wall. The wall stores it in `desktopVariant`.
- A light and dark wall is part of a colour variant set. The set has a `variantGroupId`. When Light and dark owns the browse query, it lists only `variantIndex == 0`, so each set shows one time. In every other case more than one wall of a set can show. With a colour, the colour query runs instead, because the members of a set have different colours. When Depth Effect, Spatial Scene, Live or Desktop version owns the query, the device checks only `variantGroupId`. A text search also checks only `variantGroupId`.

#### Why there is no watch version filter

`showsWatchSet` in `lib/features/watch_set/views/watch_set_row.dart` returns true for every Prism wall that is not a Duo pair. A watch version filter would hide only Duo pairs. So the sheet has no such filter.

#### Prism only searches

A kind filter, Depth Effect, Spatial Scene or **Prism walls only** makes the search Prism only. Wallhaven and Pexels are not called.

A Prism only search has no next page. The grid does not request further pages.

When a kind is on, one line under the active filters says `Only Prism walls have these kinds, so Wallhaven and Pexels results are hidden.` The **Prism walls only** switch is on while a kind is on. When the user turns it off, the kinds turn off too.

#### Server and device checks

The query uses the server for one filter. The device checks every filter on the walls that the query returns.

| Case | Where it runs | Detail |
|---|---|---|
| Empty query, one or more filters | Server, one query | Depth Effect first, then Spatial Scene, then the first kind selected in the order Live, Desktop version, Light and dark, then colour. Light and dark with a colour skips the Light and dark server filter. Another selected kind can own the query; otherwise the colour query runs. |
| Colour, Depth Effect, Spatial Scene and kinds | Device | Each wall must pass every filter. A filter that the query used is checked again. |
| Portrait only and Min resolution | Device | Checked for every Prism query. A wall with an unknown resolution passes. |
| Reads | Server | A browse with one filter reads the limit. A browse with two or more filters reads 4 times the limit. A text query reads 4 times the limit when it has a filter or more than one word. |

Limits:

| Search | Limit |
|---|---|
| Empty query on a Prism only search | 48 |
| Prism only text query | 24 |
| Prism row of a normal search | 12 |

The reads above are a bounded window, not a complete scan. Device checks can reject every wall in that window, so the first page can be empty even when an older matching wall exists. There is no automatic retry with a larger window.

#### The gate

Every query keeps `review == true`. For a walls query, `FirestoreTrackedClient` also adds six equality checks. `originalProtected` must be true, and `wallpaper_url`, `wallpaper_path`, `wallpaper_sha`, `thumb_path` and `thumb_sha` must be empty.

A wall in review, or a wall that waits for its `releaseAt` time, has `review` false. It never shows. Blocked creators are removed from every result.

#### Filter sheet and results row

- A tap on a kind chip turns that kind on or off.
- The **Prism walls only** switch sits under the kind chips. It is on while a kind is on. Turning it off turns every kind off.
- The Depth Effect switch shows on iOS only.
- **Clear all** in the sheet turns every filter off. It applies at once.
- The results row has chips for colour, Depth Effect, Spatial Scene, kinds and the explicit Prism-only source. A tap on a chip removes that filter. Orientation, resolution and sort remain in the sheet. The filter button count includes every setting that differs from its default. **Clear all** in the row turns every filter off.

#### Discover row

The **Live walls** row in the discover view shows when the discovery load finds at least one live wall. A tap opens search with the Live filter on. Other kinds turn off, so the list shows live walls. The other filters keep their values. The check reads only the newest live wall. If that wall belongs to a blocked creator, the row stays hidden even when an older visible live wall exists.

#### Links

A search link holds the query and its filters. For example, `/dashboard/search?q=sky&kind=live` searches for sky and shows only live walls.

| Key | Values | Default |
|---|---|---|
| `q` | Text, up to 200 characters, with no control characters | None |
| `kind` | Comma list of `live`, `desktop` and `light-dark` | None |
| `source` | `all` or `prism` | `all` |
| `color` | Palette id, for example `blue` | None |
| `sort` | `relevance`, `latest` or `toplist` | `relevance` |
| `res` | `<width>x<height>`, for example `1080x1920` | Any |
| `portrait` | `true` or `false` | `true` |
| `depth` | `true` | Off |
| `spatial` | `true` | Off |

- Default values are left out. A plain search is `/dashboard/search?q=sky`.
- A bad value makes the catalog refuse the link. An unknown kind is one bad value.
- A colour that is not in the palette opens Search unchanged, preserving any current query and filters.
- A link with none of these keys opens Search as before.
- A link with only `source`, `sort`, `res` or `portrait` sets the filters but does not load results. Results load after the user types a query or turns on a kind, a colour, Depth Effect or Spatial Scene.
- When `depth` and `spatial` are both true, Depth Effect wins. Spatial Scene is dropped.
- The path is `/dashboard/search`. `/search` is not an app path. The Android manifest and the iOS associated domains list only `/dashboard/search`.

#### Analytics for filters

| Event | Fields | When |
|---|---|---|
| `search_filter_applied` | `filters`, the names of the filters that are on | The sheet applies a changed filter set. |
| `search_kind_results` | `kinds`, `result_count`, `search_id` | A search with a kind filter loads. |

The `filters` names are `any_orientation`, `min_resolution`, `sort`, `color`, `depth`, `spatial`, `prism_only`, `kind_live`, `kind_desktop` and `kind_light-dark`. The `kinds` field uses the link values: `live`, `desktop` and `light-dark`.

#### Deploy order

Deploy the three Firestore indexes before the client release. They are in `firestore.indexes.json`. Each index has the six protected-wall fields, then `review`, then the kind field, then `createdAt`.

Until the indexes are built, a kind browse fails. The list is empty, and the search logs that the index is not deployed yet. The **Live walls** row stays hidden. Only the kind browse uses these indexes.

### Search by photo

The user picks a photo, for example an outfit, a room or a sunset. Search shows walls with the same colours and, for a signed-in user, the same subject.

The domain model is `PhotoQuery`:

| Field | Value |
|---|---|
| `palette` | 1 to 3 palette colours with shares that add up to 1. The largest share is first. |
| `labels` | 0 to 5 Cloud Vision labels. The most certain label is first. |
| `category` | The Prism category that the labels map to (`mapLabelsToCategory`), or none. |
| `labelsStatus` | `found`, `guest`, `capped` or `unavailable`. |
| `preview` | The clean 512 px copy. The photo chip shows it. |

Data path:

```text
camera roll (image_picker, long side 1024 or less, no metadata request)
  -> decode on the phone (dart:ui)
       -> PNG from raw pixels, long side 512 or less -> JPEG (flutter_image_compress)   = clean copy
       -> RGBA pixels, long side 48 or less -> palette in an isolate                   = PhotoQuery.palette
  -> signed in: photoSearchLabels callable (clean copy, requestId) -> Cloud Vision     = PhotoQuery.labels
     guest: no network call
  -> PrismWallSearch.photoCandidates -> rankPhotoMatches      -> "From Prism" row
  -> WallpaperSearchService.search(top label, colour = top colour) -> Wallhaven, then Pexels
       no results -> the same search with the colour only
```

How to use it:

1. Tap the **Search by photo** icon in the search bar.
2. A signed-in user sees a sheet one time. It says that a small copy goes to Google Cloud Vision and is not stored. **Choose photo** opens the camera roll. The app keeps the answer in the setting `search.photo_privacy_seen`.
3. Pick a photo. The results show with a photo chip above them.
4. Tap **Clear** on the chip to go back to the discover view. System back does the same.

The photo chip shows:

- A 44 point thumbnail of the clean copy. Its screen reader label is "Your photo".
- "Matches for" and the first 3 labels in lowercase, or "Matches by colour" when there are no labels.
- A dot for each palette colour. Its screen reader label is "Main colours:" and the colour names.
- A **Clear** button. Its tooltip and screen reader label is "Clear photo".
- One note:

| `labelsStatus` | Note |
|---|---|
| `found` | A small copy went to Google Cloud Vision to find what's in it. It isn't stored. |
| `guest` | Colour matches only. Sign in to match what's in the photo too. |
| `capped` | You've used today's 20 photo searches. Matching by colour until tomorrow. |
| `unavailable` | Couldn't read what's in the photo. Matching by colour only. |

The chip fades in. With reduce motion on, it shows at once (`context.motion`). The text wraps at large text sizes. With text larger than 130%, **Clear** moves under the note, so the labels keep the full width. The labels line shows 3 lines at most.

#### Colours on the phone

- The palette uses the same rule as the backend wall colours (`functions/src/wallColors.ts`). The image is sampled at a long side of 48 pixels. Each pixel goes to the nearest of the 12 palette colours (`nearestPaletteColor`, CIE76 in Lab space). A transparent pixel counts as on white.
- The palette keeps the colours that cover 12% of the pixels or more, at most 3, the largest first. When no colour covers 12%, it keeps the top colour.
- The count runs in `Isolate.run`. The isolate gets only the 48 pixel sample, which is 9 KB or less.
- No network call is needed for the colours.
- These bounds apply after the picker returns. They do not bound the picker's peak native memory use. The current
  Android picker can decode the full bitmap before resizing because its sampling options have no source dimensions.
  The iOS picker creates a `UIImage` before drawing the smaller copy. Very large photos, including HEIC, can exhaust
  native memory before `preparePhoto` runs. Fixing this requires native picker changes.

#### Labels

- Only a signed-in user gets labels. A guest's photo never leaves the phone.
- The app sends the clean copy and a new `requestId` to the `photoSearchLabels` callable (`us-central1`, the region of `appFunctions`).
- The callable sends the bytes to Cloud Vision label detection in the request body. It uses the same Vision client and the same score floor (0.7) as `categorizeWallpaper`. It returns at most 5 labels and the mapped category.
- Inline photo calls disable SDK retries and use a 20-second RPC timeout. The app waits 30 seconds for the callable (`photoLabelsTimeout`), so a search the server counts is not dropped by the app. Each claimed slot starts at most one Vision
  RPC. URL-based wallpaper categorization keeps its existing retry settings.
- The callable does not write the image anywhere. It does not use Firebase Storage or R2.
- App Check is not used. No other callable uses it.

Callable rules:

| Check | Answer |
|---|---|
| No sign-in, or an anonymous sign-in | `unauthenticated`. The app shows the guest note. |
| `requestId` is not 8 to 64 characters of `A-Z a-z 0-9 _ -` | `invalid-argument` |
| `image` is not base64 of a JPEG or PNG | `invalid-argument` |
| `image` is over 512 KiB | `invalid-argument`, before any count or Vision call |
| 20 labelled searches today (UTC) | `resource-exhausted`. The app shows the capped note and matches by colour. |
| The same `requestId` again on the same day | The same labels. No new count and no new Vision call. |
| The same `requestId` while the first call runs (90 seconds or less) | `aborted` |
| Cloud Vision fails | `unavailable`. The search still counts. The app shows the unavailable note. |
| The same `requestId` after it stopped while it ran (over 90 seconds) | A new Vision call that counts again. |

Every Vision call counts, so a user gets 20 Vision calls a day at most.

The claim reads the UTC day inside the transaction. Completion only updates that claim's pending slot, so an older
attempt cannot change a reclaimed slot or the next day's results. A client timeout after a claim still consumes a
search. If caching the labels fails, the callable returns them to that caller, but a replay can remain pending until
the stale window ends.

The callable keeps one doc for each user, `photoSearchRate/{uid}`: `day`, `count`, `results` (the labels and category for each `requestId` of the day) and `expireAt`. The doc has no image data. `expireAt` is two days after the last photo search. A TTL policy on `photoSearchRate.expireAt` (`firestore.indexes.json`) deletes the doc. `deleteAccount` deletes it too. Firestore rules refuse all client reads and writes (the default deny).

#### Ranking

The "From Prism" row uses walls that the backend already labels. It needs no new field and no backfill:

- `walls.colors`: 1 to 3 palette ids, the largest first (`wallColors.ts`).
- `walls.searchTerms`: the terms of the title, tags, category, description, creator name and `visionLabels` (`wallSearchTerms.ts`).

`PrismWallSearch.photoCandidates` runs two queries on reviewed walls, newest first, limit 48 each: `colors array-contains <top colour>`, and `searchTerms array-contains-any <label terms>`. A guest runs only the colour query. The existing indexes cover both. The service removes duplicates and walls from blocked creators.

`rankPhotoMatches` gives each wall a score from 0 to 1 and keeps the best 12:

- Palette closeness. The wall colours count 1, then 0.6 and 0.4, then 0.5, 0.3 and 0.2. Half of the closeness is the share overlap: for each colour, the smaller of the two shares. The other half is 1 minus the mean Lab distance from each colour to the nearest colour on the other side, where black to white is 1. A wall without colours has closeness 0.
- Label overlap. The label terms and the category term are made with the backend rule (lowercase, singular, no stop words). The overlap is the part of these terms that the wall's `searchTerms` holds.
- With labels, the score is half palette closeness and half label overlap. With no labels, the score is the palette closeness.
- Equal scores keep the query order: colour matches first, then label matches, each newest first.

The resolution and portrait filters apply to the Prism row. The colour filter is replaced by the top photo colour. Depth Effect and Spatial Scene filters do not apply to a photo search.

Starting a new photo search clears the selected kinds and resets the source to All. This is the existing picker behaviour. Kinds and **Prism walls only** selected while the photo loads or after it appears do apply. The service skips Wallhaven and Pexels and shows only the ranked Prism walls that pass the filters, with no next page. If none pass, the photo chip and active filters remain above the empty grid. **Clear all** keeps the photo and loads its results again without filters.

#### Wallhaven and Pexels

The service runs the normal search with the top label as the query and the top colour as the colour filter. If that has no results, it runs the colour only (Wallhaven only, because Pexels needs a query). The grid loads the next pages with the query that gave results. A guest has no label, so the search is colour only.

If the label search succeeds with no results and the colour-only fallback fails, the screen keeps the valid empty
result. Filters changed while labels are loading apply when the photo is ready. Late picker or result responses do
not replace a newer search or its pagination query.

#### Analytics

| Event | When |
|---|---|
| `photo_search_started` (`signed_in`, `search_id`) | The user picked a photo. |
| `photo_search_labels_returned` (`label_count`, `search_id`) | The callable returned labels. |
| `photo_search_labels_capped` (`search_id`) | The callable refused because of the daily cap. |
| `photo_search_result_opened` (`provider`, `item_id`, `index`, `search_id`) | The user opened a result of a photo search. `search_result_opened` is sent too. |
| `search_results_loaded` | A photo results request completes, including page 1, filter changes and retries. It records success, empty, failure or cancelled. A superseded request reports cancelled with reason `superseded` and zero results. |
| `search_kind_results` | A current kind-filtered photo results request succeeds. It includes the selected kinds and result count, including zero. A failed or superseded request does not send this event. |

Filter changes and retries retain the picked photo's `search_id`, so result opens still correlate with its start and label events. A new photo gets a new id.

#### Privacy

- The photo is downscaled on the phone to a long side of 512 pixels or less before it leaves the phone.
- The clean copy is a new image made from the decoded pixels. EXIF, location and all other metadata of the original are not in it. `test/features/user_search/photo_search_service_test.dart` proves this with a photo that has location data.
- The picker asks for no metadata (`requestFullMetadata: false`).
- Picker output can still contain metadata. The fresh image made from decoded pixels is the privacy boundary.
- Photo-search failure logs contain no exception messages, error objects, or stacks that could hold image data.
- A small copy goes to Google Cloud Vision for a signed-in user only. It is not stored. The app says this in the one-time sheet and in the note under the photo chip.
- The privacy page (`web/app/privacy/page.tsx`) lists Google Cloud Vision as a third party.

#### Cost

Cloud Vision label detection list price (check the Google Cloud pricing page before release): the first 1,000 units each month are free, then USD 1.50 for each 1,000 units up to 5 million units.

| Case | Vision units | Cost |
|---|---|---|
| 1,000 signed-in photo searches | 1,000 | USD 1.50 |
| A guest search, a capped search, a refused image, a replayed `requestId` | 0 | USD 0 |
| One user at the cap for one day | 20 | USD 0.03 |
| Worst case per day | 20 for each signed-in user | USD 0.03 for each signed-in user. 1,000 users at the cap is USD 30 a day. 10,000 users is USD 300 a day. |

The callable also costs one Cloud Functions call and up to three Firestore transactions for each search.

### Pagination

- The page cursor key is `search:<query>`. A search cursor does not reuse a category cursor.
- The grid loads the next page when the user scrolls near the end. It shows a footer only when more pages exist and at least 24 results are loaded.
- When a next page fails, the footer shows a retry state. The user taps it to try again.
- Pull to refresh loads page 1 again. If it fails, the grid keeps its items and shows the toast "Couldn't refresh. Pull down to try again."

### Prism catalogue results

- `PrismWallSearch.search` runs two Firestore queries on `walls` with `review == true`, newest first, limit 12. One query matches `tags` (`array-contains-any`). The other matches `category` (`in`).
- A query with several words matches on each word. "dark blue forest" finds a wall that has the tag "forest". The search uses up to 10 words. Each word is tried in lowercase, as typed, and in title case. The whole phrase fills the values that are left. Firestore allows 30 values at most.
- Category matching uses the title-case query, and any word that is a known category name.
- The service removes duplicates and walls from blocked creators.
- A query shorter than 2 characters returns nothing.
- The search never throws. A failed query counts as no match.

### Result tiles

- A tile shows a skeleton while its image loads.
- When the image fails, the tile tries the full wallpaper. When that fails too, the tile shows a **Retry image** button. A tap clears the cached copy and loads again. A tile with an empty image address stays a skeleton and has no button.
- A long press on a tile opens the quick actions sheet: Favourite or Unfavourite, Share link, and on Android Set as wallpaper. See `docs/features/categories.md`.
- Wallhaven grid tiles use the `lg` thumbnail. The detail screen still loads the original image.

### Find creators

- **Find Creators** in the discover view opens a creator search (`UserSearch`).
- The search starts 300 ms after the user stops typing. A slow answer to an older query never replaces the answer to the newest query.
- Name matching ignores case. The search reads `nameLower` (lowercase name) and `usernameLower`, and `name` for profiles that were saved before `nameLower` existed.

### Discover view and trending

- The Search screen keeps one discover bloc. "Trending right now" does not load again after each search. It loads again only when its first load failed.
- Discover cards decode their images at card size.

The Creators to follow row also shows in the Discover view. The details are in [creator-directory.md](creator-directory.md).

The Folders to follow row comes after it. The details are in [folders.md](folders.md), section Discover folders.

### Errors and empty states

| State | What the user sees |
|---|---|
| Search throws (Wallhaven and Pexels both failed) | Error state "Couldn't search right now", text "Check your connection and try again.", and a **Try again** button. Pull to refresh also retries. |
| No results from any source | `No wallpapers found for "<query>".` A colour-only search says `No <colour> wallpapers found`. With non-default filters, the text "Try fewer filters." and a **Reset filters** button. |
| Loading | Loading cards. They also show while a new search or a changed filter loads. The old results go away at once, so filtered results never mix with the old page. |

`WallpaperSearchService.search` throws `WallpaperSearchException` only when both providers fail. A Wallhaven failure alone moves the search to Pexels. A Prism query failure never makes the search fail.

### Missing index

The Prism tag query needs the Firestore index on `walls`: `tags` (array contains), `review`, `createdAt` (descending). The index is in `firestore.indexes.json`. If it is not deployed, Firestore returns `failed-precondition`. `PrismWallSearch` logs "tags index is not deployed yet" and returns no tag matches. The category query and the provider results still work.

## Limits

- Sort changes only the Wallhaven results. It does not change the Prism row or the Pexels results.
- Pexels filters by resolution only on the client, after the page loads. A page can have fewer items than the page size.
- The cursor key `search:<query>` does not include the filters. The repository cache scope does include them.
- The `tags` index change in `firestore.indexes.json` is in the working tree. The code does not show that it is deployed. A person must deploy it.
- The "From Prism" row opens a wallpaper without a hero animation. It reports index 0 in analytics for every tile.
- The detail screen loads the original Wallhaven image. Grid tiles use the smaller `lg` thumbnail, so a tile can look softer than the detail view.
- Name search for creators depends on `nameLower`. Profiles without it match only by exact-case name or by username until the backend writes `nameLower` for them.
- A colour-only search sends no search analytics event, because the event needs a query. A colour-only search is not saved in recent searches.
- A Prism wall has colours only after the backend writes `colors`. Until the backfill runs, the "From Prism" row has few walls for a colour.
- Pexels matches a colour with its own colour model. Results can include photos with a different main colour.
- The search analytics event always names Wallhaven as the provider for a submitted query (`SearchSubmittedEvent`).
- Cloud Vision labels are in English. "Matches for" shows them in English in every language.
- The `photoSearchLabels` callable must be deployed before a release that ships photo search. Until then, a signed-in user gets the unavailable note and colour matches.
- The TTL policy on `photoSearchRate.expireAt` takes effect only after `firestore.indexes.json` is deployed.
- A photo search with a label that Wallhaven does not know falls back to the colour only. The label still ranks the Prism row.

## How to test

1. Open the Search tab. Make sure the discover view shows tag suggestions.
2. Type "nature" and submit. Make sure a "From Prism" row shows first when Prism walls match.
3. Open **Filters**. Turn off Portrait only, choose 1440p and Latest, then tap **Apply**. Make sure the results reload and the Filters icon has a badge.
4. Tap the X button. Make sure the discover view shows the query in "Recent searches".
5. Tap **Clear** next to "Recent searches". Make sure the chips disappear.
6. Turn on airplane mode and search. Make sure the error state and **Try again** show. Turn the network on and tap **Try again**.
7. Open a Wallhaven wallpaper. Tap a tag chip. Make sure the Search tab opens and runs that tag.
8. Search for a word with no matches, such as "zzqxv". Make sure the empty state shows.
9. Type "dark forest" and submit. Make sure Prism walls with the tag "forest" or "dark" show in the "From Prism" row.
10. Open **Find Creators**, type "john" in lowercase. Make sure a creator saved as "John" shows.
11. Run a search, tap the X button, and look at "Trending right now". Make sure it does not show a skeleton again.
12. Long press a result tile. Make sure the quick actions sheet opens.
13. In the discover view, tap the blue swatch in **Browse by colour**. Make sure results show with a "Blue" chip and an empty search field.
14. Tap **Clear colour** on the chip. Make sure the discover view shows.
15. Type "forest" and submit. Open **Filters**, choose **My accent**, and tap **Apply**. Make sure the results reload and the Filters icon has a badge.
16. Open **Filters** and tap the selected swatch. Make sure the swatch ring goes away. Tap **Apply**. Make sure the results have no colour.
17. As a guest, tap the **Search by photo** icon and pick a sunset photo. Make sure the photo chip shows orange or red dots, "Matches by colour" and the guest note. Make sure the results are warm colours.
18. Sign in and tap the **Search by photo** icon. Make sure the privacy sheet shows. Tap **Choose photo** and pick a photo of a green room. Make sure the chip shows "Matches for" with labels and the Cloud Vision note.
19. Tap the icon again. Make sure the sheet does not show again.
20. Tap **Clear** on the chip. Make sure the discover view shows.
21. Use one account for 20 photo searches in one day. Make sure the 21st shows the capped note and colour matches.

Automated tests:

- `test/features/user_search/search_screen_test.dart`
- `test/features/user_search/search_tags_test.dart`
- `test/features/user_search/user_search_bloc_test.dart`
- `test/features/user_search/user_search_repository_impl_test.dart`
- `test/features/user_search/search_thumbnail_widgets_test.dart`
- `test/features/prism_feed/data/prism_wall_search_test.dart`
- `test/features/user_search/search_grid_test.dart`
- `test/features/user_search/search_filter_sheet_test.dart`
- `test/features/user_search/search_filters_test.dart`
- `test/features/user_search/recent_searches_store_test.dart`
- `test/features/user_search/search_discovery_recent_test.dart` (Browse by colour)
- `test/core/color/prism_palette_test.dart`
- `test/features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl_test.dart`
- `test/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl_test.dart`
- `test/features/user_search/wallpaper_search_service_test.dart`
- `test/features/wallpaper_detail/views/widgets/wallpaper_detail_widgets_test.dart` (tag chips)
- `test/features/user_search/photo_palette_test.dart` (palette of a solid colour, two colours, a gradient)
- `test/features/user_search/photo_match_ranking_test.dart` (ranking, empty labels)
- `test/features/user_search/photo_search_service_test.dart` (512 px clean copy, no EXIF or location, label errors)
- `test/features/user_search/photo_search_screen_test.dart` (picker button, guest note, privacy sheet, capped note, results order, large text)
- `test/features/user_search/photo_search_chip_test.dart` (chip, notes, large text, dark theme)
- `functions/src/__tests__/photoSearchLabels.test.ts` (auth, cap, `requestId` replay, oversize image, no image stored)

Screen renders (real photo pipeline and ranking, stub labels, light and dark):

```sh
fvm flutter test --no-pub test/qa_render/photo_search_render.dart --dart-define=QA_RENDER=true
```

The files go to `build/qa_render/photo_search_*.png`.

Local emulator QA: `tool/photo_search_qa.cjs` (`prepare`, `emulators`, `serve`, `seed`, `build-apk`, `cap`, `uncap`). It uses the weekly challenge QA runtime. That runtime blocks all nonlocal network, so a stub replaces Cloud Vision. The stub names the photo from its mean colour.

Command:

```sh
fvm flutter test --no-pub test/features/user_search
```
