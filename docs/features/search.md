# Search

The user types a word and gets wallpapers from Wallhaven, with Pexels as a fallback. Matching Prism catalogue wallpapers show first in a "From Prism" row. The user can narrow results with filters.

## Where to find it

- The **Search** tab in the bottom bar (`SearchScreen`, `lib/features/user_search/views/pages/search_screen.dart`).
- The tag chips on the wallpaper detail screen. A tap on a chip opens the Search tab and runs that tag.
- The **Filters** icon (tune icon) in the search bar opens the filter sheet.

## Platforms

Android and iOS. The code has no platform branch.

## Free and Pro

Search is free. The search files contain no premium or coin gate.

## How it works

| Path | Role |
|---|---|
| `lib/features/user_search/views/pages/search_screen.dart` | Search bar, discover view, results, error and empty states. |
| `lib/features/user_search/views/widgets/search_discovery_widget.dart` | Discover view: recent searches, tag suggestions, trending. |
| `lib/features/user_search/views/widgets/search_grid.dart` | Result grid, "From Prism" row, pagination, pull to refresh. |
| `lib/features/user_search/views/widgets/search_filter_sheet.dart` | Filter sheet and the mapping from choices to `SearchFilters`. |
| `lib/features/user_search/data/recent_searches_store.dart` | Recent searches in local settings. |
| `lib/features/user_search/data/search_filters.dart` | `SearchFilters` and `SearchSort`. |
| `lib/features/user_search/data/wallpaper_search_service.dart` | Runs the search. Falls back to Pexels. Throws on total failure. |
| `lib/features/prism_feed/data/prism_wall_search.dart` | Finds Prism walls by tag or category in Firestore. |
| `lib/features/wallpaper_detail/biz/tag_search_launcher.dart` | `openTagSearch` hands a tag to the Search screen. |

Data path:

```text
query + SearchFilters
  -> PrismWallSearch (Firestore walls)      -> prismResults ("From Prism" row)
  -> Wallhaven page 1                       -> results
       fails -> Pexels page 1               -> results
       fails -> WallpaperSearchException    -> error state with Retry
```

### Search bar

- The keyboard action is Search. A search runs when the user submits a non-empty query.
- A clear (X) button shows when the field has text. Its tooltip is "Clear search". A tap clears the field and returns to the discover view.
- System back from results returns to the discover view before the user leaves the tab.
- The Filters icon shows a small badge when the filters differ from the defaults.

### Recent searches

- The discover view lists recent searches as chips. A **Clear** button next to "Recent searches" removes all of them.
- `RecentSearchesStore` keeps the last 10 queries (`maxItems = 10`), newest first.
- A repeat of an older query, ignoring case, moves to the front. It does not make a copy.
- The store uses the key `search.recent` (`PersistenceKeys.recentSearches`).

### Tag chips from the detail screen

- The detail screen shows up to 10 tag chips for a Prism or a Wallhaven wallpaper (`wallpaperTags`).
- A Pexels wallpaper has no tags in the app, so the screen shows no chips for it.
- A tap calls `openTagSearch`. It sets `pendingTagSearch` and opens the Search tab. `SearchScreen` reads the value, fills the field, and runs the search.

### Filters

| Filter | Choices | Default |
|---|---|---|
| Portrait only | On or off | On |
| Min resolution | Any, 1080p, 1440p, 4K | Any |
| Sort | Relevance, Latest, Top | Relevance |

The sheet has **Reset** and **Apply**. Reset returns all filters to the defaults. If a search is on screen, a changed filter runs it again.

The sheet turns "Min resolution" into `<width>x<height>`. With Portrait only on, the long side is the short side times 16/9, rounded. 1080p becomes `1080x1920`, 1440p becomes `1440x2560`, and 4K becomes `2160x3840`. With Portrait only off, the value is a square such as `1080x1080`.

Mapping of `SearchFilters` to each source:

| Filter | Wallhaven | Pexels | Prism row |
|---|---|---|---|
| Portrait only | `ratios=portrait` | `orientation=portrait` | Drops walls wider than tall. |
| Min resolution | `atleast=<width>x<height>` | Client filter on the result resolution. | Client filter on the wall resolution. |
| Sort | `sorting=date_added` (Latest), `sorting=toplist` (Top). Relevance sends no `sorting`. | Not used. | Not used. |

A wall with an unknown resolution passes the client filters.

### Pagination

- The page cursor key is `search:<query>`. A search cursor does not reuse a category cursor.
- The grid loads the next page when the user scrolls near the end. It shows a footer only when more pages exist and at least 24 results are loaded.
- When a next page fails, the footer shows a retry state. The user taps it to try again.
- Pull to refresh loads page 1 again. If it fails, the grid keeps its items and shows the toast "Couldn't refresh. Pull down to try again."

### Prism catalogue results

- `PrismWallSearch.search` runs two Firestore queries on `walls` with `review == true`, newest first, limit 12. One query matches `tags` (`array-contains-any`). The other matches `category` (`in`).
- Tag matching tries the lowercase query, the raw query, and the title-case query. Category matching uses the title-case query and the known category name.
- The service removes duplicates and walls from blocked creators.
- A query shorter than 2 characters returns nothing.
- The search never throws. A failed query counts as no match.

### Errors and empty states

| State | What the user sees |
|---|---|
| Search throws (Wallhaven and Pexels both failed) | Error state "Couldn't search right now", text "Check your connection and try again.", and a **Retry** button. Pull to refresh also retries. |
| No results from any source | `No wallpapers found for "<query>".` With non-default filters, the text "Try fewer filters." and a **Reset filters** button. |
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
- The search analytics event always names Wallhaven as the provider for a submitted query (`SearchSubmittedEvent`).

## How to test

1. Open the Search tab. Make sure the discover view shows tag suggestions.
2. Type "nature" and submit. Make sure a "From Prism" row shows first when Prism walls match.
3. Open **Filters**. Turn off Portrait only, choose 1440p and Latest, then tap **Apply**. Make sure the results reload and the Filters icon has a badge.
4. Tap the X button. Make sure the discover view shows the query in "Recent searches".
5. Tap **Clear** next to "Recent searches". Make sure the chips disappear.
6. Turn on airplane mode and search. Make sure the error state and **Retry** show. Turn the network on and tap **Retry**.
7. Open a Wallhaven wallpaper. Tap a tag chip. Make sure the Search tab opens and runs that tag.
8. Search for a word with no matches, such as "zzqxv". Make sure the empty state shows.

Automated tests:

- `test/features/user_search/search_screen_test.dart`
- `test/features/user_search/search_grid_test.dart`
- `test/features/user_search/search_filter_sheet_test.dart`
- `test/features/user_search/search_filters_test.dart`
- `test/features/user_search/recent_searches_store_test.dart`
- `test/features/user_search/wallpaper_search_service_test.dart`
- `test/features/wallpaper_detail/views/widgets/wallpaper_detail_widgets_test.dart` (tag chips)

Command:

```sh
fvm flutter test --no-pub test/features/user_search
```
