# Search

Search is the second bottom-nav tab (route `/dashboard/search`, `SearchRoute`). `lib/features/navigation/views/pages/search_tab_page.dart` is a thin wrapper (12 lines); the real discovery content is `lib/features/user_search/views/widgets/search_discovery_widget.dart`, and user search itself is a nested route, `/dashboard/search/users` (`UserSearchRoute`, `lib/features/user_search/views/pages/user_search_page.dart`).

## Sub-features

- `discovery` sections on the search landing screen: `Trending Right Now`, `Browse by Category`, `Search by Color` (`search_discovery_widget.dart`).
- `color-search`: tapping a color swatch pushes `ColorRoute(hexColor: swatch.hex)` (route `/color`).
- `user-search`: pushes `UserSearchRoute`, has a text field with hint `Search` (`user_search_page.dart:69`), and lets you push a `ProfileRoute` for a result.

## How to get to it (user POV)

- Tap `Search` in the bottom nav.
- On the discovery screen, tap a trending wallpaper to open `features/wallpaper-detail.md`, a category tile to browse by category, a color swatch for `Search by Color`, or the search-users entry to reach `/dashboard/search/users`.

## Driving it with the helper

Preconditions:

- App launched, signed in or out (search itself does not require a session).

- **Landing.** Tap `Search`. Snapshot `--tag search-discovery`. Assert section headers `Trending Right Now`, `Browse by Category`, `Search by Color`.
- **Color search.** Tap a color swatch. Confirm `ColorRoute` opens with wallpapers filtered by that hex color.
- **User search.** Reach `/dashboard/search/users`. Assert a text field with hint `Search`. Type a query with `type --platform <p> --text "<name>"`; confirm results render, then tap a result to open its `ProfileRoute` (see `features/profile.md`).
- **Proof.** Snapshot the discovery screen, a color-filtered result, and a user-search result list.

## Gotchas

- The exact affordance for reaching user search from the discovery screen (a button, a tab, a search-bar toggle) was not pinned down for this map. Run `describe` on the discovery screen and look for a label near "search" or "people" before writing a tap recipe.
- `search_tab_page.dart` itself has almost no content; do not spend time reading it further, the interesting code is in `search_discovery_widget.dart` and `user_search`.
